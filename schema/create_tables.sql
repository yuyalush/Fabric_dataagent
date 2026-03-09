-- ================================================================
-- Fabric Warehouse: 製造業 PoC テーブル定義
-- 対象: Microsoft Fabric Warehouse (T-SQL 互換)
-- 作成日: 2026-03-09
-- ================================================================

-- ----------------------------------------------------------------
-- ディメンションテーブル (マスタ)
-- ----------------------------------------------------------------

-- 製品マスタ
CREATE TABLE dim_products (
    product_id          VARCHAR(20)     NOT NULL,
    product_name        NVARCHAR(100)   NOT NULL,
    product_category    NVARCHAR(50)    NOT NULL,
    model_number        VARCHAR(30)     NOT NULL,
    voltage_spec_v      VARCHAR(20)     NULL,       -- 電圧仕様
    current_spec_a      DECIMAL(10, 2)  NULL,       -- 電流仕様 (A)
    power_rating_kw     DECIMAL(10, 2)  NULL,       -- 定格出力 (kW)
    weight_kg           DECIMAL(10, 2)  NULL,       -- 質量 (kg)
    release_year        SMALLINT        NULL,       -- 発売年
    status              VARCHAR(20)     NOT NULL DEFAULT 'active', -- active / discontinued
    notes               NVARCHAR(500)   NULL,
    created_at          DATETIME2       NOT NULL DEFAULT GETDATE(),
    updated_at          DATETIME2       NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_dim_products PRIMARY KEY (product_id)
);

-- 製造工程マスタ
CREATE TABLE dim_processes (
    process_id              VARCHAR(20)     NOT NULL,
    process_name            NVARCHAR(100)   NOT NULL,
    process_order           TINYINT         NOT NULL,   -- 工程順序
    department              NVARCHAR(50)    NOT NULL,   -- 担当部署
    standard_time_min       SMALLINT        NULL,       -- 標準作業時間 (分)
    description             NVARCHAR(500)   NULL,
    required_skill_level    NVARCHAR(20)    NULL,       -- 初級/中級/上級
    applicable_products     NVARCHAR(200)   NULL,       -- 適用製品ID (セミコロン区切り)
    created_at              DATETIME2       NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_dim_processes PRIMARY KEY (process_id)
);

-- 部材マスタ
CREATE TABLE dim_parts (
    part_id             VARCHAR(20)     NOT NULL,
    part_name           NVARCHAR(100)   NOT NULL,
    part_category       NVARCHAR(50)    NOT NULL,   -- 半導体/コンデンサ/基板/筐体 etc.
    part_number         VARCHAR(50)     NULL,       -- メーカー型番
    supplier_name       NVARCHAR(100)   NULL,
    unit_price_jpy      DECIMAL(12, 0)  NULL,       -- 単価 (円)
    lead_time_days      SMALLINT        NULL,       -- 調達リードタイム (日)
    stock_unit          VARCHAR(10)     NULL,       -- 在庫単位
    description         NVARCHAR(500)   NULL,
    alternative_part_id VARCHAR(20)     NULL,       -- 代替部材ID
    created_at          DATETIME2       NOT NULL DEFAULT GETDATE(),
    updated_at          DATETIME2       NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_dim_parts PRIMARY KEY (part_id)
);

-- 作業者マスタ
CREATE TABLE dim_workers (
    worker_id           VARCHAR(20)     NOT NULL,
    last_name           NVARCHAR(20)    NOT NULL,
    first_name          NVARCHAR(20)    NOT NULL,
    department          NVARCHAR(50)    NOT NULL,
    skill_level         NVARCHAR(20)    NULL,       -- 初級/中級/上級
    hire_year           SMALLINT        NULL,
    certifications      NVARCHAR(200)   NULL,       -- 保有資格 (セミコロン区切り)
    notes               NVARCHAR(200)   NULL,
    is_active           BIT             NOT NULL DEFAULT 1,
    created_at          DATETIME2       NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_dim_workers PRIMARY KEY (worker_id)
);

-- ----------------------------------------------------------------
-- ファクトテーブル (実績)
-- ----------------------------------------------------------------

-- 製造指示
CREATE TABLE fact_production_orders (
    order_id            VARCHAR(30)     NOT NULL,
    product_id          VARCHAR(20)     NOT NULL,
    planned_qty         SMALLINT        NOT NULL,
    actual_qty          SMALLINT        NULL DEFAULT 0,  -- 実際に完成した台数
    planned_start_date  DATE            NULL,
    actual_start_date   DATE            NULL,
    planned_end_date    DATE            NULL,
    actual_end_date     DATE            NULL,
    order_status        NVARCHAR(20)    NOT NULL DEFAULT '未着手', -- 未着手/進行中/完了/中止
    priority            NVARCHAR(10)    NULL,   -- 通常/高/緊急
    customer_code       VARCHAR(20)     NULL,
    notes               NVARCHAR(500)   NULL,
    created_at          DATETIME2       NOT NULL DEFAULT GETDATE(),
    updated_at          DATETIME2       NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_fact_production_orders PRIMARY KEY (order_id),
    CONSTRAINT FK_orders_products FOREIGN KEY (product_id) REFERENCES dim_products(product_id)
);

