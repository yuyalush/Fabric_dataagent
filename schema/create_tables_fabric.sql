-- ================================================================
-- Fabric Warehouse: テーブル定義 (Fabric 互換版)
-- VARCHAR(n), DATETIME2(6), DEFAULT/FK 制約なし
-- ================================================================

-- dim_products
CREATE TABLE dim_products (
    product_id          VARCHAR(20)     NOT NULL,
    product_name        VARCHAR(200)    NOT NULL,
    product_category    VARCHAR(100)    NOT NULL,
    model_number        VARCHAR(30)     NOT NULL,
    voltage_spec_v      VARCHAR(20)     NULL,
    current_spec_a      DECIMAL(10, 2)  NULL,
    power_rating_kw     DECIMAL(10, 2)  NULL,
    weight_kg           DECIMAL(10, 2)  NULL,
    release_year        SMALLINT        NULL,
    status              VARCHAR(20)     NOT NULL,
    notes               VARCHAR(1000)   NULL
);

-- dim_processes
CREATE TABLE dim_processes (
    process_id              VARCHAR(20)     NOT NULL,
    process_name            VARCHAR(200)    NOT NULL,
    process_order           SMALLINT        NOT NULL,
    department              VARCHAR(100)    NOT NULL,
    standard_time_min       SMALLINT        NULL,
    description             VARCHAR(1000)   NULL,
    required_skill_level    VARCHAR(40)     NULL,
    applicable_products     VARCHAR(400)    NULL
);

-- dim_parts
CREATE TABLE dim_parts (
    part_id             VARCHAR(20)     NOT NULL,
    part_name           VARCHAR(200)    NOT NULL,
    part_category       VARCHAR(100)    NOT NULL,
    part_number         VARCHAR(50)     NULL,
    supplier_name       VARCHAR(200)    NULL,
    unit_price_jpy      DECIMAL(12, 0)  NULL,
    lead_time_days      SMALLINT        NULL,
    stock_unit          VARCHAR(10)     NULL,
    description         VARCHAR(1000)   NULL,
    alternative_part_id VARCHAR(20)     NULL
);

-- dim_workers
CREATE TABLE dim_workers (
    worker_id           VARCHAR(20)     NOT NULL,
    last_name           VARCHAR(40)     NOT NULL,
    first_name          VARCHAR(40)     NOT NULL,
    department          VARCHAR(100)    NOT NULL,
    skill_level         VARCHAR(40)     NULL,
    hire_year           SMALLINT        NULL,
    certifications      VARCHAR(400)    NULL,
    notes               VARCHAR(400)    NULL
);

-- fact_production_orders
CREATE TABLE fact_production_orders (
    order_id            VARCHAR(30)     NOT NULL,
    product_id          VARCHAR(20)     NOT NULL,
    planned_qty         SMALLINT        NOT NULL,
    actual_qty          SMALLINT        NULL,
    planned_start_date  DATE            NULL,
    actual_start_date   DATE            NULL,
    planned_end_date    DATE            NULL,
    actual_end_date     DATE            NULL,
    order_status        VARCHAR(40)     NOT NULL,
    priority            VARCHAR(20)     NULL,
    customer_code       VARCHAR(20)     NULL,
    notes               VARCHAR(1000)   NULL
);

-- fact_process_results
CREATE TABLE fact_process_results (
    result_id           VARCHAR(30)     NOT NULL,
    order_id            VARCHAR(30)     NOT NULL,
    process_id          VARCHAR(20)     NOT NULL,
    unit_seq            SMALLINT        NOT NULL,
    start_datetime      DATETIME2(6)    NULL,
    end_datetime        DATETIME2(6)    NULL,
    worker_id           VARCHAR(20)     NULL,
    actual_time_min     SMALLINT        NULL,
    status              VARCHAR(40)     NOT NULL,
    defect_flag         BIT             NOT NULL,
    defect_description  VARCHAR(1000)   NULL,
    notes               VARCHAR(1000)   NULL
);

-- fact_parts_usage
CREATE TABLE fact_parts_usage (
    usage_id            VARCHAR(30)     NOT NULL,
    result_id           VARCHAR(30)     NOT NULL,
    part_id             VARCHAR(20)     NOT NULL,
    planned_qty         DECIMAL(10, 2)  NULL,
    actual_qty          DECIMAL(10, 2)  NOT NULL,
    lot_number          VARCHAR(50)     NULL,
    notes               VARCHAR(400)    NULL
);

-- fact_quality_inspections
CREATE TABLE fact_quality_inspections (
    inspection_id       VARCHAR(30)     NOT NULL,
    result_id           VARCHAR(30)     NOT NULL,
    inspection_item     VARCHAR(200)    NOT NULL,
    inspection_type     VARCHAR(100)    NULL,
    measured_value      DECIMAL(18, 4)  NULL,
    lower_limit         DECIMAL(18, 4)  NULL,
    upper_limit         DECIMAL(18, 4)  NULL,
    unit                VARCHAR(20)     NULL,
    pass_fail           VARCHAR(20)     NOT NULL,
    inspector_id        VARCHAR(20)     NULL,
    inspection_datetime DATETIME2(6)    NULL,
    notes               VARCHAR(1000)   NULL
);
