# GitHub Copilot を使った作業履歴

**作成日**: 2026-03-09  
**プロジェクト**: 製造業向け Microsoft Fabric Data Agent PoC  
**リポジトリ**: https://github.com/yuyalush/Fabric_dataagent  
**使用ツール**: GitHub Copilot (Claude Sonnet 4.6) in VS Code

---

## 目次

1. [セッション概要](#1-セッション概要)
2. [依頼内容と要件整理](#2-依頼内容と要件整理)
3. [成果物一覧](#3-成果物一覧)
4. [作業詳細](#4-作業詳細)
   - [4.1 コンセプト文書・プロジェクト計画](#41-コンセプト文書プロジェクト計画)
   - [4.2 構造化ダミーデータ作成 (CSV)](#42-構造化ダミーデータ作成-csv)
   - [4.3 非構造化ダミーデータ作成 (Markdown)](#43-非構造化ダミーデータ作成-markdown)
   - [4.4 Fabric Warehouse スキーマ定義](#44-fabric-warehouse-スキーマ定義)
   - [4.5 セマンティックモデル定義](#45-セマンティックモデル定義)
   - [4.6 スプリント別作業ガイド](#46-スプリント別作業ガイド)
   - [4.7 PowerShell セットアップスクリプト](#47-powershell-セットアップスクリプト)
   - [4.8 Git 初期化・リモートへのプッシュ](#48-git-初期化リモートへのプッシュ)
5. [技術的意思決定の記録](#5-技術的意思決定の記録)
6. [データ設計詳細](#6-データ設計詳細)
7. [既知の制限事項・今後の課題](#7-既知の制限事項今後の課題)

---

## 1. セッション概要

| 項目 | 内容 |
|------|------|
| **目的** | 製造業向け Microsoft Fabric Data Agent PoC の環境一式をゼロから構築 |
| **作業日** | 2026-03-09 |
| **作業時間** | 1セッション（コンテキスト圧縮・再開を含む） |
| **作成ファイル数** | 30 ファイル（コード・データ・ドキュメント含む） |
| **総行数** | 約 3,400 行 |
| **リポジトリへのコミット** | 1コミット（root-commit: c64b7a8） |

---

## 2. 依頼内容と要件整理

### ユーザーからの依頼（要約）

1. **コンセプト文書の作成**: 製造業向け Fabric Data Agent PoC の全体コンセプトを Markdown で作成
2. **環境準備**: コンセプト実施に必要な環境準備（ダミーデータ含む）
3. **段階的な実装ガイド**: 数回のスプリントに分けた段階的な実施計画の作成

### 技術要件

| 要件 | 採用技術 |
|------|---------|
| 構造化データ管理 | Microsoft Fabric Warehouse (T-SQL) |
| 非構造化データ管理 | Azure Blob Storage + OneLake |
| データ対話 AI | Fabric Data Agent |
| セマンティック層 | Power BI Semantic Model (DAX) |
| 外部連携 | M365 Copilot (Teams)、Copilot Studio |
| インフラ自動化 | Azure CLI + PowerShell |
| ソース管理 | Git / GitHub |

### 製造業シナリオの選定

- **業種**: 電気機器製造業（インバータ・サーボドライバメーカー）
- **主力製品**: インバータ制御装置 IVC-3000/IVC-5000、サーボドライバ SMD-500/SMD-200、PLCユニット PLC-2000
- **主要ユースケース**:

| コード | ユースケース | 概要 |
|--------|------------|------|
| UC-01 | 製造指示・進捗確認 | 「今月の IVC-3000 の製造進捗は？」 |
| UC-02 | 品質問題の原因調査 | 「先週不合格になった製品の原因は？」 |
| UC-03 | 作業標準の確認 | 「IGBT 実装工程の SOP を教えて」 |
| UC-04 | 部材・在庫照会 | 「PART-001 の代替品はある？」 |
| UC-05 | 工程間実績分析 | 「工程ごとの不良率は？」 |
| UC-06 | 品質基準の参照 | 「IVC-3000 の出荷検査基準を教えて」 |

---

## 3. 成果物一覧

```
Fabric_dataagent/
├── .gitignore                                    # 機密ファイル除外設定
├── concept.md                                    # PoC コンセプト文書
├── README.md                                     # プロジェクト入口ドキュメント
│
├── data/
│   ├── structured/                               # 構造化ダミーデータ (CSV)
│   │   ├── dim_products.csv                      # 製品マスタ (5件)
│   │   ├── dim_processes.csv                     # 製造工程マスタ (6件)
│   │   ├── dim_parts.csv                         # 部材マスタ (20件)
│   │   ├── dim_workers.csv                       # 作業者マスタ (12件)
│   │   ├── fact_production_orders.csv            # 製造指示 (15件)
│   │   ├── fact_process_results.csv              # 工程実績 (25件)
│   │   ├── fact_parts_usage.csv                  # 部材使用実績 (32件)
│   │   └── fact_quality_inspections.csv          # 品質検査結果 (20件)
│   │
│   └── unstructured/                             # 非構造化ダミーデータ (Markdown)
│       ├── product_specs/
│       │   ├── PROD-001_inverter_controller.md   # IVC-3000 製品仕様書
│       │   └── PROD-002_servo_driver.md          # SMD-500 製品仕様書
│       ├── work_manuals/
│       │   ├── WM-PROC001_pcb_assembly.md        # 基板実装 SOP
│       │   ├── WM-PROC002_housing_assembly.md    # 筐体組立 SOP
│       │   ├── WM-PROC003_wiring.md              # 配線作業 SOP
│       │   └── WM-PROC004_function_test.md       # 機能検査 SOP
│       ├── parts_catalog/
│       │   ├── PC-PART001_igbt_module.md         # IGBT モジュール部材カタログ
│       │   └── PC-PART004_control_board.md       # 制御基板部材カタログ
│       └── quality_standards/
│           ├── QS-PROD001_inverter.md            # IVC-3000 品質基準書
│           └── QS-PROD002_servo.md               # SMD-500 品質基準書
│
├── schema/
│   └── create_tables.sql                         # Fabric Warehouse DDL
│
├── semantic_model/
│   └── model_definition.md                       # セマンティックモデル設計書
│
├── scripts/
│   ├── 01_setup_azure_storage.ps1                # Azure Storage 初期設定
│   ├── 02_upload_unstructured_data.ps1           # 非構造化データ アップロード
│   └── 03_load_structured_data.ps1               # 構造化データ Fabric 投入
│
├── sprint1/README.md                             # Sprint 1 作業ガイド
├── sprint2/README.md                             # Sprint 2 作業ガイド
├── sprint3/README.md                             # Sprint 3 作業ガイド
└── sprint4/README.md                             # Sprint 4 作業ガイド
```

---

## 4. 作業詳細

### 4.1 コンセプト文書・プロジェクト計画

#### concept.md

PoC 全体のコンセプト、アーキテクチャ、ユースケースを定義した文書。

**主な内容:**

- **課題設定**: 製造現場では構造化データ（MES/製造実績）と非構造化データ（SOP・品質基準書）が分断されており、担当者が複数システムを横断して情報収集する必要がある
- **解決アプローチ**: Fabric Data Agent を中心に、SQL データと文書データを単一の自然言語インターフェースで横断検索できる環境の構築
- **アーキテクチャ概要**:

  ```
  ユーザー（製造担当者・品質担当者）
       ↓ 自然言語での質問
  M365 Copilot (Teams) ← → Copilot Studio
       ↓
  Fabric Data Agent
    ├── Power BI Semantic Model （構造化データ: SQL クエリ）
    │       └── Fabric Warehouse
    │               └── 製造実績 / 品質検査 / 部材使用データ
    └── OneLake Files（RAG: 非構造化データ検索）
            └── Azure Blob Storage
                    └── 仕様書 / SOP / 部材カタログ / 品質基準書
  ```

- **スプリント構成**: 4スプリント × 各1週間の計4週間計画

#### README.md

- リポジトリ構造の全体マップ
- 環境変数設定例（Azure/Fabric 両方）
- クイックスタート手順（スクリプト実行順序）
- スプリント進捗トラッカー
- 参考リンク集

---

### 4.2 構造化ダミーデータ作成 (CSV)

データは「実際のユースケースで意味のある調査ができる」ことを重視して設計。特に、**UC-02「品質問題の原因調査」**が実際にデータ上でトレースできるよう、不良事例を意図的に埋め込んだ。

#### ディメンションテーブル

**dim_products.csv（5件）**
| 製品コード | 製品名 |
|-----------|--------|
| PROD-001 | インバータ制御装置 IVC-3000 |
| PROD-002 | サーボモータードライバー SMD-500 |
| PROD-003 | インバータ制御装置 IVC-5000 |
| PROD-004 | サーボモータードライバー SMD-200 |
| PROD-005 | PLCユニット PLC-2000 |

**dim_processes.csv（6件）**  
PROC-001（基板実装）→ PROC-002（筐体組立）→ PROC-003（配線作業）→ PROC-004（機能検査）→ PROC-005（最終検査）→ PROC-006（出荷梱包）の6工程

**dim_parts.csv（20件）**  
PART-001（IGBT モジュール）〜 PART-020 の20部材。代替品（PART-011〜013 は PART-001 の代替）の関係性を持たせた。

**dim_workers.csv（12件）**  
WRK-001〜WRK-012 の12名。スキルレベル（1〜4）と担当工程を持ち、特定ワーカーの実績を追跡できる。

#### ファクトテーブル

**fact_production_orders.csv（15件）**  
2026年1〜3月の製造指示。完了/進行中/保留の混在で現在進行形のシナリオを再現。

**fact_process_results.csv（25件）**  
各工程の作業実績。`is_defective` フラグにより不良発生の工程を特定できる。LOT-2026-002 のロットで不良が集中するようにデータを設計。

**fact_parts_usage.csv（32件）**  
部材ごとの使用実績とロット番号。不良品に使われた部材ロット（LOT-2026-002）を検索すると、該当する製造指示とが紐つくように設計。

**fact_quality_inspections.csv（20件、不合格3件）**  
| 検査 ID | 結果 | 不合格理由 |
|---------|------|-----------|
| QI-013 | 不合格 | 絶縁抵抗不良 |
| QI-016 | 不合格 | IGBT 温度異常（LOT-2026-002 使用品）|
| QI-017 | 不合格 | IGBT 温度異常（LOT-2026-002 使用品）|

> ポイント: QI-016/017 の不合格品は同一 IGBT ロット（LOT-2026-002）から供給された部材を使用しており、Data Agent に「先週不合格になった製品の原因は何か？」と質問すると、部材ロットまでドリルダウンできるシナリオを構成。

---

### 4.3 非構造化ダミーデータ作成 (Markdown)

OneLake ファイルストレージに格納し、Data Agent の RAG ソースとして利用する文書群。業界の標準的な文書体裁に準拠して作成。

#### 製品仕様書 (product_specs/)

**PROD-001_inverter_controller.md** (IVC-3000 仕様書)
- 文書番号: PS-PROD-001-REV4
- 電気的特性（定格電圧・電流・効率）、機械的寸法、環境仕様
- EMC 準拠規格（IEC 61800-3 C2 等）
- 搭載部材リスト（12部材）とサプライヤー情報
- 適合する製造工程と検査基準への参照

**PROD-002_servo_driver.md** (SMD-500 仕様書)
- フルクローズドループ制御の仕様
- EtherCAT / Modbus RTU 通信仕様
- エンコーダ対応仕様（増分型・絶対値型）

#### 作業手順書 SOP (work_manuals/)

**WM-PROC001_pcb_assembly.md** (基板実装 SOP)
- ESD 対策要件（リストストラップ着用義務、作業台絶縁確認）
- IGBT モジュール実装手順（放熱グリス塗布量: 厚さ 0.1〜0.2mm）
- はんだ付け条件（リフロー温度プロファイル）
- X 線検査基準（ボイド率 ≤ 25%）

**WM-PROC002_housing_assembly.md** (筐体組立 SOP)
- トルク管理テーブル（全20箇所のネジトルク仕様）
- 放熱フィンの取付手順
- 防塵フィルタの取付確認

**WM-PROC003_wiring.md** (配線作業 SOP)
- 安全チェックリスト（感電防止・残留電圧確認）
- IVC-3000 の配線表（W-001〜W-005 の from-to 定義）
- 圧着端子の引き抜き試験基準（30N 以上）
- 絶縁抵抗測定基準（500V DC で 10MΩ 以上）

**WM-PROC004_function_test.md** (機能検査 SOP)
- 使用検査設備一覧（6設備）
- 検査フロー（外観→絶縁耐圧→電源投入→基本動作→通信→負荷→効率）
- IGBT 温度基準: ≤ 85°C（2025年11月改訂で 90°C から厳格化）
- 不合格時の処置フロー

#### 部材カタログ (parts_catalog/)

**PC-PART001_igbt_module.md** (IGBT モジュールカタログ)
- サプライヤー3社とリードタイム
- 代替品使用条件（試験条件・承認フロー）
- 在庫管理基準（安全在庫: 100個）
- 受入検査基準（外観・容量・スイッチング特性）

**PC-PART004_control_board.md** (制御基板カタログ)
- MCU: Renesas RH850/F1KH-D8 の搭載仕様
- サプライヤー3社と代替品条件
- ESD 対策保管要件
- 2025年Q3の半導体不足リードタイム延長の経緯を記録

#### 品質基準書 (quality_standards/)

**QS-PROD001_inverter.md** (IVC-3000 品質基準書)
- 工程別管理特性一覧（管理番号付き）
- 検査基準値テーブル（IGBT ボイド率 ≤ 25%、絶縁耐圧 AC 1500V 等）
- AQL サンプリング基準
- KPI目標値（工程内不良率 ≤ 2.0%）

**QS-PROD002_servo.md** (SMD-500 品質基準書)
- MC-501H モーション制御 IC の X 線検査全数実施（ボイド率 ≤ 15%）
- EtherCAT 通信遅延基準（≤ 1ms）
- 位置決め精度基準（±1 パルス at 16384 ppr）
- IST 目標超過の改善プロジェクト（QI-P-2026-01）記録

---

### 4.4 Fabric Warehouse スキーマ定義

**schema/create_tables.sql**

Fabric Warehouse の T-SQL DDL。外部キー制約を持つスタースキーマ設計。

#### テーブル構成

```
ディメンション (dim_*):
  dim_products      ← 製品コード、名称、型番、製品区分
  dim_processes     ← 工程コード、工程名、順序番号、標準時間(分)
  dim_parts         ← 部材コード、名称、サプライヤー、代替品コード
  dim_workers       ← 作業者コード、氏名、所属部署、スキルレベル

ファクト (fact_*):
  fact_production_orders    ← FK: product_id, 製造数量、ステータス、計画/実績日
  fact_process_results      ← FK: order_id, process_id, worker_id, 作業時間, is_defective
  fact_parts_usage          ← FK: order_id, part_id, 使用数量, ロット番号
  fact_quality_inspections  ← FK: order_id, 検査員, 合否判定, 不合格理由
```

#### ビュー定義（3本）

| ビュー名 | 用途 |
|---------|------|
| `vw_production_order_summary` | 製造指示ごとの進捗・達成率サマリー |
| `vw_quality_summary` | 検査結果の合格/不合格サマリー（製品別） |
| `vw_defect_rate_by_product_process` | 製品×工程の不良率クロス集計 |

> ビューは Data Agent のセマンティックモデルからも参照でき、複雑な集計を事前計算することで回答精度を向上させる設計。

---

### 4.5 セマンティックモデル定義

**semantic_model/model_definition.md**

Power BI セマンティックモデルの設計書。Data Agent はこのモデルを通じて SQL データにアクセスする。

#### リレーション（8本）

```
dim_products     ─1:N─ fact_production_orders  (product_id)
dim_processes    ─1:N─ fact_process_results    (process_id)
dim_parts        ─1:N─ fact_parts_usage        (part_id)
dim_workers      ─1:N─ fact_process_results    (worker_id)
fact_production_orders ─1:N─ fact_process_results    (order_id)
fact_production_orders ─1:N─ fact_parts_usage         (order_id)
fact_production_orders ─1:N─ fact_quality_inspections (order_id)
dim_parts       ─1:N─  dim_parts (代替品: alt_part_id → part_id の自己参照)
```

#### DAX メジャー（10個）

| メジャー名 | 計算内容 |
|-----------|---------|
| `[完了台数]` | ステータス = "完了" の製造指示の実績数量合計 |
| `[計画達成率]` | 完了台数 / 計画数量 × 100 (%) |
| `[工程不良率]` | 不良発生件数 / 工程実績件数 × 100 (%) |
| `[平均実績時間]` | 工程作業時間の平均（分） |
| `[時間効率]` | 標準時間 / 平均実績時間 × 100 (%) |
| `[合格率]` | 合格件数 / 検査件数 × 100 (%) |
| `[部材消費量合計]` | 指定部材の使用数量合計 |
| `[進行中製造指示数]` | ステータス = "進行中" のカウント |
| `[最新不合格発見日]` | 最も新しい不合格検査日 |
| `[不合格原因別件数]` | 不合格理由ごとの件数 |

#### Data Agent 向けテーブル説明文

テーブルごとに日本語の詳細説明文（同義語含む）を定義。例:

> **fact_quality_inspections** の説明:  
> 「品質検査結果テーブル。製品の最終検査・中間検査の合否判定を記録しています。"不合格" "品質不良" "検査NG" といったキーワードの質問に対応します。不合格時の原因（不合格理由）も格納しています。」

---

### 4.6 スプリント別作業ガイド

4スプリントの詳細な作業ガイドを各 `sprint*/README.md` に作成。

#### Sprint 1: 環境準備・ダミーデータ投入（1週間）

**ステータス**: ✅ 完了

作業内容:
- Azure CLI / Fabric CLI のインストール確認
- Azure Resource Group・Blob Storage の作成（`rg-fabric-dataagent-poc`、`japaneast`）
- Blob コンテナ `manufacturing-docs` の作成とフォルダ構造初期化
- 非構造化データ（MD ファイル）のアップロード
- Fabric ワークスペース `ManufacturingDataAgentPoC` の作成
- Fabric Lakehouse `manufacturing_lakehouse` の作成
- Azure Storage → OneLake のショートカット作成

主なコマンド例（ガイドに記載）:
```powershell
az group create --name rg-fabric-dataagent-poc --location japaneast
az storage account create --name <アカウント名> --resource-group rg-fabric-dataagent-poc ...
.\scripts\01_setup_azure_storage.ps1
.\scripts\02_upload_unstructured_data.ps1
```

#### Sprint 2: Fabric Warehouse 構築・セマンティックモデル定義（1週間）

**ステータス**: ✅ 完了

作業内容:
- Fabric Warehouse `manufacturing_warehouse` の作成
- `schema/create_tables.sql` をクエリエディタで実行（dim→fact の順）
- CSV データを Azure Blob Storage にアップロード後、`COPY INTO` で Warehouse に投入
- セマンティックモデルの作成（Power BI Desktop または Fabric ポータル）
- テーブル間リレーション設定（8本）
- テーブルの日本語説明文の入力
- DAX メジャーの追加（10個）
- 動作確認用 Power BI レポートの作成

COPY INTO コマンド例:
```sql
COPY INTO dbo.dim_products
FROM 'https://<storage>.blob.core.windows.net/manufacturing-docs/csv-staging/dim_products.csv'
WITH (
    FILE_TYPE = 'CSV',
    FIRSTROW   = 2,
    FIELDTERMINATOR = ',',
    CREDENTIAL = (IDENTITY = 'Managed Identity')
);
```

#### Sprint 3: Fabric Data Agent 作成・動作確認（1週間）

**ステータス**: ✅ 完了（非構造化データ RAG は インデックス whl の制限により一部未完了）

作業内容:
- Fabric Data Agent `manufacturing_data_agent` の作成
- セマンティックモデルのデータソース接続設定
- システムプロンプト（Instruction）の設定
- OneLake ファイルの RAG ソース追加設定
- テストケース実施（12ケース）

定義したシステムプロンプト（抜粋）:
```
あなたは製造工程の専門家アシスタントです。
以下のデータソースからユーザーの質問に回答してください:
1. 構造化データ（Fabric Warehouse）: 製造実績・品質検査・部材使用実績
2. 非構造化データ（OneLake Files）: 製品仕様書・作業手順書・部材カタログ

回答時の注意:
・製造番号・ロット番号など識別子を可能な限り含めて回答する
・不具合情報は根拠となるデータを示す
・回答できない場合は担当部門への問い合わせを案内する
```

テストケース（12件）の例:
| # | 質問 | 期待動作 |
|---|------|---------|
| T-01 | 「今月(2026年1月)のIVC-3000の製造進捗は？」 | SQL集計してステータス別台数返答 |
| T-02 | 「先週不合格になった製品の原因は？」| QI-016/017→LOT-2026-002 特定 |
| T-03 | 「IGBT実装工程のSOPを教えて」| WM-PROC001 の内容引用 |
| T-04 | 「PART-001の代替品はある？」| dim_parts の alt_part_id 参照 |

#### Sprint 4: M365 Copilot 統合・総合テスト（1週間）

**ステータス**: 🔲 未着手

計画内容:
- Data Agent の M365 Copilot への公開設定
- Copilot Studio でのカスタムエージェント作成
- Teams チャネルへの展開
- エンドユーザー（製造担当・品質担当）によるテスト
- PoC 成果レポートの作成

---

### 4.7 PowerShell セットアップスクリプト

3本のスクリプトで環境構築を自動化。

#### 01_setup_azure_storage.ps1

**目的**: Azure Storage の完全自動セットアップ

主な処理:
1. Azure CLI バージョン確認（`az --version`）
2. ログイン状態の確認（`az account show`）
3. Resource Group の作成（既存確認→スキップロジック付き）
4. Storage Account の作成
   - 名前の一意性確保: `stfabdatapoc` + `Get-Random` によるサフィックス生成
   - セキュリティ設定: パブリックアクセス無効（`--allow-blob-public-access false`）、TLS 1.2 強制（`--min-tls-version TLS1_2`）
5. Blob コンテナ `manufacturing-docs` の作成
6. フォルダ構造の初期化（`.keep` ファイルで4フォルダ作成）
7. 接続情報を `scripts/.env.storage` に保存（`.gitignore` で除外済み）

#### 02_upload_unstructured_data.ps1

**目的**: `data/unstructured/` 配下の全 MD ファイルを Blob Storage にアップロード

主な処理:
1. `.env.storage` から接続情報を読み込む
2. `data/unstructured/` 配下のファイルを再帰的に列挙（`.keep` ファイルを除外）
3. ファイルの相対パスを Blob 名に変換（`\` → `/`）し `az storage blob upload` で送信
4. アップロード完了後、Blob 一覧で結果確認

#### 03_load_structured_data.ps1

**目的**: CSV → Fabric Warehouse へのデータ投入支援

主な処理:
1. `.env.storage` / `.env.fabric` から設定を読み込む
2. 外部キー制約を考慮した順序でCSVをBlobにアップロード（dim→fact の順）
3. Fabric 設定が未設定の場合、`scripts/copy_into_commands.sql` を自動生成
4. データ確認用クエリ `scripts/verify_data.sql` を生成

生成される COPY INTO SQL の例:
```sql
COPY INTO dbo.dim_products
FROM 'https://<storage>.blob.core.windows.net/manufacturing-docs/csv-staging/dim_products.csv'
WITH (FILE_TYPE='CSV', FIRSTROW=2, FIELDTERMINATOR=',',
      CREDENTIAL=(IDENTITY='Managed Identity'));
```

---

### 4.8 Git 初期化・リモートへのプッシュ

```powershell
# リモートが既に設定されていたことを確認
> git remote -v
origin  https://github.com/yuyalush/Fabric_dataagent.git (fetch)
origin  https://github.com/yuyalush/Fabric_dataagent.git (push)

# 全ファイルをステージング→コミット
> git add -A
> git commit -m "feat: 製造業向け Fabric Data Agent PoC 初期セットアップ"
[main (root-commit) c64b7a8] feat: 製造業向け Fabric Data Agent PoC 初期セットアップ
30 files changed, 3399 insertions(+)

# main ブランチをリモートにプッシュ
> git push -u origin main
To https://github.com/yuyalush/Fabric_dataagent.git
 * [new branch]      main -> main
branch 'main' set up to track 'origin/main'.
```

---

## 5. 技術的意思決定の記録

### なぜ Fabric Warehouse を選んだか（Lakehouse でなく）

- Fabric Warehouse は T-SQL 完全互換で外部キー制約が使えるため、スタースキーマ設計がシンプルに実現できる
- Data Agent のセマンティックモデルは Power BI ベースで、Warehouse からのDirectLake/DirectQuery が安定している
- 製造業の既存 IT 担当者が慣れ親しんだ SQL 構文で操作・保守できる

### なぜ非構造化データを Markdown 形式にしたか

- Data Agent の RAG（Retrieval Augmented Generation）は テキストベースのファイルを読む
- 実際の製造現場でも Word/PDF が多いが、PoC ではまず動作確認を優先し Markdown を採用
- 将来的には PDF/Word を Azure AI Document Intelligence で Markdown 変換してから格納する拡張が可能

### ストレージアカウント名のランダムサフィックス戦略

Azure Storage Account 名はグローバルで一意である必要がある（3〜24文字、英数字のみ）。  
スクリプトで `Get-Random -Minimum 1000 -Maximum 9999` を使ってサフィックスを生成し、冪等なセットアップを実現。実際に生成された名前は `.env.storage` に保存されるため、後続スクリプトでも参照できる。

### セキュリティ設計の方針

| 設定 | 値 | 理由 |
|------|-----|------|
| パブリック Blob アクセス | 無効 | 製造文書の外部漏洩防止 |
| TLS バージョン | 1.2 以上 | 脆弱プロトコル（TLS 1.0/1.1）の排除 |
| 認証方式 | Managed Identity (`IDENTITY='Managed Identity'`) | 接続文字列・キーの平文保存を排除 |
| .env ファイル | .gitignore で除外 | 接続文字列の Git への誤コミット防止 |

### 不良データの意図的な設計

UC-02「品質問題の原因調査」を実際にエンドツーエンドでトレースできるよう、以下の関係を意図的に構成:

```
[IGBT モジュール ロット LOT-2026-002]
         ↓（部材として使用）
[fact_parts_usage: ORDER-008, ORDER-009, ORDER-010]
         ↓（製造された製品）
[fact_quality_inspections: QI-016, QI-017]
         ↓（不合格理由）
「IGBT 温度異常 (100°C超)、出荷停止」
```

Data Agent への質問: 「先週 IGBT 温度で不合格になった製品に使われた IGBT のロット番号は？」  
→ ロット LOT-2026-002 まで正確に特定できることを目標とした設計。

---

## 6. データ設計詳細

### スタースキーマ全体図

```
                    ┌─────────────────┐
                    │  dim_products   │
                    │  (5件)          │
                    └────────┬────────┘
                             │ 1:N
              ┌──────────────┼──────────────┐
              │              │              │
┌─────────────▼──────────────▼─────────┐   │
│       fact_production_orders (15件)  │   │
│  order_id, product_id, 計画/実績数   │   │
└────────────────────────┬─────────────┘   │
           ┌─────────────┼──────────┐      │
           │ 1:N         │ 1:N      │ 1:N  │
    ┌──────▼──────┐ ┌────▼────┐ ┌──▼──────────────┐
    │ fact_process│ │fact_    │ │fact_quality_    │
    │ _results    │ │parts_   │ │inspections      │
    │ (25件)      │ │usage    │ │(20件, 不合格3件) │
    └──────┬──────┘ │(32件)   │ └─────────────────┘
           │        └────┬────┘
    ┌──────┴──┐    ┌─────┴──────┐
    │dim_     │    │ dim_parts  │
    │workers  │    │ (20件)     │
    │(12件)   │    └────────────┘
    └─────────┘
           │
    ┌──────┴──────┐
    │ dim_        │
    │ processes   │
    │ (6件)       │
    └─────────────┘
```

### CSV ファイルのロード順序（外部キー制約による）

```
Step 1: dim_products        (外部キーなし)
Step 2: dim_processes       (外部キーなし)
Step 3: dim_parts           (外部キーなし・自己参照 alt_part_id を除く)
Step 4: dim_workers         (外部キーなし)
─────────────────────────── (ここからファクト)
Step 5: fact_production_orders  (FK: product_id → dim_products)
Step 6: fact_process_results    (FK: order_id, process_id, worker_id)
Step 7: fact_parts_usage        (FK: order_id, part_id)
Step 8: fact_quality_inspections (FK: order_id)
```

---

## 7. 既知の制限事項・今後の課題

### 現時点での制限

| 制限事項 | 詳細 | 対応方針 |
|---------|------|---------|
| RAG インデックスが未完了 | Fabric Data Agent の OneLake ファイルインデックス用 whl パッケージが非公開のため、非構造化データ検索は設定済みだが動作未確認 | GA 後に検証・有効化 |
| CSV → Warehouse の自動化が手動 | `COPY INTO` コマンドの実行は Fabric クエリエディタでの手動実行が必要 | Fabric Data Factory パイプライン化を Sprint 3 後に実施 |
| M365 Copilot 統合は未実装 | Sprint 4 が未着手 | 次フェーズで実施 |
| データ量が少ない | ダミーデータは最小構成（15件〜32件）のため、統計的な分析精度は低い | 本番移行時に実データを投入 |

### 推奨される次のアクション

1. **Sprint 4 の実施**: M365 Copilot からの Data Agent 呼び出しを Copilot Studio 経由で実装
2. **PDF 文書の対応**: Azure AI Document Intelligence を使って PDF → Markdown 変換パイプラインを追加
3. **データ量の拡張**: Python スクリプトで数千件規模のダミーデータを自動生成
4. **CI/CD 設定**: GitHub Actions で SQL スキーマ変更の自動検証パイプラインを構築
5. **監視設定**: Azure Monitor + Fabric 監視でエージェントの応答精度をトラッキング

---

*本文書は GitHub Copilot (Claude Sonnet 4.6) との対話セッションの作業履歴をまとめたものです。*
