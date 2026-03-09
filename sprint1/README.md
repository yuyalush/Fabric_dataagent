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
| 1-6 | Fabric ワークスペースの作成（fab CLI） | Fabric担当 | ✅ |
| 1-7 | Fabric Lakehouse の作成 | Fabric担当 | ✅ |
| 1-8 | 非構造化データの OneLake 直接アップロード | Fabric担当 | ✅ |
| 1-9 | 構造化データ CSV ファイルの内容確認 | データ担当 | ✅ |
| 1-10 | Sprint 1 完了レビュー | 全員 | ✅ |

---

## 手順詳細

### Step 1: 前提ツールの確認

```powershell
# Azure CLI のバージョン確認 (2.50 以上推奨)
az --version

# Azure にログイン
az login

# サブスクリプションの確認・設定
az account list --output table
az account set --subscription "<your-subscription-id>"
```

### Step 2: Azure リソースの作成

```powershell
# 環境変数の設定
$RESOURCE_GROUP = "rg-fabric-dataagent-poc"
$LOCATION       = "japaneast"
$STORAGE_ACCOUNT = "stfabricdatapoc$(Get-Random -Minimum 1000 -Maximum 9999)"  # 一意の名前
$CONTAINER       = "manufacturing-docs"

# Resource Group の作成
az group create `
    --name $RESOURCE_GROUP `
    --location $LOCATION

# Storage Account の作成
az storage account create `
    --name $STORAGE_ACCOUNT `
    --resource-group $RESOURCE_GROUP `
    --location $LOCATION `
    --sku Standard_LRS `
    --kind StorageV2 `
    --allow-blob-public-access false `
    --min-tls-version TLS1_2

# Blob コンテナの作成
az storage container create `
    --name $CONTAINER `
    --account-name $STORAGE_ACCOUNT `
    --auth-mode login
```

### Step 3: 非構造化データのアップロード

```powershell
# セットアップスクリプトを実行（プロジェクトルートから）
.\scripts\01_setup_azure_storage.ps1
.\scripts\02_upload_unstructured_data.ps1
```

> 詳細は [scripts/01_setup_azure_storage.ps1](../scripts/01_setup_azure_storage.ps1) を参照

### Step 4: Fabric ワークスペースの作成 （ポータル操作）

1. [Microsoft Fabric ポータル](https://app.fabric.microsoft.com) にブラウザでアクセス
2. 左サイドバー下部「**ワークスペース**」→「**+ 新しいワークスペース**」をクリック
3. 以下の設定でワークスペースを作成：
   - **名前**: `ManufacturingDataAgentPoC`
   - **説明**: `製造業 Data Agent PoC`
   - **ライセンスモード**: Fabric（Trial または購入済みライセンスを選択）
4. 「**適用**」をクリックして作成を確認

### Step 5: Fabric Lakehouse の作成 （ポータル操作）

1. 作成したワークスペース内で「**+ 新規**」→「**Lakehouse**」をクリック
2. 名前: `manufacturing_lakehouse` で作成
3. 左サイドバーの「**ファイル**」に右クリック →「**新しいサブフォルダー**」で以下を作成：
   - `product_specs`
   - `work_manuals`
   - `parts_catalog`
   - `quality_standards`

### Step 6: Azure Storage → Fabric OneLake へのショートカット作成

1. Lakehouse のファイルセクションで「**ショートカット**」→「**Azure Data Lake Storage Gen2（または Blob Storage）**」を選択
2. Azure Storage の接続情報を入力：
   - URL: `https://<storage-account>.blob.core.windows.net`
   - コンテナ: `manufacturing-docs`
3. 各フォルダをショートカットとして Lakehouse に追加

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
| Lakehouse ショートカットで認証エラー | マネージド ID or 接続文字列の誤り | 認証方式を「アカウントキー」に変えて試す |

---

## Sprint 1 完了後の次のステップ

✅ Sprint 1 完了 → [Sprint 2: Fabric Warehouse 構築](../sprint2/README.md) へ進む
