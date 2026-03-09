# Sprint 2: Fabric Warehouse 構築・セマンティックモデル定義

**期間**: 1週間  
**目標**: Fabric Warehouse にテーブルを作成してダミーデータを投入し、Power BI セマンティックモデルを定義する  
**前提**: [Sprint 1](../sprint1/README.md) 完了済み  
**ステータス**: 🔲 未着手

---

## Sprint 2 の完了条件 (Definition of Done)

- [ ] Fabric Warehouse が作成されており、全テーブル・ビューが存在する
- [ ] ダミーデータ（CSV）が全テーブルに投入されている
- [ ] Power BI セマンティックモデルが作成され、テーブル間リレーションが設定されている
- [ ] セマンティックモデルに DAX メジャーが追加されている
- [ ] Power BI レポート（動作確認用）で基本集計が表示できる

---

## タスク一覧

| # | タスク | 担当 | ステータス |
|---|---|---|---|
| 2-1 | Fabric Warehouse の作成 | Fabric担当 | 🔲 |
| 2-2 | テーブル定義 SQL の実行 | Fabric担当 | 🔲 |
| 2-3 | ダミーデータ（CSV）のアップロード・投入 | データ担当 | 🔲 |
| 2-4 | データ投入の検証クエリ実行 | データ担当 | 🔲 |
| 2-5 | セマンティックモデルの新規作成 | BI担当 | 🔲 |
| 2-6 | テーブル間リレーションの設定 | BI担当 | 🔲 |
| 2-7 | テーブルの日本語説明文の入力 | BI担当 | 🔲 |
| 2-8 | DAX メジャーの作成 | BI担当 | 🔲 |
| 2-9 | 動作確認用 Power BI レポートの作成 | BI担当 | 🔲 |
| 2-10 | Sprint 2 完了レビュー | 全員 | 🔲 |

---

## 手順詳細

### Step 1: Fabric Warehouse の作成

1. Fabric ポータルの `ManufacturingDataAgentPoC` ワークスペースを開く
2. 「**+ 新規**」→「**Warehouse**」をクリック
3. 名前: `manufacturing_warehouse` で作成

### Step 2: テーブル定義 SQL の実行

1. Warehouse を開き、上部の「**新しいクエリ**」をクリック
2. [schema/create_tables.sql](../schema/create_tables.sql) の内容をコピー&ペーストして実行
3. ディメンションテーブル（dim_*）を先に、次にファクトテーブル（fact_*）を実行するために、スクリプトを分割して順番に実行

```sql
-- 実行確認クエリ（全テーブルの存在確認）
SELECT TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo'
ORDER BY TABLE_NAME;
```

### Step 3: ダミーデータの投入

#### オプション A: PowerShell スクリプトで自動投入

```powershell
# Fabric REST API もしくは COPY INTO を使用したデータ投入
.\scripts\03_load_structured_data.ps1
```

#### オプション B: Fabric ポータルから手動投入（CSV インポート）

1. Warehouse のツールバー「**データの取得**」→「**ファイルからアップロード**」
2. 各 CSV ファイルを対応するテーブルにインポート
   - `data/structured/dim_products.csv` → `dim_products`
   - `data/structured/dim_processes.csv` → `dim_processes`
   - `data/structured/dim_parts.csv` → `dim_parts`
   - `data/structured/dim_workers.csv` → `dim_workers`
3. ファクトテーブルも同様に投入（dim_* のあとに実施）

#### オプション C: T-SQL の COPY INTO コマンド

```sql
-- Fabric Warehouse では COPY INTO でステージングから直接投入可能
-- まず CSV を OneLake の Files セクションにアップロードしてから実行

COPY INTO dbo.dim_products
FROM 'https://<onelake-path>/manufacturing_lakehouse.Lakehouse/Files/csv/dim_products.csv'
WITH (
    FILE_TYPE = 'CSV',
    FIRSTROW = 2,  -- ヘッダー行をスキップ
    FIELDTERMINATOR = ','
);
```

### Step 4: データ投入確認クエリ

