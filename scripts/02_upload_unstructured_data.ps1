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

Write-Step "1/5 設定ファイルの読み込み"

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

# ─── 操作ユーザーへの RBAC ロール確認・自動付与 ────────────────────

Write-Step "2/5 操作ユーザーへの RBAC ロール確認"

# .env.storage から AZURE_STORAGE_SCOPE を取得（なければ az で取得）
$storageScope = $envVars["AZURE_STORAGE_SCOPE"]
if (-not $storageScope) {
    $resourceGroup = $envVars["AZURE_RESOURCE_GROUP"]
    $storageScope  = (az storage account show `
        --name $storageAccount `
        --resource-group $resourceGroup `
        --query "id" --output tsv 2>&1).Trim()
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Storage Account のリソース ID を取得できませんでした。"
        exit 1
    }
}

# ログインユーザーの Object ID を取得
$currentUserId = (az ad signed-in-user show --query "id" --output tsv 2>&1).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($currentUserId)) {
    Write-Error "現在のログインユーザーを特定できませんでした。az login を実行してください。"
    exit 1
}

# 必要ロール（Contributor 以上）を確認
$assignments = az role assignment list `
    --assignee $currentUserId `
    --scope $storageScope `
    --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

$hasRole = $assignments | Where-Object {
    $_.roleDefinitionName -in @("Storage Blob Data Owner", "Storage Blob Data Contributor")
}

if ($hasRole) {
    Write-Success "RBAC 確認済み: [$($hasRole[0].roleDefinitionName)] ロールが付与されています。"
} else {
    Write-Info "Storage Blob Data Contributor ロールが未付与です。自動付与を試みます..."

    az role assignment create `
        --role "Storage Blob Data Contributor" `
        --assignee-object-id $currentUserId `
        --assignee-principal-type User `
        --scope $storageScope `
        --output none 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Error @"
Storage Blob Data Contributor の付与に失敗しました。
ロールの付与には Owner または User Access Administrator 権限が必要です。

手動で付与する場合は以下を実行してください:
  az role assignment create --role "Storage Blob Data Contributor" --assignee "$currentUserId" --scope "$storageScope"

付与後に再度このスクリプトを実行してください（ロール反映まで数分かかる場合があります）。
"@
        exit 1
    }

    Write-Success "Storage Blob Data Contributor を付与しました。"
}

# ロールの実効確認（付与直後・反映遅延を考慮して最大 5 分ポーリング）
Write-Info "Blob Storage への読み書き権限を確認中..."
$maxWaitSec  = 300
$intervalSec = 15
$elapsed     = 0
$permOk      = $false

while ($elapsed -le $maxWaitSec) {
    $testOut = az storage blob list `
        --account-name $storageAccount `
        --container-name $containerName `
        --auth-mode login `
        --output none 2>&1
    if ($LASTEXITCODE -eq 0) {
        $permOk = $true
        break
    }
    Write-Info "  まだ反映中... ($elapsed / $maxWaitSec 秒経過、${intervalSec}秒後に再確認)"
    Start-Sleep -Seconds $intervalSec
    $elapsed += $intervalSec
}

if (-not $permOk) {
    Write-Error @"
ロールの反映がタイムアウトしました（${maxWaitSec}秒）。
しばらく時間をおいてから再度スクリプトを実行してください。
"@
    exit 1
}
Write-Success "権限確認OK（${elapsed}秒で反映）。アップロードを開始します。"

# ─── アップロード対象ディレクトリの確認 ────────────────────────────

Write-Step "3/5 アップロード対象ファイルの確認"

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

Write-Step "4/5 Azure Blob Storage へのアップロード"

$uploadCount = 0
$errorCount  = 0

foreach ($file in $files) {
    # ファイルの相対パスを Blob 名に変換（\ → /）
    $relativePath = $file.FullName.Substring($dataDir.Length).TrimStart('\', '/').Replace('\', '/')
    $blobName = $relativePath

    Write-Info "アップロード中: $blobName"

    $maxRetries    = 3
    $retryDelaySec = 20
    $uploaded      = $false
    $azOutput      = ""

    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        $azOutput = az storage blob upload `
            --account-name $storageAccount `
            --container-name $containerName `
            --name $blobName `
            --file $file.FullName `
            --auth-mode login `
            --overwrite true `
            --output none 2>&1

        if ($LASTEXITCODE -eq 0) {
            $uploaded = $true
            break
        }

        # 権限エラーかつリトライ余裕がある場合は待機して再試行
        $isPermError = "$azOutput" -match "do not have the required permissions"
        if ($isPermError -and $attempt -lt $maxRetries) {
            Write-Info "  権限エラー、リトライ ($attempt/$maxRetries)... ${retryDelaySec}秒待機"
            Start-Sleep -Seconds $retryDelaySec
        } else {
            break
        }
    }

    if ($uploaded) {
        Write-Success "完了: $blobName"
        $uploadCount++
    } else {
        Write-Warning "失敗: $blobName - $azOutput"
        $errorCount++
    }
}

# ─── アップロード結果の確認 ──────────────────────────────────────

Write-Step "5/5 アップロード結果確認"

$blobListJson = az storage blob list `
    --account-name $storageAccount `
    --container-name $containerName `
    --auth-mode login `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {
    $blobs = $blobListJson | ConvertFrom-Json
    Write-Info "アップロード済みファイル一覧:"
    $blobs | Where-Object { $_.name -notlike "*/.keep" } | ForEach-Object {
        $sizeMB = [math]::Round($_.properties.contentLength / 1024, 1)
        Write-Info "  $($_.name) (${sizeMB}KB)"
    }
} else {
    Write-Info "Blob 一覧の取得をスキップします（Step 2 で付与したロールの反映中の可能性があります）。"
}

if ($errorCount -gt 0) {
    Write-Host "`n====================================" -ForegroundColor Red
    Write-Host " アップロード一部失敗" -ForegroundColor Red
    Write-Host "====================================" -ForegroundColor Red
    Write-Host "  成功: $uploadCount ファイル"
    Write-Host "  失敗: $errorCount ファイル"
    Write-Host ""
    Write-Host "[FAILED] 上記の警告メッセージを確認してください。" -ForegroundColor Red
    exit 1
}

Write-Host "`n====================================" -ForegroundColor Green
Write-Host " 非構造化データのアップロード完了！" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host "  成功: $uploadCount ファイル"
Write-Host "  失敗: $errorCount ファイル"
Write-Host ""
Write-Host "次のステップ: Fabric Lakehouse から Azure Storage へのショートカットを作成してください。"
Write-Host "詳細は sprint1/README.md の Step 6 を参照してください。"
