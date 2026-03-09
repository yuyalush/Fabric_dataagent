"""Execute SQL against Fabric Warehouse using ODBC + Azure AD token."""
import pyodbc, struct, sys, os, re

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

def execute_sql_file(conn, filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remove block comments
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    
    # Split by semicolons, filter empty/comment-only
    statements = content.split(';')
    cursor = conn.cursor()
    ok_count = 0
    err_count = 0
    
    for stmt in statements:
        lines = [l for l in stmt.split('\n') if l.strip() and not l.strip().startswith('--')]
        clean = '\n'.join(lines).strip()
        if not clean:
            continue
        try:
            cursor.execute(clean)
            label = clean[:70].replace('\n', ' ')
            print(f'[OK] {label}...')
            ok_count += 1
        except Exception as e:
            print(f'[ERR] {str(e)[:150]}')
            err_count += 1
    
    print(f'\nDone: {ok_count} succeeded, {err_count} failed')
    return cursor

def execute_query(conn, query):
    cursor = conn.cursor()
    cursor.execute(query)
    if cursor.description is None:
        print('Statement executed successfully (no result set)')
        return [], []
    cols = [desc[0] for desc in cursor.description]
    rows = cursor.fetchall()
    return cols, rows

if __name__ == '__main__':
    server = os.environ['FABRIC_SQL_ENDPOINT']
    database = os.environ['FABRIC_DATABASE']
    token = os.environ['FABRIC_TOKEN']
    
    conn = get_connection(server, database, token)
    
    mode = sys.argv[1] if len(sys.argv) > 1 else 'query'
    
    if mode == 'file' and len(sys.argv) > 2:
        execute_sql_file(conn, sys.argv[2])
        # List tables after
        cols, rows = execute_query(conn, 
            "SELECT TABLE_NAME, TABLE_TYPE FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='dbo' ORDER BY TABLE_NAME")
        print('\n=== Tables/Views ===')
        for r in rows:
            print(f'  {r[1]:12s} {r[0]}')
    elif mode == 'query' and len(sys.argv) > 2:
        query = sys.argv[2]
        cols, rows = execute_query(conn, query)
        print('\t'.join(cols))
        for r in rows:
            print('\t'.join(str(v) for v in r))
    
    conn.close()
