# Sprint 4: AI Search による非構造化データ検索の統合

**期間**: 1週間  
**目標**: Azure AI Search を使って Blob Storage 上の非構造化データ（製品仕様書・作業手順書・部材カタログ・品質基準書）を検索可能にし、Fabric Data Agent から参照できるようにする  
**前提**: [Sprint 3](../sprint3/README.md) 完了済み（Data Agent が構造化データで動作している）  
**ステータス**: 🔲 未着手

---

## 背景と課題

Sprint 3 までの構成では、Fabric Data Agent は **構造化データ（Warehouse / セマンティックモデル）** への自然言語クエリに対応していますが、**非構造化データ（製品仕様書・作業手順書・部材カタログ・品質基準書）** への検索は機能していません。

Sprint 3 テスト結果でも以下が確認されています：

| テスト ID | 質問 | 結果 | 原因 |
|---|---|---|---|
| TC-05 | 「インバータ制御装置の筐体組立の手順を教えて」 | △ 不正確 | OneLake ファイルインデックス未完了 |
| TC-06 | 「基板実装で ESD 対策はどうすればよい？」 | × 誤回答 | 同上 |

OneLake ネイティブの RAG インデックス機能は `unstructured_data_rag` パッケージが非公開のため利用不可です。  
そこで本スプリントでは **Azure AI Search** を検索エンジンとして利用し、既に Blob Storage にアップロード済みの非構造化データに対する全文検索・セマンティック検索を実現します。

---

## アーキテクチャ（Sprint 4 追加分）

```
                           ┌──────────────────────────┐
                           │   Fabric Data Agent      │
                           │   (自然言語クエリ)        │
                           └──────┬──────────┬────────┘
                                  │          │
                     構造化クエリ  │          │  非構造化検索
                                  │          │
                 ┌────────────────▼──┐  ┌───▼──────────────────┐
                 │  Fabric Warehouse │  │  Azure AI Search     │
                 │  (SQL)            │  │  (全文+セマンティック) │
                 │  + セマンティック  │  └───┬──────────────────┘
                 │    モデル         │      │ インデクサー
                 └──────────────────┘      │
                                      ┌───▼──────────────────┐
                                      │  Azure Blob Storage  │
                                      │  manufacturing-docs/ │
                                      │  ├─ product_specs/   │
                                      │  ├─ work_manuals/    │
                                      │  ├─ parts_catalog/   │
                                      │  └─ quality_standards│
                                      └──────────────────────┘
```

---

## Sprint 4 の完了条件 (Definition of Done)

- [ ] Azure AI Search リソースが作成されている
- [ ] Blob Storage の非構造化データに対するインデックスが作成・完了している
- [ ] AI Search でセマンティック検索が有効になっている
- [ ] Fabric Data Agent から AI Search を検索ソースとして利用できる
- [ ] Sprint 3 で失敗した TC-05 / TC-06 相当の質問に正しく回答できる
- [ ] UC-03（作業手順確認）/ UC-04（部材情報統合）/ UC-05（仕様+基準値）のテストが合格する

---

## タスク一覧

| # | タスク | 担当 | ステータス |
|---|---|---|---|
| 4-1 | Azure AI Search リソースの作成 | Azure担当 | 🔲 |
| 4-2 | Azure OpenAI リソース・埋め込みモデルの作成 | Azure担当 | 🔲 |
| 4-3 | データソースの接続（Blob Storage → AI Search） | Azure担当 | 🔲 |
| 4-4 | インデックスの定義と作成 | Azure担当 | 🔲 |
| 4-5 | インデクサーの作成と初回実行 | Azure担当 | 🔲 |
| 4-6 | セマンティック検索の有効化 | Azure担当 | 🔲 |
| 4-7 | AI Search 単体での検索動作確認 | テスト担当 | 🔲 |
| 4-8 | Data Agent への AI Search 接続設定 | Fabric担当 | 🔲 |
| 4-9 | Data Agent システムプロンプトの更新 | AI担当 | 🔲 |
| 4-10 | 非構造化データ検索のテスト実施 | テスト担当 | 🔲 |
| 4-11 | 構造化 × 非構造化の統合クエリテスト | テスト担当 | 🔲 |
| 4-12 | Sprint 4 完了レビュー | 全員 | 🔲 |

---

## 手順詳細

