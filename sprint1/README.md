# Sprint 1: 環境準備・ダミーデータ投入

**期間**: 1週間  
**目標**: Azure Storage と Fabric Workspace の基本環境を整備し、ダミーデータを手元・クラウドに配置する  
**ステータス**: ✅ 完了

---

## Sprint 1 の完了条件 (Definition of Done)

- [x] Azure Resource Group と Blob Storage アカウントが作成されている
- [x] Blob Storage に非構造化データ（仕様書・手順書）がアップロードされている
- [x] Fabric ワークスペースが作成されている
- [x] Fabric Lakehouse が作成されており、非構造化データが OneLake に同期されている
- [x] 構造化ダミーデータ（CSV）が手元で確認できる状態になっている

---

## タスク一覧

| # | タスク | 担当 | ステータス |
|---|---|---|---|
| 1-1 | Azure CLI / Fabric CLI のインストール確認 | 環境担当 | ✅ |
| 1-2 | Azure Resource Group の作成 | 環境担当 | ✅ |
| 1-3 | Azure Blob Storage アカウントの作成 | 環境担当 | ✅ |
| 1-4 | Blob コンテナの作成とフォルダ構造設定 | 環境担当 | ✅ |
| 1-5 | 非構造化データのアップロード（スクリプト実行） | 環境担当 | ✅ |
| 1-6 | Azure Fabric 容量の作成 | 環境担当 | ✅ |
| 1-7 | Fabric ワークスペースの作成 | Fabric担当 | ✅ |
| 1-8 | Fabric Lakehouse の作成 | Fabric担当 | ✅ |
| 1-9 | 非構造化データの OneLake 直接アップロード | Fabric担当 | ✅ |
| 1-10 | 構造化データ CSV ファイルの内容確認 | データ担当 | ✅ |
| 1-11 | Sprint 1 完了レビュー | 全員 | ✅ |

---

## 手順詳細

> **注意**: タスク 1-2〜1-4 は `scripts/01_setup_azure_storage.ps1` を実行すると一括自動実行されます。  
> タスク 1-5 は `scripts/02_upload_unstructured_data.ps1` で実行します。  
> 個別に実行する場合は各タスクの手動コマンドを参照してください。

### タスク 1-1: Azure CLI / Fabric CLI のインストール確認

```powershell
# Azure CLI のバージョン確認 (2.50 以上推奨)
az --version

# Azure にログイン
az login

# サブスクリプションの確認・設定
az account list --output table
az account set --subscription "<your-subscription-id>"
```

### タスク 1-2: Azure Resource Group の作成

> `01_setup_azure_storage.ps1` を実行すると タスク 1-2〜1-4 をまとめて自動実行します。

```powershell
$RESOURCE_GROUP = "rg-fabric-dataagent-poc"
$LOCATION       = "japaneast"

az group create `
    --name $RESOURCE_GROUP `
    --location $LOCATION
```

### タスク 1-3: Azure Blob Storage アカウントの作成

> `01_setup_azure_storage.ps1` が自動実行します（`--allow-shared-key-access false` でキーレス設定済み）。

```powershell
$STORAGE_ACCOUNT = "stfabricdatapoc$(Get-Random -Minimum 1000 -Maximum 9999)"

az storage account create `
    --name $STORAGE_ACCOUNT `
    --resource-group $RESOURCE_GROUP `
    --location $LOCATION `
    --sku Standard_LRS `
    --kind StorageV2 `
    --allow-blob-public-access false `
    --min-tls-version TLS1_2 `
    --allow-shared-key-access false
```

### タスク 1-4: Blob コンテナの作成とフォルダ構造設定

> `01_setup_azure_storage.ps1` が自動実行します。

```powershell
$CONTAINER = "manufacturing-docs"

az storage container create `
    --name $CONTAINER `
    --account-name $STORAGE_ACCOUNT `
    --auth-mode login
```

フォルダ構造（Blob の仮想フォルダ）:
- `product_specs/` — 製品仕様書
- `work_manuals/` — 作業手順書
- `parts_catalog/` — 部品カタログ
- `quality_standards/` — 品質基準書

### タスク 1-5: 非構造化データのアップロード（スクリプト実行）

```powershell
# タスク 1-2〜1-4 をまとめて実行する場合はこちらから
.\scripts\01_setup_azure_storage.ps1

