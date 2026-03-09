<#
.SYNOPSIS
    非構造化データ（仕様書・手順書等）を Azure Blob Storage にアップロードするスクリプト

.DESCRIPTION
    data/unstructured/ フォルダ内のすべてのファイルを、対応する Azure Blob Storage
    のフォルダにアップロードします。
    
.PREREQUISITES
    - 01_setup_azure_storage.ps1 が実行済みであること（.env.storage が存在する）
    - Azure CLI で az login 済みであること

.USAGE
    .\scripts\02_upload_unstructured_data.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── ヘルパー関数 ───────────────────────────────────────────────

function Write-Step   { param([string]$M); Write-Host "`n[STEP] $M" -ForegroundColor Cyan }
function Write-Success{ param([string]$M); Write-Host "[OK]   $M" -ForegroundColor Green }
function Write-Info   { param([string]$M); Write-Host "[INFO] $M" -ForegroundColor Yellow }

# ─── 設定読み込み ────────────────────────────────────────────────

Write-Step "1/4 設定ファイルの読み込み"

$envFile = Join-Path $PSScriptRoot ".env.storage"
if (-not (Test-Path $envFile)) {
    Write-Error ".env.storage が見つかりません。先に 01_setup_azure_storage.ps1 を実行してください。"
    exit 1
}

# .env.storage から設定を読み込む
$envVars = @{}
Get-Content $envFile | Where-Object { $_ -match "^[^#].*=.*" } | ForEach-Object {
    $parts = $_ -split "=", 2
    $envVars[$parts[0].Trim()] = $parts[1].Trim()
}

$storageAccount = $envVars["AZURE_STORAGE_ACCOUNT"]
$containerName  = $envVars["AZURE_CONTAINER_NAME"]

if (-not $storageAccount -or -not $containerName) {
    Write-Error ".env.storage から必要な設定を読み込めませんでした。"
    exit 1
}

Write-Success "設定読み込み完了: Storage=$storageAccount, Container=$containerName"

# ─── アップロード対象ディレクトリの確認 ────────────────────────────

Write-Step "2/4 アップロード対象ファイルの確認"

$projectRoot = Join-Path $PSScriptRoot ".."
$dataDir     = Join-Path $projectRoot "data\unstructured"

if (-not (Test-Path $dataDir)) {
    Write-Error "data/unstructured フォルダが見つかりません: $dataDir"
    exit 1
}

$files = Get-ChildItem -Path $dataDir -Recurse -File | Where-Object { $_.Name -ne ".keep" }

Write-Info "アップロード対象ファイル数: $($files.Count)"
$files | ForEach-Object { Write-Info "  - $($_.FullName.Replace($dataDir, '').TrimStart('\/'))" }

# ─── Azure Blob Storage へのアップロード ────────────────────────

Write-Step "3/4 Azure Blob Storage へのアップロード"

$uploadCount = 0
$errorCount  = 0

foreach ($file in $files) {
    # ファイルの相対パスを Blob 名に変換（\ → /）
    $relativePath = $file.FullName.Substring($dataDir.Length).TrimStart('\', '/').Replace('\', '/')
    $blobName = $relativePath

    Write-Info "アップロード中: $blobName"

    try {
        az storage blob upload `
            --account-name $storageAccount `
            --container-name $containerName `
            --name $blobName `
            --file $file.FullName `
            --auth-mode login `
            --overwrite true `
            --output none

        Write-Success "完了: $blobName"
        $uploadCount++
    } catch {
        Write-Warning "失敗: $blobName - $($_.Exception.Message)"
        $errorCount++
    }
}

# ─── アップロード結果の確認 ──────────────────────────────────────

Write-Step "4/4 アップロード結果確認"

$blobs = az storage blob list `
    --account-name $storageAccount `
    --container-name $containerName `
    --auth-mode login `
    --output json | ConvertFrom-Json

Write-Info "アップロード済みファイル一覧:"
$blobs | Where-Object { $_.name -notlike "*/.keep" } | ForEach-Object {
    $sizeMB = [math]::Round($_.properties.contentLength / 1024, 1)
    Write-Info "  $($_.name) (${sizeMB}KB)"
}

Write-Host "`n====================================" -ForegroundColor Green
Write-Host " 非構造化データのアップロード完了！" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host "  成功: $uploadCount ファイル"
Write-Host "  失敗: $errorCount ファイル"
Write-Host ""
Write-Host "次のステップ: Fabric Lakehouse から Azure Storage へのショートカットを作成してください。"
Write-Host "詳細は sprint1/README.md の Step 6 を参照してください。"