### Step 1: Azure AI Search リソースの作成（タスク 4-1）

#### Azure Portal での作成

1. [Azure Portal](https://portal.azure.com) を開く
2. 「**リソースの作成**」→ 「**AI + Machine Learning**」→ 「**Azure AI Search**」を選択
3. 以下の設定で作成：

| 設定項目 | 値 |
|---|---|
| サブスクリプション | $env:AZURE_SUBSCRIPTION_ID |
| リソースグループ | `rg-fabric-dataagent-poc` |
| サービス名 | `manufacturing-search-<suffix>`（グローバル一意のためランダムサフィックス付与） |
| 場所 | `Japan East` |
| 価格レベル | `Basic`（PoC 用。セマンティック検索には Basic 以上が必要） |

> **注意**: AI Search のサービス名は `<name>.search.windows.net` というグローバル DNS 名になるため、**全 Azure テナントで一意**である必要があります。Sprint 1 の Storage Account と同様、ランダムサフィックスを付与して作成します。

#### PowerShell での作成（代替）

```powershell
# AI Search のサービス名はグローバルで一意である必要があるため、
# ランダムサフィックスを付与する（Storage Account と同じ方式）
$suffix = -join ((97..122) + (48..57) | Get-Random -Count 6 | % { [char]$_ })
$searchName = "manufacturing-search-$suffix"
Write-Host "AI Search サービス名: $searchName"

# Azure AI Search リソースの作成（Managed Identity を有効化）
az search service create `
    --name $searchName `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --location $env:AZURE_LOCATION `
    --sku "basic" `
    --partition-count 1 `
    --replica-count 1 `
    --identity-type SystemAssigned

# セマンティック検索の有効化
az search service update `
    --name $searchName `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --semantic-search "standard"

# 以降の手順で使う環境変数として設定・記録
$env:AZURE_SEARCH_SERVICE = $searchName
Write-Host "環境変数に設定しました: AZURE_SEARCH_SERVICE=$searchName"
Write-Host "※ .env.search ファイルへの記録を推奨します"
```

### Step 2〜4 一括: Azure Portal「データのインポートとベクター化」ウィザード（推奨）

Azure Portal の新しいウィザード「**データのインポートとベクター化**」を使うと、**データソース・インデックス・インデクサーの 3 つを一括で作成**できます。  
以下の手順だけで Step 2〜4 の作業がすべて完了するため、PoC ではこの方法を推奨します。

> **注意**: AI Search のポータルには「データのインポート」（旧）と「**データのインポートとベクター化**」（新）の 2 つがあります。新しい方を使用してください。

> **検索方式の選択**: ウィザードでは「キーワード検索」「**RAG**」「マルチモーダル RAG」の 3 つから選択します。  
> 本 PoC では **「RAG」を選択**してください。理由は以下の通りです：
>
> | 選択肢 | 仕組み | Data Agent との相性 |
> |---|---|---|
> | キーワード検索 | 従来の全文検索（BM25） | △ キーワード一致のみ。自然言語クエリでは意図と異なる結果が返りやすい |
> | **RAG**（推奨） | テキストをチャンク分割 → ベクトル埋め込み → ハイブリッド検索 | ◎ Data Agent の自然言語クエリの「意味」でマッチングできる |
> | マルチモーダル RAG | テキスト + 画像もベクトル化 | × 対象が Markdown テキストなので画像検索は不要。コストも高い |
>
> RAG を選択すると、ドキュメントが自動でチャンク分割され、Azure OpenAI の埋め込みモデルでベクトル化されます。  
> これにより、「ESD 対策」と「静電気対策」のように表現が異なっても意味的に近いドキュメントを検索できます。

#### 前提: Azure OpenAI リソースの作成（タスク 4-2）

RAG 方式ではテキストのベクトル埋め込みに Azure OpenAI の埋め込みモデルが必要です。  
ウィザード開始前に以下を作成してください。

##### Azure OpenAI リソースの作成

```powershell
# Azure OpenAI リソースの作成（同一リソースグループ・同一リージョン）
az cognitiveservices account create `
    --name "manufacturing-llm" `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --location $env:AZURE_LOCATION `
    --kind "OpenAI" `
    --sku "S0" `
    --custom-domain "manufacturing-llm"
```

##### 埋め込みモデルのデプロイ

```powershell
# text-embedding-3-small モデルをデプロイ
az cognitiveservices account deployment create `
    --name "manufacturing-llm" `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --deployment-name "manufacturing-embedding" `
    --model-name "text-embedding-3-small" `
    --model-version "1" `
    --model-format "OpenAI" `
    --sku-capacity 120 `
    --sku-name "Standard"
```

##### リソース設定一覧

| 設定項目 | 値 |
|---|---|
| Azure OpenAI リソース名 | `manufacturing-llm` |
| リソースグループ | `rg-fabric-dataagent-poc`（既存） |
| リージョン | `Japan East`（既存リソースと同一） |
| 価格レベル | `Standard S0` |
| デプロイメント名 | `manufacturing-embedding` |
| モデル | `text-embedding-3-small` |

##### AI Search から Azure OpenAI への RBAC 設定

AI Search の Managed Identity が Azure OpenAI の埋め込み API を呼び出すための権限を付与します。  
この設定がないと、インデクサー実行時に `PermissionDenied` エラーが発生します。

```powershell
# AI Search のマネージド ID を取得
$searchPrincipalId = (az search service show `
    --name $env:AZURE_SEARCH_SERVICE `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --query identity.principalId -o tsv)

# Azure OpenAI への Cognitive Services OpenAI User ロールを付与
az role assignment create `
    --assignee $searchPrincipalId `
    --role "Cognitive Services OpenAI User" `
    --scope "/subscriptions/$env:AZURE_SUBSCRIPTION_ID/resourceGroups/$env:AZURE_RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/manufacturing-llm"
```

> **注意**: RBAC の反映に数分かかる場合があります。ロール付与直後にインデクサーを実行して失敗した場合は、少し待ってから再実行してください。

#### 手順

1. Azure Portal で AI Search サービス（`$env:AZURE_SEARCH_SERVICE`）を開く
2. 概要画面の上部にある「**データのインポートとベクター化**」をクリック
3. 「**RAG**」を選択

#### ① データソースへの接続

3. データソースとして「**Azure Blob Storage**」を選択
4. 以下を設定：

| 設定項目 | 値 |
|---|---|
| サブスクリプション | 使用中のサブスクリプション |
| Blob ストレージアカウント | `.env.storage` の `AZURE_STORAGE_ACCOUNT` に該当するアカウント |
| Blob コンテナー | `manufacturing-docs` |
| 認証の種類 | `システム マネージド ID`（Step 1 で有効化済み） |

5. 「**次へ**」をクリック

#### ② テキストのベクター化

6. 「**テキストをベクター化する**」にチェックが入っていることを確認
7. 埋め込みモデルとして以下を選択：

| 設定項目 | 値 |
|---|---|
| サブスクリプション | 使用中のサブスクリプション |
| Azure OpenAI サービス | `manufacturing-llm`（前提で作成済み） |
| モデル デプロイ | `manufacturing-embedding` |

8. 「**次へ**」をクリック

#### ③ インデックスのカスタマイズ

8. 以下を設定：

| 設定項目 | 値 |
|---|---|
| インデックス名 | `manufacturing-docs-index` |
| セマンティック ランカーを有効にする | ✅（チェックを入れる） |
| スケジュール | `1 回`（PoC では初回のみ） |

> インデックスのフィールド構成はウィザードが Blob メタデータから自動生成します。  
> `content`、`metadata_storage_name`、`metadata_storage_path` 等のフィールドが自動で追加されます。

9. 「**次へ**」をクリック

#### ④ 確認と作成

10. 設定内容を確認し「**作成**」をクリック
11. データソース・インデックス・インデクサー・セマンティック構成が一括で作成され、インデクサーが自動実行される
12. 左メニュー「**インデクサー**」で作成されたインデクサーのステータスが「**成功**」になることを確認
13. 左メニュー「**インデックス**」で `manufacturing-docs-index` のドキュメント数が 10 件（非構造化ファイル数）であることを確認

#### セマンティック構成の確認

ウィザードでセマンティックランカーを有効にした場合、セマンティック構成が自動作成されます。  
内容を確認・調整する場合：

1. 左メニュー「**インデックス**」→ `manufacturing-docs-index` をクリック
2. 「**セマンティック構成**」タブを開く
3. 以下の設定になっていることを確認（必要に応じて編集）：

| 設定項目 | 値 |
|---|---|
| セマンティック構成名 | 自動生成名を `manufacturing-docs-semantic-config` にリネーム推奨 |
| コンテンツフィールド | `content`（本文テキスト） |
| タイトルフィールド | `metadata_storage_name`（ファイル名） |

> **Portal ウィザードで作成した場合、以下の Step 2〜4 の REST API / PowerShell 手順はスキップできます。**  
> Step 5（検索動作確認）に進んでください。

---

### Step 2: データソースの接続（タスク 4-2）

> ※ Azure Portal「データのインポート」ウィザードで一括作成した場合はスキップ可

Blob Storage を AI Search のデータソースとして登録します。

#### 接続情報

| 項目 | 値 |
|---|---|
| データソース名 | `manufacturing-docs-datasource` |
| 種類 | Azure Blob Storage |
| ストレージアカウント | `$env:AZURE_STORAGE_ACCOUNT`（実値は `.env.storage` 参照） |
| コンテナー | `manufacturing-docs` |
| 認証方式 | Managed Identity（推奨） |

#### PowerShell での設定

```powershell
# .env.storage から環境変数を読み込み（未設定の場合）
Get-Content scripts/.env.storage | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.+)$') {
        [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), 'Process')
    }
}
$env:AZURE_SUBSCRIPTION_ID = (az account show --query id -o tsv)