# 非構造化データのアップロード（data/unstructured/ 以下を Blob Storage へ）
.\scripts\02_upload_unstructured_data.ps1
```

> 詳細は [scripts/01_setup_azure_storage.ps1](../scripts/01_setup_azure_storage.ps1) を参照

### タスク 1-6: Azure Fabric 容量の作成

Fabric ワークスペースで Fabric ライセンスモードを利用するには、Azure サブスクリプション上に **Fabric 容量（F-SKU）** が必要です。

#### オプション A: Fabric 試用版（無料・60日間、推奨）

テナントで試用版が有効な場合、Azure リソースの作成なしに利用できます。

1. [Microsoft Fabric ポータル](https://app.fabric.microsoft.com) にアクセス
2. 右上のユーザーアイコン →「**無料試用版を開始**」をクリック
3. 「試用版の容量が有効になりました」と表示されたことを確認

> 試用版ボタンが表示されない（テナントで無効化されている）場合は、オプション B に進んでください。

#### オプション B: Azure ポータルで Fabric 容量を作成（有償）

1. [Azure ポータル](https://portal.azure.com) にアクセス
2. 「**リソースの作成**」→ 検索欄に `Microsoft Fabric` と入力 →「**Microsoft Fabric**」を選択
3. 以下の設定で作成：
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `rg-fabric-dataagent-poc`
   - **容量名**: `fabriccappoc`（グローバルで一意の名前）
   - **リージョン**: `Japan East`
   - **サイズ**: `F2`（PoC 用最小構成）
   - **Fabric 容量管理者**: ログイン中のユーザーを指定
4. 「**確認および作成**」→「**作成**」をクリックし、デプロイ完了を待つ

#### オプション B: Azure CLI で Fabric 容量を作成（有償）

```powershell
# Fabric 拡張機能をインストール（初回のみ）
az extension add --name microsoft-fabric

# Fabric 容量の作成（<subscription-id> と <your-email@domain.com> を置換）
az rest --method PUT `
    --url "https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/rg-fabric-dataagent-poc/providers/Microsoft.Fabric/capacities/fabriccappoc?api-version=2023-11-01" `
    --body '{"location":"japaneast","sku":{"name":"F2","tier":"Fabric"},"properties":{"administration":{"members":["<your-email@domain.com>"]}}}'
```

> **コスト注意**: F2 は約 \$262/月（Japan East）です。PoC 終了後は必ず一時停止または削除してください。  
> 一時停止: Azure ポータル → 作成した Fabric 容量 →「**一時停止**」

### タスク 1-7: Fabric ワークスペースの作成 （ポータル操作）

1. [Microsoft Fabric ポータル](https://app.fabric.microsoft.com) にブラウザでアクセス
2. 左サイドバー下部「**ワークスペース**」→「**+ 新しいワークスペース**」をクリック
3. 以下の設定でワークスペースを作成：
   - **名前**: `ManufacturingDataAgentPoC`
   - **説明**: `製造業 Data Agent PoC`
   - **ライセンスモード**: Fabric（Trial または購入済みライセンスを選択）
4. 「**適用**」をクリックして作成を確認

### タスク 1-8: Fabric Lakehouse の作成 （ポータル操作）

1. 作成したワークスペース内で「**+ 新規**」→「**Lakehouse**」をクリック
2. 名前: `manufacturing_lakehouse` で作成
3. 左サイドバーの「**ファイル**」に右クリック →「**新しいサブフォルダー**」で以下を作成：
   - `product_specs`
   - `work_manuals`
   - `parts_catalog`
   - `quality_standards`

### タスク 1-9: 非構造化データの OneLake 直接アップロード（ショートカット作成）

> **認証方式**: このプロジェクトは **Workspace Identity（Managed Identity）** を使用します。  
> アカウントキー・SAS トークンは使用しません。

1. Lakehouse のファイルセクションで「**ショートカット**」→「**Azure Data Lake Storage Gen2（または Blob Storage）**」を選択
2. 接続情報を入力：
   - **URL**: `https://<storage-account>.blob.core.windows.net`
   - **認証の種類**: `組織のアカウント（ワークスペース ID）` または `Workspace Identity` を選択
   - ※ アカウントキー・SAS・接続文字列は **選択しない**こと
3. コンテナ `manufacturing-docs` を選択し、ショートカットを Lakehouse のファイルセクションに追加

> **事前確認（ショートカット作成に失敗する場合）**  
> Fabric ワークスペース設定 →「**ワークスペース ID**」→ Object ID をコピーして以下を実行:  
> ```powershell
> .\scripts\04_assign_rbac.ps1 -FabricWorkspaceMiObjectId "<Object ID>"
> ```

