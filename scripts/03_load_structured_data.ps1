<#
.SYNOPSIS
    構造化データ（CSV）を Azure Blob Storage を経由して Fabric Warehouse にロードするスクリプト

.DESCRIPTION
    data/structured/ フォルダ内の CSV ファイルを一時的に Azure Blob Storage にアップロードし、
    その後 Fabric REST API を使って Data Pipeline を起動します。
    
    ロード順序（外部キー制約を考慮）:
      1. dim_products  → 2. dim_processes → 3. dim_parts → 4. dim_workers
      5. fact_production_orders → 6. fact_process_results
      7. fact_parts_usage      → 8. fact_quality_inspections

.PREREQUISITES
    - 01_setup_azure_storage.ps1 が実行済み（.env.storage が存在する）
    - Azure CLI で az login 済み
    - Fabric ワークスペースが作成済みで .env.fabric に設定が保存されている

.USAGE
    .\scripts\03_load_structured_data.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── ヘルパー関数 ───────────────────────────────────────────────

function Write-Step   { param([string]$M); Write-Host "`n[STEP] $M" -ForegroundColor Cyan }
function Write-Success{ param([string]$M); Write-Host "[OK]   $M" -ForegroundColor Green }
function Write-Info   { param([string]$M); Write-Host "[INFO] $M" -ForegroundColor Yellow }
function Write-Warn   { param([string]$M); Write-Host "[WARN] $M" -ForegroundColor Magenta }

# ─── 設定読み込み ────────────────────────────────────────────────

Write-Step "1/5 設定ファイルの読み込み"

function Load-EnvFile([string]$path) {
    $vars = @{}
    if (Test-Path $path) {
        Get-Content $path | Where-Object { $_ -match "^[^#].*=.*" } | ForEach-Object {
            $p = $_ -split "=", 2
            $vars[$p[0].Trim()] = $p[1].Trim()
        }
    }
    return $vars
}

$storageEnv = Load-EnvFile (Join-Path $PSScriptRoot ".env.storage")
$fabricEnv  = Load-EnvFile (Join-Path $PSScriptRoot ".env.fabric")

$storageAccount = $storageEnv["AZURE_STORAGE_ACCOUNT"]
$containerName  = $storageEnv["AZURE_CONTAINER_NAME"]

if (-not $storageAccount) {
    Write-Error ".env.storage が見つかりません。01_setup_azure_storage.ps1 を先に実行してください。"
    exit 1
}

Write-Success "Storage 設定読み込み完了: $storageAccount / $containerName"

# Fabric 設定（存在する場合のみ）
$fabricWorkspaceId = $fabricEnv["FABRIC_WORKSPACE_ID"]
$fabricWarehouseId = $fabricEnv["FABRIC_WAREHOUSE_ID"]
if ($fabricWorkspaceId) {
    Write-Success "Fabric 設定読み込み完了: Workspace=$fabricWorkspaceId"
} else {
    Write-Warn ".env.fabric が見つかりません。CSV のアップロードまで実施し、Fabric ロードは手動で行ってください。"
}

# ─── CSV ファイルのアップロード ────────────────────────────────────

Write-Step "2/5 CSV ファイルを Azure Blob Storage にアップロード"

$projectRoot = Join-Path $PSScriptRoot ".."
$csvDir      = Join-Path $projectRoot "data\structured"

if (-not (Test-Path $csvDir)) {
    Write-Error "data/structured フォルダが見つかりません: $csvDir"
    exit 1
}

# ロード順序（外部キー制約を考慮）
$loadOrder = @(
    "dim_products.csv",
    "dim_processes.csv",
    "dim_parts.csv",
    "dim_workers.csv",
    "fact_production_orders.csv",
    "fact_process_results.csv",
    "fact_parts_usage.csv",
    "fact_quality_inspections.csv"
)

$uploadedFiles = @()