-- 工程作業実績
CREATE TABLE fact_process_results (
    result_id           VARCHAR(30)     NOT NULL,
    order_id            VARCHAR(30)     NOT NULL,
    process_id          VARCHAR(20)     NOT NULL,
    unit_seq            SMALLINT        NOT NULL,   -- 同一指示内の台番
    start_datetime      DATETIME2       NULL,
    end_datetime        DATETIME2       NULL,
    worker_id           VARCHAR(20)     NULL,
    actual_time_min     SMALLINT        NULL,       -- 実作業時間 (分)
    status              NVARCHAR(20)    NOT NULL DEFAULT '作業中',  -- 作業中/完了/保留
    defect_flag         BIT             NOT NULL DEFAULT 0,
    defect_description  NVARCHAR(500)   NULL,
    notes               NVARCHAR(500)   NULL,
    created_at          DATETIME2       NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_fact_process_results PRIMARY KEY (result_id),
    CONSTRAINT FK_results_orders   FOREIGN KEY (order_id)   REFERENCES fact_production_orders(order_id),
    CONSTRAINT FK_results_process  FOREIGN KEY (process_id) REFERENCES dim_processes(process_id),
    CONSTRAINT FK_results_worker   FOREIGN KEY (worker_id)  REFERENCES dim_workers(worker_id)
);

-- 部材使用実績
CREATE TABLE fact_parts_usage (
    usage_id            VARCHAR(30)     NOT NULL,
    result_id           VARCHAR(30)     NOT NULL,
    part_id             VARCHAR(20)     NOT NULL,
    planned_qty         DECIMAL(10, 2)  NULL,
    actual_qty          DECIMAL(10, 2)  NOT NULL,
    lot_number          VARCHAR(50)     NULL,       -- 使用ロット番号
    notes               NVARCHAR(200)   NULL,
    created_at          DATETIME2       NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_fact_parts_usage PRIMARY KEY (usage_id),
    CONSTRAINT FK_usage_result FOREIGN KEY (result_id) REFERENCES fact_process_results(result_id),
    CONSTRAINT FK_usage_part   FOREIGN KEY (part_id)   REFERENCES dim_parts(part_id)
);

-- 品質検査結果
CREATE TABLE fact_quality_inspections (
    inspection_id       VARCHAR(30)     NOT NULL,
    result_id           VARCHAR(30)     NOT NULL,
    inspection_item     NVARCHAR(100)   NOT NULL,   -- 検査項目名
    inspection_type     NVARCHAR(50)    NULL,       -- 機能検査/最終検査
    measured_value      DECIMAL(18, 4)  NULL,       -- 測定値
    lower_limit         DECIMAL(18, 4)  NULL,       -- 下限値
    upper_limit         DECIMAL(18, 4)  NULL,       -- 上限値
    unit                VARCHAR(20)     NULL,       -- 単位
    pass_fail           NVARCHAR(10)    NOT NULL,   -- 合格/不合格
    inspector_id        VARCHAR(20)     NULL,
    inspection_datetime DATETIME2       NULL,
    notes               NVARCHAR(500)   NULL,
    created_at          DATETIME2       NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_fact_quality_inspections PRIMARY KEY (inspection_id),
    CONSTRAINT FK_inspection_result   FOREIGN KEY (result_id)    REFERENCES fact_process_results(result_id),
    CONSTRAINT FK_inspection_inspector FOREIGN KEY (inspector_id) REFERENCES dim_workers(worker_id)
);

-- ================================================================
-- ビュー定義 (セマンティックモデル補助)
-- ================================================================

-- 製造指示サマリービュー（製品名を結合）
CREATE VIEW vw_production_order_summary AS
SELECT
    po.order_id,
    p.product_name,
    p.product_category,
    p.model_number,
    po.planned_qty,
    po.actual_qty,
    po.planned_start_date,
    po.actual_start_date,
    po.planned_end_date,
    po.actual_end_date,
    po.order_status,
    po.priority,
    po.customer_code,
    DATEDIFF(day, po.planned_end_date, po.actual_end_date) AS delay_days,
    po.notes
FROM fact_production_orders po
INNER JOIN dim_products p ON po.product_id = p.product_id;

-- 品質サマリービュー（工程・製品紐付き）
CREATE VIEW vw_quality_summary AS
SELECT
    qi.inspection_id,
    po.order_id,
    p.product_name,
    p.model_number,
    pr.process_id,
    proc.process_name,
    qi.inspection_item,
    qi.inspection_type,
    qi.measured_value,
    qi.lower_limit,
    qi.upper_limit,
    qi.unit,
    qi.pass_fail,
    qi.inspection_datetime,
    qi.notes
FROM fact_quality_inspections qi
INNER JOIN fact_process_results pr ON qi.result_id = pr.result_id
INNER JOIN fact_production_orders po ON pr.order_id = po.order_id
INNER JOIN dim_products p ON po.product_id = p.product_id
INNER JOIN dim_processes proc ON pr.process_id = proc.process_id;

-- 不良率集計ビュー（製品・工程別）
CREATE VIEW vw_defect_rate_by_product_process AS
SELECT
    p.product_id,
    p.product_name,
    pr_def.process_id,
    proc.process_name,
    COUNT(pr_def.result_id)                             AS total_results,
    SUM(CAST(pr_def.defect_flag AS INT))                AS defect_count,
    CAST(SUM(CAST(pr_def.defect_flag AS INT)) AS FLOAT)
        / NULLIF(COUNT(pr_def.result_id), 0) * 100      AS defect_rate_pct
FROM fact_process_results pr_def
INNER JOIN fact_production_orders po ON pr_def.order_id = po.order_id
INNER JOIN dim_products p ON po.product_id = p.product_id
INNER JOIN dim_processes proc ON pr_def.process_id = proc.process_id
GROUP BY p.product_id, p.product_name, pr_def.process_id, proc.process_name;