### タスク 1-10: 構造化データ CSV ファイルの内容確認

```powershell
# CSV ファイルの一覧と容量を確認
Get-ChildItem -Path ".\data\structured" -Filter "*.csv" | Select-Object Name, Length

# ファイルの先頭行を確認（例: dim_products.csv）
Get-Content ".\data\structured\dim_products.csv" | Select-Object -First 5
```

期待されるファイル（8 件）:
- `dim_products.csv`, `dim_processes.csv`, `dim_parts.csv`, `dim_workers.csv`
- `fact_production_orders.csv`, `fact_process_results.csv`, `fact_parts_usage.csv`, `fact_quality_inspections.csv`

### タスク 1-11: Sprint 1 完了レビュー

下記「確認チェックリスト」全項目をパスしていることを確認し、チームでレビュー後に Sprint 2 へ進みます。

---

## 確認チェックリスト

| 項目 | 確認方法 | 合否 |
|---|---|---|
| Azure Storage にファイルが存在 | `az storage blob list` コマンドまたは Azure ポータル | |
| Fabric ワークスペースが存在 | Fabric ポータルで確認 | |
| Lakehouse のファイルセクションにデータが見える | Fabric ポータルで確認 | |

---

## トラブルシューティング

| 問題 | 原因 | 対処 |
|---|---|---|
| `az login` でブラウザが開かない | ヘッドレス環境 | `az login --use-device-code` を使用 |
| Storage Account 名が重複エラー | 名前がグローバルで一意である必要あり | ランダムな数字を付与して再試行 |
| Fabric ライセンスが見つからない | テナントで Fabric が有効でない | IT 管理者に Fabric ライセンスを確認 |
| Lakehouse ショートカットで認証エラー | Fabric Workspace MI への RBAC ロール未付与 | `04_assign_rbac.ps1` を実行して `Storage Blob Data Reader` ロールを付与。Fabric ポータル → ワークスペース設定 → ワークスペース ID で Object ID を確認後、スクリプトに渡す |

---

## Sprint 1 完了後の次のステップ

✅ Sprint 1 完了 → [Sprint 2: Fabric Warehouse 構築](../sprint2/README.md) へ進む

### タスク 1-6: Azure Fabric 容量の作成

Fabric ワークスペースで Fabric ライセンスモードを利用するには、Azure サブスクリプション上に **Fabric 容量（F-SKU）** が必要です。

#### オプション A: Fabric 試用版（無料・60日間、推奨）

テナントで試用版が有効な場合、Azure リソースの作成なしに利用できます。

1. [Microsoft Fabric ポータル](https://app.fabric.microsoft.com) にアクセス
2. 右上のユーザーアイコン →「**無料試用版を開始**」をクリック
3. 「試用版の容量が有効になりました」と表示されたことを確認

> 試用版ボタンが表示されない（テナントで無効化されている）場合は、オプション B に進んでください。

#### オプション B: Azure ポータルで Fabric 容量を作成（有償）

1. [Azure ポータル](https://portal.azure.com) にアクセス
2. 「**リソースの作成**」→ 検索欄に `Microsoft Fabric` と入力 →「**Microsoft Fabric**」を選択
3. 以下の設定で作成：
   - **サブスクリプション**: 使用するサブスクリプション
   - **リソース グループ**: `rg-fabric-dataagent-poc`
   - **容量名**: `fabriccappoc`（グローバルで一意の名前）
   - **リージョン**: `Japan East`
   - **サイズ**: `F2`（PoC 用最小構成）
   - **Fabric 容量管理者**: ログイン中のユーザーを指定
4. 「**確認および作成**」→「**作成**」をクリックし、デプロイ完了を待つ

#### オプション B: Azure CLI で Fabric 容量を作成（有償）

```powershell
# Fabric 拡張機能をインストール（初回のみ）
az extension add --name microsoft-fabric

# Fabric 容量の作成（<subscription-id> と <your-email@domain.com> を置換）
az rest --method PUT `
    --url "https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/rg-fabric-dataagent-poc/providers/Microsoft.Fabric/capacities/fabriccappoc?api-version=2023-11-01" `
    --body '{"location":"japaneast","sku":{"name":"F2","tier":"Fabric"},"properties":{"administration":{"members":["<your-email@domain.com>"]}}}'
```

> **コスト注意**: F2 は約 \$262/月（Japan East）です。PoC 終了後は必ず一時停止または削除してください。  
> 一時停止: Azure ポータル → 作成した Fabric 容量 →「**一時停止**」