foreach ($csvFile in $loadOrder) {
    $fullPath  = Join-Path $csvDir $csvFile
    $blobName  = "csv-staging/$csvFile"

    if (-not (Test-Path $fullPath)) {
        Write-Warn "ファイルが見つかりません（スキップ）: $fullPath"
        continue
    }

    Write-Info "アップロード中: $csvFile → $blobName"

    az storage blob upload `
        --account-name $storageAccount `
        --container-name $containerName `
        --name $blobName `
        --file $fullPath `
        --auth-mode login `
        --overwrite true `
        --output none

    Write-Success "完了: $csvFile"
    $uploadedFiles += $blobName
}

Write-Success "CSV アップロード完了: $($uploadedFiles.Count) ファイル"

# ─── Fabric REST API で COPY INTO を実行 ─────────────────────────

Write-Step "3/5 Fabric Warehouse に COPY INTO でデータを投入"

if (-not $fabricWorkspaceId -or -not $fabricWarehouseId) {
    Write-Warn "Fabric の設定が未設定のため、手動ロード用の T-SQL コマンドを生成します。"

    $storageBaseUrl = "https://$storageAccount.blob.core.windows.net/$containerName/csv-staging"

    $sqlContent = @"
-- =========================================================
-- Fabric Warehouse COPY INTO コマンド
-- 生成日時: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
-- Storage URL: $storageBaseUrl
-- =========================================================
-- ※ このファイルを Fabric Warehouse のクエリエディタで実行してください

"@

    $tableMap = @{
        "dim_products.csv"            = "dim_products"
        "dim_processes.csv"           = "dim_processes"
        "dim_parts.csv"               = "dim_parts"
        "dim_workers.csv"             = "dim_workers"
        "fact_production_orders.csv"  = "fact_production_orders"
        "fact_process_results.csv"    = "fact_process_results"
        "fact_parts_usage.csv"        = "fact_parts_usage"
        "fact_quality_inspections.csv"= "fact_quality_inspections"
    }

    foreach ($csvFile in $loadOrder) {
        $tableName = $tableMap[$csvFile]
        $blobUrl   = "$storageBaseUrl/$csvFile"

        $sqlContent += @"
-- ---------------------------------------------------------
-- $tableName
-- ---------------------------------------------------------
COPY INTO dbo.$tableName
FROM '$blobUrl'
WITH (
    FILE_TYPE = 'CSV',
    FIRSTROW   = 2,          -- ヘッダー行をスキップ
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CREDENTIAL = (IDENTITY = 'Managed Identity')
);
GO

"@
    }

    $sqlOutput = Join-Path $PSScriptRoot "copy_into_commands.sql"
    $sqlContent | Out-File -FilePath $sqlOutput -Encoding UTF8
    Write-Success "手動実行用 SQL ファイルを生成しました: $sqlOutput"

} else {
    # Fabric REST API でパイプラインを起動（Fabric Workspace が設定済みの場合）
    Write-Info "Fabric REST API 経由のパイプライン起動は現時点では手動手順が必要です。"
    Write-Info "生成された SQL ファイルを Fabric Warehouse のクエリエディタで実行してください。"
}

# ─── ロード後の行数確認用 SQL 生成 ─────────────────────────────

Write-Step "4/5 データ確認クエリの生成"

$verifySQL = @"
-- =========================================================
-- データロード確認クエリ
-- =========================================================

SELECT 'dim_products'             AS table_name, COUNT(*) AS row_count FROM dbo.dim_products
UNION ALL
SELECT 'dim_processes',                           COUNT(*) FROM dbo.dim_processes
UNION ALL
SELECT 'dim_parts',                               COUNT(*) FROM dbo.dim_parts
UNION ALL
SELECT 'dim_workers',                             COUNT(*) FROM dbo.dim_workers
UNION ALL
SELECT 'fact_production_orders',                  COUNT(*) FROM dbo.fact_production_orders
UNION ALL
SELECT 'fact_process_results',                    COUNT(*) FROM dbo.fact_process_results
UNION ALL
SELECT 'fact_parts_usage',                        COUNT(*) FROM dbo.fact_parts_usage
UNION ALL
SELECT 'fact_quality_inspections',                COUNT(*) FROM dbo.fact_quality_inspections
ORDER BY table_name;

-- 製造不良率サマリー
SELECT product_id, defect_rate
FROM   dbo.vw_defect_rate_by_product_process
ORDER  BY defect_rate DESC;
"@

$verifyOutput = Join-Path $PSScriptRoot "verify_data.sql"
$verifySQL | Out-File -FilePath $verifyOutput -Encoding UTF8
Write-Success "データ確認クエリを生成しました: $verifyOutput"

# ─── 完了メッセージ ────────────────────────────────────────────

Write-Step "5/5 完了"

Write-Host "`n====================================" -ForegroundColor Green
Write-Host " 構造化データの準備完了！" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""
Write-Host "次の手順:"
Write-Host "  1. Fabric Studio で Warehouse を開く"
Write-Host "  2. scripts\copy_into_commands.sql の内容をクエリエディタに貼り付けて実行"
Write-Host "  3. scripts\verify_data.sql でロード結果を確認"
Write-Host "  4. Sprint 2 の README.md を参照してセマンティックモデルを構成する"
Write-Host ""
Write-Host "詳細手順: sprint2/README.md を参照"
