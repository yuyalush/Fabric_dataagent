"""Generate model.bim for Fabric Semantic Model with full column definitions."""
import json, base64, sys

SQL_ENDPOINT = "za4oqmkdbmie5cy3rtz4avmj7q-3vda2qi3qfde7jvkwtquiwhmvi.datawarehouse.fabric.microsoft.com"
DATABASE = "manufacturing_warehouse"

def col(name, dtype="string", hidden=False):
    c = {"name": name, "dataType": dtype, "sourceColumn": name}
    if hidden:
        c["isHidden"] = True
    return c

def partition(tbl):
    return {
        "name": tbl,
        "mode": "directQuery",
        "source": {
            "type": "m",
            "expression": f'let\n    Source = DatabaseQuery,\n    dbo_{tbl} = Source{{[Schema="dbo",Item="{tbl}"]}}[Data]\nin\n    dbo_{tbl}'
        }
    }

TABLES = [
    {
        "name": "dim_products",
        "description": "製造する製品の基本情報を管理するマスタテーブルです。製品ID、製品名、製品カテゴリ（インバータ/サーボドライバ/PLC等）、型番、電圧・電流・出力の仕様値、質量などが含まれます。",
        "columns": [
            col("product_id"), col("product_name"), col("product_category"),
            col("model_number"), col("voltage_spec_v"), col("current_spec_a", "double"),
            col("power_rating_kw", "double"), col("weight_kg", "double"),
            col("release_year", "int64"), col("status"), col("notes")
        ]
    },
    {
        "name": "dim_processes",
        "description": "製造の各工程（基板実装/筐体組立/配線作業/機能検査/最終検査/梱包）を定義するマスタテーブルです。工程の順序、担当部署、標準作業時間、必要スキルレベルが含まれます。",
        "columns": [
            col("process_id"), col("process_name"), col("process_order", "int64"),
            col("department"), col("standard_time_min", "int64"), col("description"),
            col("required_skill_level"), col("applicable_products")
        ]
    },
    {
        "name": "dim_parts",
        "description": "製造に使用する部材・部品の情報を管理するマスタテーブルです。部材名、部材カテゴリ、メーカー型番、仕入先、単価、調達リードタイム、代替部材情報が含まれます。",
        "columns": [
            col("part_id"), col("part_name"), col("part_category"), col("part_number"),
            col("supplier_name"), col("unit_price_jpy", "double"),
            col("lead_time_days", "int64"), col("stock_unit"), col("description"),
            col("alternative_part_id")
        ]
    },
    {
        "name": "dim_workers",
        "description": "製造・品質・出荷部門の作業者情報を管理するマスタテーブルです。氏名、部署、スキルレベル（初級/中級/上級）、入社年、保有資格が含まれます。",
        "columns": [
            col("worker_id"), col("last_name"), col("first_name"), col("department"),
            col("skill_level"), col("hire_year", "int64"), col("certifications"), col("notes")
        ]
    },
    {
        "name": "fact_production_orders",
        "description": "製品の製造指示（製造オーダー）の計画と実績を記録するファクトテーブルです。製品ID、計画数量、実績数量、計画・実績の開始/終了日、ステータス、優先度、顧客コードが含まれます。",
        "columns": [
            col("order_id"), col("product_id"), col("planned_qty", "int64"),
            col("actual_qty", "int64"), col("planned_start_date", "dateTime"),
            col("actual_start_date", "dateTime"), col("planned_end_date", "dateTime"),
            col("actual_end_date", "dateTime"), col("order_status"), col("priority"),
            col("customer_code"), col("notes")
        ]
    },
    {
        "name": "fact_process_results",
        "description": "各製造指示の各工程における作業実績を記録するファクトテーブルです。作業開始/終了日時、担当作業者、実際の作業時間、不良フラグ、不良内容が含まれます。",
        "columns": [
            col("result_id"), col("order_id"), col("process_id"), col("unit_seq", "int64"),
            col("start_datetime", "dateTime"), col("end_datetime", "dateTime"),
            col("worker_id"), col("actual_time_min", "int64"), col("status"),
            col("defect_flag", "boolean"), col("defect_description"), col("notes")
        ]
    },
    {
        "name": "fact_parts_usage",
        "description": "各工程実績で使用した部材の実績数量とロット番号を記録するファクトテーブルです。",
        "columns": [
            col("usage_id"), col("result_id"), col("part_id"),
            col("planned_qty", "double"), col("actual_qty", "double"),
            col("lot_number"), col("notes")
        ]
    },
    {
        "name": "fact_quality_inspections",
        "description": "各工程での検査結果（機能検査・最終検査）を記録するファクトテーブルです。検査項目、測定値、上限/下限値、単位、合否判定、検査者が含まれます。",
        "columns": [
            col("inspection_id"), col("result_id"), col("inspection_item"),
            col("inspection_type"), col("measured_value", "double"),
            col("lower_limit", "double"), col("upper_limit", "double"),
            col("unit"), col("pass_fail"), col("inspector_id"),
            col("inspection_datetime", "dateTime"), col("notes")
        ]
    }
]

RELATIONSHIPS = [
    {"name": "r1", "fromTable": "fact_production_orders", "fromColumn": "product_id", "toTable": "dim_products", "toColumn": "product_id"},
    {"name": "r2", "fromTable": "fact_process_results", "fromColumn": "order_id", "toTable": "fact_production_orders", "toColumn": "order_id"},
    {"name": "r3", "fromTable": "fact_process_results", "fromColumn": "process_id", "toTable": "dim_processes", "toColumn": "process_id"},
    {"name": "r4", "fromTable": "fact_process_results", "fromColumn": "worker_id", "toTable": "dim_workers", "toColumn": "worker_id"},
    {"name": "r5", "fromTable": "fact_parts_usage", "fromColumn": "result_id", "toTable": "fact_process_results", "toColumn": "result_id"},
    {"name": "r6", "fromTable": "fact_parts_usage", "fromColumn": "part_id", "toTable": "dim_parts", "toColumn": "part_id"},
    {"name": "r7", "fromTable": "fact_quality_inspections", "fromColumn": "result_id", "toTable": "fact_process_results", "toColumn": "result_id"},
    {"name": "r8", "fromTable": "fact_quality_inspections", "fromColumn": "inspector_id", "toTable": "dim_workers", "toColumn": "worker_id", "isActive": False},
]

def build_model():
    model = {
        "compatibilityLevel": 1604,
        "model": {
            "culture": "ja-JP",
            "defaultPowerBIDataSourceVersion": "powerBI_V3",
            "expressions": [
                {
                    "name": "DatabaseQuery",
                    "kind": "m",
                    "expression": f'let\n    database = Sql.Database("{SQL_ENDPOINT}", "{DATABASE}")\nin\n    database'
                }
            ],
            "tables": [],
            "relationships": RELATIONSHIPS
        }
    }
    
    for tbl_def in TABLES:
        tbl = {
            "name": tbl_def["name"],
            "description": tbl_def["description"],
            "columns": tbl_def["columns"],
            "partitions": [partition(tbl_def["name"])]
        }
        model["model"]["tables"].append(tbl)
    
    return model

if __name__ == "__main__":
    model = build_model()
    json_str = json.dumps(model, ensure_ascii=False, indent=2)
    
    if "--base64" in sys.argv:
        print(base64.b64encode(json_str.encode("utf-8")).decode("ascii"))
    else:
        print(json_str)
