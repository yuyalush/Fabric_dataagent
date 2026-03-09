# Power BI セマンティックモデル定義書

**文書番号**: SM-DEF-001-REV1  
**対象**: Microsoft Fabric / Power BI セマンティックモデル  
**モデル名**: manufacturing_semantic_model  
**発行日**: 2026-03-09  

---

## 1. 概要

本セマンティックモデルは、Fabric Warehouse 上の製造工程データを Power BI および Fabric Data Agent から利用するための意味的定義を提供します。Data Agent はこのモデルを参照して、自然言語クエリを正確な DAX/SQL クエリに変換します。

---

## 2. テーブル構成とリレーション

```
dim_products (製品マスタ)
    │ 1
    │ ∞
fact_production_orders (製造指示)  ────────── dim_workers (作業者マスタ)
    │ 1                                              │ 1 (inspector)
    │ ∞                                              │
fact_process_results (工程作業実績) ─────────────────┘
    │ 1
    ├──∞── fact_parts_usage (部材使用実績)
    │           │ ∞
    │           │ 1
    │       dim_parts (部材マスタ)
    │
    └──∞── fact_quality_inspections (品質検査結果)

dim_processes (工程マスタ)
    │ 1
    │ ∞
fact_process_results (工程作業実績)
```

### リレーション定義

| From テーブル | From カラム | To テーブル | To カラム | カーディナリティ |
|---|---|---|---|---|
| fact_production_orders | product_id | dim_products | product_id | 多:1 |
| fact_process_results | order_id | fact_production_orders | order_id | 多:1 |
| fact_process_results | process_id | dim_processes | process_id | 多:1 |
| fact_process_results | worker_id | dim_workers | worker_id | 多:1 |
| fact_parts_usage | result_id | fact_process_results | result_id | 多:1 |
| fact_parts_usage | part_id | dim_parts | part_id | 多:1 |
| fact_quality_inspections | result_id | fact_process_results | result_id | 多:1 |
| fact_quality_inspections | inspector_id | dim_workers | worker_id | 多:1 |

---

## 3. テーブルの日本語説明（Data Agent 向け）

Data Agent がテーブルの意味を理解するための説明文です。Fabric Data Agent の「テーブル説明」フィールドに設定します。

### dim_products（製品マスタ）
```
製造する製品の基本情報を管理するマスタテーブルです。
製品ID、製品名、製品カテゴリ（インバータ/サーボドライバ/PLC等）、型番、
電圧・電流・出力の仕様値、質量などが含まれます。
「製品」「型番」「製品名」「製品カテゴリ」に関する質問はこのテーブルを参照します。
```

### dim_processes（製造工程マスタ）
```
製造の各工程（基板実装/筐体組立/配線作業/機能検査/最終検査/梱包）を定義するマスタテーブルです。
工程の順序、担当部署、標準作業時間、必要スキルレベルが含まれます。
「工程」「工程名」「工程順序」「標準時間」に関する質問はこのテーブルを参照します。
```

### dim_parts（部材マスタ）
```
製造に使用する部材・部品の情報を管理するマスタテーブルです。
部材名、部材カテゴリ（半導体/コンデンサ/基板/筐体等）、メーカー型番、
仕入先、単価、調達リードタイム、代替部材情報が含まれます。
「部材」「部品」「仕入先」「単価」「代替品」に関する質問はこのテーブルを参照します。
```

### dim_workers（作業者マスタ）
```
製造・品質・出荷部門の作業者情報を管理するマスタテーブルです。
氏名、部署、スキルレベル（初級/中級/上級）、入社年、保有資格が含まれます。
「作業者」「担当者」「スキル」「資格」に関する質問はこのテーブルを参照します。
```

### fact_production_orders（製造指示）
```
製品の製造指示（製造オーダー）の計画と実績を記録するファクトテーブルです。
製品ID、計画数量、実績数量、計画・実績の開始/終了日、ステータス（未着手/進行中/完了）、
優先度、顧客コードが含まれます。
「製造指示」「生産計画」「製造数量」「完了日」「納期」「進捗」に関する質問はこのテーブルを参照します。
```

### fact_process_results（工程作業実績）
```
各製造指示の各工程における作業実績を記録するファクトテーブルです。
作業開始/終了日時、担当作業者、実際の作業時間、不良フラグ、不良内容が含まれます。
「工程実績」「作業時間」「作業者実績」「不良」「手直し」に関する質問はこのテーブルを参照します。
このテーブルは fact_production_orders と dim_processes をつなぐ中心テーブルです。
```

### fact_parts_usage（部材使用実績）
```
各工程実績で使用した部材の実績数量とロット番号を記録するファクトテーブルです。
「部材使用量」「ロット番号」「使用実績」「部材トレーサビリティ」に関する質問はこのテーブルを参照します。
```

