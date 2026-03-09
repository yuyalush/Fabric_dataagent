# Fabric Data Agent PoC — 製造業向け製造工程データ対話システム

> **PoC 概要**: Microsoft Fabric Data Agent を活用し、製造業の工程データ（構造化 + 非構造化）に自然言語で対話できる環境を構築する。

## ドキュメント構成

| ドキュメント | 概要 |
|---|---|
| [concept.md](concept.md) | PoC のコンセプト・アーキテクチャ・ユースケース定義 |
| [sprint1/README.md](sprint1/README.md) | Sprint 1: 環境準備・ダミーデータ投入 |
| [sprint2/README.md](sprint2/README.md) | Sprint 2: Fabric Warehouse 構築・セマンティックモデル定義 |
| [sprint3/README.md](sprint3/README.md) | Sprint 3: Fabric Data Agent 作成・動作確認 |
| [sprint4/README.md](sprint4/README.md) | Sprint 4: M365 Copilot 統合・総合テスト |

---

## リポジトリ構造

```
Fabric_dataagent/
├── concept.md                        # PoC コンセプト文書
├── README.md                         # 本ファイル
│
├── data/
│   ├── structured/                   # 構造化ダミーデータ (CSV)
│   │   ├── dim_products.csv          # 製品マスタ
│   │   ├── dim_processes.csv         # 製造工程マスタ
│   │   ├── dim_parts.csv             # 部材マスタ
│   │   ├── dim_workers.csv           # 作業者マスタ
│   │   ├── fact_production_orders.csv # 製造指示
│   │   ├── fact_process_results.csv  # 工程作業実績
│   │   ├── fact_parts_usage.csv      # 部材使用実績
│   │   └── fact_quality_inspections.csv # 品質検査結果
│   │
│   └── unstructured/                 # 非構造化ダミーデータ (Markdown)
│       ├── product_specs/            # 製品仕様書
│       │   ├── PROD-001_inverter_controller.md
│       │   └── PROD-002_servo_driver.md
│       ├── work_manuals/             # 作業手順書 (SOP)
│       │   ├── WM-PROC001_pcb_assembly.md
│       │   ├── WM-PROC002_housing_assembly.md
│       │   ├── WM-PROC003_wiring.md
│       │   └── WM-PROC004_function_test.md
│       ├── parts_catalog/            # 部材カタログ
│       │   ├── PC-PART001_igbt_module.md
│       │   └── PC-PART004_control_board.md
│       └── quality_standards/        # 品質基準書
│           ├── QS-PROD001_inverter.md
│           └── QS-PROD002_servo.md
│
├── schema/
│   └── create_tables.sql             # Fabric Warehouse テーブル定義
│
├── semantic_model/
│   └── model_definition.md           # セマンティックモデル定義書
│
├── scripts/
│   ├── 01_setup_azure_storage.ps1    # Azure Blob Storage 初期設定
│   ├── 02_upload_unstructured_data.ps1 # 非構造化データのアップロード
│   └── 03_load_structured_data.ps1   # 構造化データの Fabric 投入
│
├── sprint1/
│   └── README.md                     # Sprint 1 作業ガイド
├── sprint2/
│   └── README.md                     # Sprint 2 作業ガイド
├── sprint3/
│   └── README.md                     # Sprint 3 作業ガイド
└── sprint4/
    └── README.md                     # Sprint 4 作業ガイド
```

---

## クイックスタート

### 前提条件の確認

```powershell
# Azure CLI のバージョン確認
az --version

# Fabric CLI (fab) の確認
fab --version

# PowerShell バージョン確認 (7.0 以上推奨)
$PSVersionTable.PSVersion
```

### 環境変数の設定

```powershell
# Azure 設定
$env:AZURE_SUBSCRIPTION_ID = "<your-subscription-id>"
$env:AZURE_RESOURCE_GROUP   = "rg-fabric-dataagent-poc"
$env:AZURE_LOCATION         = "japaneast"
$env:AZURE_STORAGE_ACCOUNT  = "stfabricdataagentpoc"
$env:AZURE_CONTAINER_NAME   = "manufacturing-docs"

# Fabric 設定
$env:FABRIC_WORKSPACE_NAME  = "ManufacturingDataAgentPoC"
$env:FABRIC_WAREHOUSE_NAME  = "manufacturing_warehouse"
```

### セットアップ実行順序

```powershell
# 1. Azure Storage のセットアップ
.\scripts\01_setup_azure_storage.ps1

# 2. 非構造化データのアップロード
.\scripts\02_upload_unstructured_data.ps1

# 3. 構造化データの Fabric 投入（Sprint 2 完了後）
.\scripts\03_load_structured_data.ps1
```

---

## スプリント進捗

| スプリント | 状態 | 完了条件 |
|---|---|---|
| [Sprint 1](sprint1/README.md): 環境準備 | 🔲 未着手 | Azure Storage・Fabric Workspace が設定済み、ダミーデータが手元にある |
| [Sprint 2](sprint2/README.md): データ基盤構築 | 🔲 未着手 | Warehouse にテーブルが存在し、セマンティックモデルが Fabric に登録済み |
| [Sprint 3](sprint3/README.md): Data Agent 構築 | 🔲 未着手 | Data Agent に質問して SQL データから正しい回答が返る |
| [Sprint 4](sprint4/README.md): Copilot 統合 | 🔲 未着手 | M365 Copilot (Teams) から Data Agent 経由で質問・回答できる |

---

## 参考リンク

- [Microsoft Fabric Data Agent ドキュメント](https://learn.microsoft.com/fabric/data-science/data-agent)
- [Power BI セマンティックモデル作成ガイド](https://learn.microsoft.com/power-bi/transform-model/desktop-modeling-view)
- [Copilot Studio ドキュメント](https://learn.microsoft.com/microsoft-copilot-studio/)
- [Azure Blob Storage ドキュメント](https://learn.microsoft.com/azure/storage/blobs/)