# AI Search のマネージド ID に Blob Storage の読み取り権限を付与
# ※ $env:AZURE_SEARCH_SERVICE に Step 1 で作成したサービス名が設定されていること
$searchPrincipalId = (az search service show `
    --name $env:AZURE_SEARCH_SERVICE `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --query identity.principalId -o tsv)

az role assignment create `
    --assignee $searchPrincipalId `
    --role "Storage Blob Data Reader" `
    --scope "/subscriptions/$env:AZURE_SUBSCRIPTION_ID/resourceGroups/$env:AZURE_RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$env:AZURE_STORAGE_ACCOUNT"
```

#### REST API でデータソース作成

> この操作では、**AI Search に「どの Blob コンテナからデータを読み取るか」を登録**しています。  
> AI Search のパイプラインは以下の 3 要素で構成されており、データソースはその最初の設定です。
>
> | # | リソース | 役割 |
> |---|---|---|
> | 1 | **データソース**（← 本ステップ） | 検索対象データの取得先（Blob Storage の接続情報） |
> | 2 | **インデックス**（Step 3） | 検索用データ構造の定義・格納先 |
> | 3 | **インデクサー**（Step 4） | データソースからデータを読み取りインデックスに投入する処理 |
>
> データの実体（Markdown ファイル群）は Sprint 1 の `02_upload_unstructured_data.ps1` で既に Blob Storage にアップロード済みです。