### fact_quality_inspections（品質検査結果）
```
各工程での検査結果（機能検査・最終検査）を記録するファクトテーブルです。
検査項目、測定値、上限/下限値、単位、合否判定、検査者が含まれます。
「品質」「検査」「合格」「不合格」「不良率」「測定値」「絶縁」「電流」「電圧」
に関する質問はこのテーブルを参照します。
```

---

## 4. DAX メジャー定義

Power BI セマンティックモデルに追加する計算メジャーです。

```dax
-- 製造完了台数
完了台数 = CALCULATE(
    SUM(fact_production_orders[actual_qty]),
    fact_production_orders[order_status] = "完了"
)

-- 製造計画台数
計画台数 = SUM(fact_production_orders[planned_qty])

-- 達成率 (%)
達成率_pct = DIVIDE([完了台数], [計画台数]) * 100

-- 平均作業時間 (分)
平均作業時間_分 = AVERAGE(fact_process_results[actual_time_min])

-- 標準時間比率 (%)
-- 実作業時間 / 標準時間 × 100
標準時間比率_pct = DIVIDE(
    AVERAGE(fact_process_results[actual_time_min]),
    RELATED(dim_processes[standard_time_min])
) * 100

-- 検査合格数
検査合格数 = CALCULATE(
    COUNTROWS(fact_quality_inspections),
    fact_quality_inspections[pass_fail] = "合格"
)

-- 検査不合格数
検査不合格数 = CALCULATE(
    COUNTROWS(fact_quality_inspections),
    fact_quality_inspections[pass_fail] = "不合格"
)

-- 工程不良率 (%)
工程不良率_pct = DIVIDE(
    CALCULATE(COUNTROWS(fact_process_results), fact_process_results[defect_flag] = TRUE()),
    COUNTROWS(fact_process_results)
) * 100

-- 工程遅延日数（平均）
平均遅延日数 = AVERAGEX(
    FILTER(fact_production_orders, fact_production_orders[actual_end_date] <> BLANK()),
    DATEDIFF(fact_production_orders[planned_end_date], fact_production_orders[actual_end_date], DAY)
)

-- 部材使用コスト（推計）
部材使用コスト_円 = SUMX(
    fact_parts_usage,
    fact_parts_usage[actual_qty] * RELATED(dim_parts[unit_price_jpy])
)
```

---

## 5. 日付テーブル定義

時系列分析のための日付テーブルです。Fabric Data Agent の時間軸クエリに必要です。

```dax
dim_date = 
ADDCOLUMNS(
    CALENDAR(DATE(2025, 1, 1), DATE(2027, 12, 31)),
    "Year",         YEAR([Date]),
    "Month",        MONTH([Date]),
    "MonthName",    FORMAT([Date], "MMMM", "ja-JP"),
    "Quarter",      "Q" & QUARTER([Date]),
    "WeekNumber",   WEEKNUM([Date]),
    "DayOfWeek",    WEEKDAY([Date], 2),
    "DayName",      FORMAT([Date], "dddd", "ja-JP"),
    "YearMonth",    FORMAT([Date], "YYYY-MM"),
    "IsWeekend",    IF(WEEKDAY([Date], 2) >= 6, TRUE(), FALSE())
)
```

---

## 6. Fabric Data Agent 向け自然言語スキーマ設定

Data Agent の設定画面で入力するシステムプロンプト（Instruction）例：

```
あなたは製造業の生産管理・品質管理の専門AIアシスタントです。
以下のデータを持つ製造工程データベースに対して、自然言語で質問に答えてください。

【利用可能なデータ】
- 製品マスタ (dim_products): 5製品（インバータ2種、サーボドライバ2種、PLC1種）
- 製造工程マスタ (dim_processes): 6工程（基板実装〜梱包）
- 部材マスタ (dim_parts): 20種類の部材・代替品情報
- 作業者マスタ (dim_workers): 12名の作業者
- 製造指示 (fact_production_orders): 2026年1月〜3月の製造指示
- 工程作業実績 (fact_process_results): 各工程の実施実績
- 部材使用実績 (fact_parts_usage): 工程ごとの部材使用記録
- 品質検査結果 (fact_quality_inspections): 機能検査・最終検査の測定結果

【回答スタイル】
- 数値は具体的に（例: 10台、不良率2.5%）
- 不明な点は確認する
- 品質問題は原因追跡を案内する
```

---

## 7. セマンティックモデル作成手順サマリー

1. Fabric ポータル → 対象ワークスペース → 「+ 新規」→「セマンティックモデル」
2. データソースとして Fabric Warehouse の `manufacturing_warehouse` を選択
3. 上記テーブルをすべてインポート
4. 「モデルビュー」でリレーション（セクション 2）を設定
5. 「データビュー」でテーブルの日本語説明を各テーブルの「説明」フィールドに入力
6. DAX メジャーをホームテーブル（`fact_production_orders`）に追加
7. `dim_date` テーブルを追加し、各ファクトテーブルの日付カラムとリレーションを設定
8. モデルを保存・発行
