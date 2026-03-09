"""Load CSV files into Fabric Warehouse via INSERT statements."""
import pyodbc, struct, csv, os, sys

def get_connection(server, database, token):
    token_bytes = token.encode('utf-16-le')
    token_struct = struct.pack(f'<I{len(token_bytes)}s', len(token_bytes), token_bytes)
    return pyodbc.connect(
        f'DRIVER={{ODBC Driver 18 for SQL Server}};'
        f'SERVER={server};DATABASE={database};'
        f'Encrypt=yes;TrustServerCertificate=no;',
        attrs_before={1256: token_struct},
        autocommit=True
    )

# CSV column to table column mapping (CSV headers -> DB columns)
TABLE_COLUMNS = {
    'dim_products': ['product_id','product_name','product_category','model_number',
                     'voltage_spec_v','current_spec_a','power_rating_kw','weight_kg',
                     'release_year','status','notes'],
    'dim_processes': ['process_id','process_name','process_order','department',
                      'standard_time_min','description','required_skill_level','applicable_products'],
    'dim_parts': ['part_id','part_name','part_category','part_number','supplier_name',
                  'unit_price_jpy','lead_time_days','stock_unit','description','alternative_part_id'],
    'dim_workers': ['worker_id','last_name','first_name','department',
                    'skill_level','hire_year','certifications','notes'],
    'fact_production_orders': ['order_id','product_id','planned_qty','actual_qty',
                               'planned_start_date','actual_start_date','planned_end_date','actual_end_date',
                               'order_status','priority','customer_code','notes'],
    'fact_process_results': ['result_id','order_id','process_id','unit_seq',
                              'start_datetime','end_datetime','worker_id','actual_time_min',
                              'status','defect_flag','defect_description','notes'],
    'fact_parts_usage': ['usage_id','result_id','part_id','planned_qty','actual_qty','lot_number','notes'],
    'fact_quality_inspections': ['inspection_id','result_id','inspection_item','inspection_type',
                                 'measured_value','lower_limit','upper_limit','unit',
                                 'pass_fail','inspector_id','inspection_datetime','notes'],
}

LOAD_ORDER = [
    'dim_products', 'dim_processes', 'dim_parts', 'dim_workers',
    'fact_production_orders', 'fact_process_results',
    'fact_parts_usage', 'fact_quality_inspections'
]

def load_csv(conn, table_name, csv_path):
    columns = TABLE_COLUMNS[table_name]
    cursor = conn.cursor()
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        count = 0
        for row in reader:
            values = []
            for col in columns:
                v = row.get(col, '').strip()
                if v == '':
                    values.append(None)
                elif col == 'defect_flag':
                    values.append(1 if v.lower() in ('true','1','yes') else 0)
                else:
                    values.append(v)
            
            placeholders = ','.join(['?' for _ in columns])
            col_list = ','.join(columns)
            sql = f"INSERT INTO dbo.{table_name} ({col_list}) VALUES ({placeholders})"
            try:
                cursor.execute(sql, values)
                count += 1
            except Exception as e:
                print(f"  [ERR] Row {count+1}: {str(e)[:100]}")
    
    print(f"[OK] {table_name}: {count} rows inserted")
    return count

if __name__ == '__main__':
    server = os.environ['FABRIC_SQL_ENDPOINT']
    database = os.environ['FABRIC_DATABASE']
    token = os.environ['FABRIC_TOKEN']
    csv_dir = sys.argv[1] if len(sys.argv) > 1 else 'data/structured'
    
    conn = get_connection(server, database, token)
    total = 0
    
    for table in LOAD_ORDER:
        csv_path = os.path.join(csv_dir, f'{table}.csv')
        if not os.path.exists(csv_path):
            print(f"[SKIP] {csv_path} not found")
            continue
        total += load_csv(conn, table, csv_path)
    
    print(f"\nTotal: {total} rows inserted across {len(LOAD_ORDER)} tables")
    conn.close()