```sql
-- 件数確認
SELECT 'dim_products'              AS table_name, COUNT(*) AS row_count FROM dim_products
UNION ALL SELECT 'dim_processes',   COUNT(*) FROM dim_processes
UNION ALL SELECT 'dim_parts',       COUNT(*) FROM dim_parts
UNION ALL SELECT 'dim_workers',     COUNT(*) FROM dim_workers
UNION ALL SELECT 'fact_production_orders', COUNT(*) FROM fact_production_orders
UNION ALL SELECT 'fact_process_results',   COUNT(*) FROM fact_process_results
UNION ALL SELECT 'fact_parts_usage',       COUNT(*) FROM fact_parts_usage
UNION ALL SELECT 'fact_quality_inspections', COUNT(*) FROM fact_quality_inspections;

-- ユースケース動作確認クエリ（UC-01: 今月の製造完了数）
SELECT
    p.product_name,
    SUM(po.actual_qty) AS completed_qty
FROM fact_production_orders po
INNER JOIN dim_products p ON po.product_id = p.product_id
WHERE po.order_status = '完了'
  AND YEAR(po.actual_end_date) = 2026
  AND MONTH(po.actual_end_date) = 2  -- 2月の例
GROUP BY p.product_name
ORDER BY completed_qty DESC;

-- ユースケース動作確認クエリ（UC-02: 検査不合格品の工程と部材）
SELECT
    qi.inspection_id,
    po.order_id,
    p.product_name,
    proc.process_name,
    qi.inspection_item,
    qi.measured_value,
    qi.pass_fail,
    qi.notes
FROM fact_quality_inspections qi
INNER JOIN fact_process_results pr ON qi.result_id = pr.result_id
INNER JOIN fact_production_orders po ON pr.order_id = po.order_id
INNER JOIN dim_products p ON po.product_id = p.product_id
INNER JOIN dim_processes proc ON pr.process_id = proc.process_id
WHERE qi.pass_fail = '不合格';
```

### Step 5: セマンティックモデルの作成

1. ワークスペースで「**+ 新規**」→「**セマンティックモデル**」をクリック
2. 名前: `manufacturing_semantic_model`
3. データソースとして `manufacturing_warehouse` を選択
4. 以下のテーブルをすべて追加：
   - `dim_products`, `dim_processes`, `dim_parts`, `dim_workers`
   - `fact_production_orders`, `fact_process_results`, `fact_parts_usage`, `fact_quality_inspections`

### Step 6: リレーションの設定

「モデルビュー」でリレーションを設定。[semantic_model/model_definition.md](../semantic_model/model_definition.md) のセクション 2 を参照。

テーブル間の線をドラッグして接続、カーディナリティを「多:1」に設定。

### Step 7: テーブルの説明文の入力

各テーブルを選択 → 右パネルの「**説明**」フィールドに  
[semantic_model/model_definition.md](../semantic_model/model_definition.md) セクション 3 の説明文を入力。

> ⚠️ **重要**: Data Agent の回答精度はテーブル説明文の品質に大きく依存します。正確で詳細な説明を入力してください。

### Step 8: DAX メジャーの追加

「データビュー」でホームテーブル（`fact_production_orders`）を選択 → 「**新しいメジャー**」で各 DAX を入力。  
[semantic_model/model_definition.md](../semantic_model/model_definition.md) セクション 4 の DAX コードを参照。

### Step 9: 動作確認レポートの作成

1. セマンティックモデルから「**レポートの作成**」をクリック
2. 基本的なビジュアルを追加して集計が正しく表示されることを確認：
   - カード: 完了台数、計画台数
   - 棒グラフ: 製品別完了台数
   - テーブル: 不合格検査一覧

---

## 期待されるデータ量（ダミーデータ）

| テーブル | 期待件数 |
|---|---|
| dim_products | 5件 |
| dim_processes | 6件 |
| dim_parts | 20件 |
| dim_workers | 12件 |
| fact_production_orders | 15件 |
| fact_process_results | 25件 |
| fact_parts_usage | 32件 |
| fact_quality_inspections | 20件 |

---

## Sprint 2 完了後の次のステップ

✅ Sprint 2 完了 → [Sprint 3: Fabric Data Agent 作成](../sprint3/README.md) へ進む