```json
// POST https://$AZURE_SEARCH_SERVICE.search.windows.net/datasources?api-version=2024-07-01
{
  "name": "manufacturing-docs-datasource",
  "type": "azureblob",
  "credentials": {
    "connectionString": "ResourceId=/subscriptions/<sub-id>/resourceGroups/rg-fabric-dataagent-poc/providers/Microsoft.Storage/storageAccounts/<AZURE_STORAGE_ACCOUNT>;"
  },
  "container": {
    "name": "manufacturing-docs"
  }
}
```

### Step 3: インデックスの定義と作成（タスク 4-3）

> ※ Azure Portal「データのインポート」ウィザードで一括作成した場合はスキップ可

#### インデックス設計

| フィールド名 | 型 | 検索可能 | フィルタ可能 | ソート可能 | 説明 |
|---|---|---|---|---|---|
| `id` | Edm.String | — | — | — | ドキュメント一意キー |
| `content` | Edm.String | ✅ | — | — | ドキュメント本文（全文検索対象） |
| `metadata_storage_name` | Edm.String | ✅ | ✅ | ✅ | ファイル名 |
| `metadata_storage_path` | Edm.String | — | ✅ | — | Blob パス |
| `metadata_content_type` | Edm.String | — | ✅ | — | コンテンツタイプ |
| `doc_category` | Edm.String | ✅ | ✅ | ✅ | ドキュメント種別（product_specs / work_manuals / parts_catalog / quality_standards） |

#### REST API でインデックス作成

```json
// POST https://$AZURE_SEARCH_SERVICE.search.windows.net/indexes?api-version=2024-07-01
{
  "name": "manufacturing-docs-index",
  "fields": [
    { "name": "id", "type": "Edm.String", "key": true, "filterable": false },
    { "name": "content", "type": "Edm.String", "searchable": true, "filterable": false, "sortable": false },
    { "name": "metadata_storage_name", "type": "Edm.String", "searchable": true, "filterable": true, "sortable": true },
    { "name": "metadata_storage_path", "type": "Edm.String", "filterable": true },
    { "name": "metadata_content_type", "type": "Edm.String", "filterable": true },
    { "name": "doc_category", "type": "Edm.String", "searchable": true, "filterable": true, "sortable": true }
  ],
  "semantic": {
    "configurations": [
      {
        "name": "manufacturing-docs-semantic-config",
        "prioritizedFields": {
          "contentFields": [
            { "fieldName": "content" }
          ],
          "titleField": { "fieldName": "metadata_storage_name" },
          "keywordsFields": [
            { "fieldName": "doc_category" }
          ]
        }
      }
    ]
  }
}
```

### Step 4: インデクサーの作成と実行（タスク 4-4）

> ※ Azure Portal「データのインポート」ウィザードで一括作成した場合はスキップ可

#### インデクサー設定

| 設定項目 | 値 |
|---|---|
| インデクサー名 | `manufacturing-docs-indexer` |
| データソース | `manufacturing-docs-datasource` |
| ターゲットインデックス | `manufacturing-docs-index` |
| パース方式 | `text`（Markdown ファイル用） |
| スケジュール | 手動（PoC では初回のみ） |

#### REST API でインデクサー作成

```json
// POST https://$AZURE_SEARCH_SERVICE.search.windows.net/indexers?api-version=2024-07-01
{
  "name": "manufacturing-docs-indexer",
  "dataSourceName": "manufacturing-docs-datasource",
  "targetIndexName": "manufacturing-docs-index",
  "parameters": {
    "configuration": {
      "parsingMode": "text",
      "dataToExtract": "contentAndMetadata"
    }
  },
  "fieldMappings": [
    {
      "sourceFieldName": "metadata_storage_path",
      "targetFieldName": "id",
      "mappingFunction": { "name": "base64Encode" }
    }
  ]
}
```

#### インデクサーの手動実行

```powershell
# インデクサーを実行
az rest --method POST `
    --url "https://$env:AZURE_SEARCH_SERVICE.search.windows.net/indexers/manufacturing-docs-indexer/run?api-version=2024-07-01" `
    --headers "Content-Type=application/json"

# 実行ステータスの確認
az rest --method GET `
    --url "https://$env:AZURE_SEARCH_SERVICE.search.windows.net/indexers/manufacturing-docs-indexer/status?api-version=2024-07-01"
```

### Step 5: セマンティック検索の有効化（タスク 4-5）

Step 3 のインデックス定義で `semantic` セクションを含めている場合、セマンティック検索は自動的に利用可能です。

#### 検索動作確認

```powershell
# 全文検索テスト
az rest --method POST `
    --url "https://$env:AZURE_SEARCH_SERVICE.search.windows.net/indexes/manufacturing-docs-index/docs/search?api-version=2024-07-01" `
    --body '{
        "search": "IGBT モジュール 代替品",
        "queryType": "semantic",
        "semanticConfiguration": "manufacturing-docs-semantic-config",
        "top": 3,
        "select": "metadata_storage_name,content"
    }'
```

#### 期待される検索結果

| 検索クエリ | 期待するヒットファイル |
|---|---|
| 「IGBT モジュール 代替品」 | `PC-PART001_igbt_module.md` |
| 「筐体組立 手順」 | `WM-PROC002_housing_assembly.md` |
| 「インバータ 電流 仕様」 | `PROD-001_inverter_controller.md` / `QS-PROD001_inverter.md` |
| 「ESD 対策 基板実装」 | `WM-PROC001_pcb_assembly.md` |
| 「サーボドライバ 検査基準」 | `QS-PROD002_servo.md` |

### Step 6: Data Agent への AI Search 接続（タスク 4-7）

#### 接続方法

Fabric Data Agent に AI Search を検索ナレッジソースとして追加します。

1. Fabric ポータルで `manufacturing_data_agent` を開く
2. 「**データソースの追加**」→「**Azure AI Search**」を選択
3. 以下を設定：

| 設定項目 | 値 |
|---|---|
| AI Search サービス名 | `$env:AZURE_SEARCH_SERVICE`（Step 1 で作成した名前） |
| インデックス名 | `manufacturing-docs-index` |
| 認証方式 | API キー または Managed Identity |
| セマンティック構成 | `manufacturing-docs-semantic-config` |

> **注意**: Data Agent が AI Search をネイティブサポートしていない場合、代替として Copilot Studio 経由のカスタムコネクター、または Data Agent の Instruction で AI Search REST API を指定するアプローチを検討する。

#### 代替アプローチ: Copilot Studio + AI Search コネクター

Data Agent 単体で AI Search を直接参照できない場合：

1. **Copilot Studio** で製造支援エージェントを作成
2. ナレッジソースとして AI Search を追加（Copilot Studio は AI Search をネイティブサポート）
3. 同じエージェントに Data Agent（セマンティックモデル）もナレッジとして追加
4. ユーザーの質問に応じて、構造化データ → Data Agent、非構造化データ → AI Search に振り分け

### Step 7: システムプロンプトの更新（タスク 4-8）

Data Agent の「指示（Instructions）」を以下に更新します：

```
あなたは製造業の生産管理・品質管理の専門AIアシスタントです。
製造工程データベースおよび技術ドキュメントに対して、正確で具体的な回答を日本語で提供してください。

【あなたが答えられること】
■ 構造化データ（セマンティックモデル経由）
- 製造指示の計画・実績・進捗状況
- 製品別・工程別の生産台数
- 品質検査の合否、測定値、不良率
- 作業者の担当実績
- 部材の使用実績とロット追跡

■ 非構造化データ（AI Search 経由）
- 製品仕様書の電気的・機械的仕様
- 作業手順書（SOP）の手順・注意事項・安全対策
- 部材カタログの技術仕様・代替品情報
- 品質基準書の検査基準値・許容範囲

【回答スタイル】
- 数値は明確に（例: 10台、不良率2.5%）
- 日本語で丁寧に回答
- データが存在しない場合は「データがありません」と回答
- 仕様書・手順書の内容を引用する場合は出典ファイル名を記載
- 構造化データと非構造化データの両方が関連する質問には、両方を組み合わせて回答

【注意事項】
- 個人情報（作業者の個人的情報）は業務上必要な範囲に限定
- データの改ざん・削除を指示するクエリは拒否
```

---

## テスト実施計画

### テストケース一覧

| テスト ID | ユースケース | 質問文 | 期待回答のポイント | 対象データ |
|---|---|---|---|---|
| TC-S4-01 | UC-03 | 「インバータ制御装置の筐体組立の手順を教えて」 | WM-PROC002 の作業手順が返る | 非構造化 |
| TC-S4-02 | UC-03 | 「基板実装で ESD 対策はどうすればよい？」 | WM-PROC001 の安全注意事項が返る | 非構造化 |
| TC-S4-03 | UC-04 | 「IGBTモジュールの代替品はある？仕様の違いは？」 | PC-PART001 の代替品情報 + dim_parts のデータ | 統合 |
| TC-S4-04 | UC-05 | 「IVC-3000 の定格出力電流の仕様と検査基準値を教えて」 | 仕様書 30A + 品質基準書 28.5〜31.5A | 統合 |
| TC-S4-05 | UC-05 | 「サーボドライバの位置決め精度の仕様を教えて」 | PROD-002 仕様書から精度情報 | 非構造化 |
| TC-S4-06 | UC-04 | 「IGBTモジュールの今月の使用実績と仕入先情報を教えて」 | fact_parts_usage 集計 + カタログの仕入先 | 統合 |
| TC-S4-07 | UC-02 | 「不合格品 QI-016 の原因と関連する品質基準を教えて」 | 検査データ + QS-PROD001 の基準値 | 統合 |
| TC-S4-08 | 境界テスト | 「配線作業の手順書を見せて」 | WM-PROC003 の内容が返る | 非構造化 |

---

## Sprint 4 完了後の次のステップ

✅ Sprint 4 完了 → [Sprint 5: M365 Copilot 統合・総合テスト](../sprint5/README.md) へ進む
