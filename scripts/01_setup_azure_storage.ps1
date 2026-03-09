<#
.SYNOPSIS
    Azure Storage アカウントのセットアップスクリプト
    
.DESCRIPTION
    製造業 Data Agent PoC 用の Azure Blob Storage を作成します。
    Resource Group、Storage Account、Blob コンテナ、フォルダ構造を作成します。
    
.PREREQUISITES
    - Azure CLI (az) がインストール済みであること
    - az login で認証済みであること
    - 適切なサブスクリプション権限があること

.USAGE
    .\scripts\01_setup_azure_storage.ps1
    .\scripts\01_setup_azure_storage.ps1 -ResourceGroup "my-rg" -Location "eastus"
#>

[CmdletBinding()]
param(
    [string]$ResourceGroup   = "rg-fabric-dataagent-poc",
    [string]$Location        = "japaneast",
    [string]$StorageAccount  = "",       # 空の場合は自動生成
    [string]$ContainerName   = "manufacturing-docs"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── ヘルパー関数 ───────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "`n[STEP] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

# ─── 事前確認 ───────────────────────────────────────────────────

Write-Step "1/7 Azure CLI のバージョン確認"
try {
    $azVersion = az --version 2>&1 | Select-Object -First 1
    Write-Success "Azure CLI が見つかりました: $azVersion"
} catch {
    Write-Error "Azure CLI が見つかりません。https://learn.microsoft.com/cli/azure/install-azure-cli からインストールしてください。"
    exit 1
}

Write-Step "2/7 ログイン状態の確認"
$account = az account show --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $account) {
    Write-Info "ログインが必要です。ブラウザが開きます..."
    az login
    $account = az account show --output json | ConvertFrom-Json
}
Write-Success "ログイン済み: $($account.user.name) | サブスクリプション: $($account.name)"

# ─── Storage Account 名の決定 ──────────────────────────────────

if ([string]::IsNullOrEmpty($StorageAccount)) {
    # Storage Account 名はグローバルで一意である必要があるため、ランダムサフィックスを付与
    $suffix = -join ((48..57) + (97..122) | Get-Random -Count 6 | ForEach-Object { [char]$_ })
    $StorageAccount = "stfabricdatapoc$suffix"
}

Write-Info "使用するリソース設定:"
Write-Info "  Resource Group  : $ResourceGroup"
Write-Info "  Location        : $Location"
Write-Info "  Storage Account : $StorageAccount"
Write-Info "  Container       : $ContainerName"

# ─── Resource Group の作成 ─────────────────────────────────────

Write-Step "3/7 Resource Group の作成"
$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "true") {
    Write-Info "Resource Group '$ResourceGroup' は既に存在します。スキップします。"
} else {
    az group create `
        --name $ResourceGroup `
        --location $Location `
        --output none
    Write-Success "Resource Group '$ResourceGroup' を作成しました。"
}

# ─── Storage Account の作成 ────────────────────────────────────

Write-Step "4/7 Storage Account の作成"
$saExists = az storage account check-name --name $StorageAccount --query "nameAvailable" --output tsv
if ($saExists -eq "false") {
    Write-Info "Storage Account '$StorageAccount' は既に存在するか、名前が使用中です。既存を使用します。"
} else {
    az storage account create `
        --name $StorageAccount `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2 `
        --allow-blob-public-access false `
        --min-tls-version TLS1_2 `
        --output none
    Write-Success "Storage Account '$StorageAccount' を作成しました。"
}

# ─── Blob コンテナの作成 ────────────────────────────────────────

Write-Step "5/7 Blob コンテナの作成"
$containerExists = az storage container exists `
    --name $ContainerName `
    --account-name $StorageAccount `
    --auth-mode login `
    --query "exists" --output tsv

if ($containerExists -eq "true") {
    Write-Info "コンテナ '$ContainerName' は既に存在します。スキップします。"
} else {
    az storage container create `
        --name $ContainerName `
        --account-name $StorageAccount `
        --auth-mode login `
        --output none
    Write-Success "コンテナ '$ContainerName' を作成しました。"
}

# ─── フォルダ構造の初期化 ────────────────────────────────────────

Write-Step "6/7 フォルダ構造の初期化（.keep ファイルで構造を作成）"

$folders = @(
    "product_specs",
    "work_manuals",
    "parts_catalog",
    "quality_standards"
)

$tempKeep = New-TemporaryFile

foreach ($folder in $folders) {
    $blobName = "$folder/.keep"
    
    az storage blob upload `
        --account-name $StorageAccount `
        --container-name $ContainerName `
        --name $blobName `
        --file $tempKeep.FullName `
        --auth-mode login `
        --overwrite true `
        --output none 2>&1 | Out-Null

    Write-Success "フォルダを作成しました: $folder/"
}

Remove-Item $tempKeep.FullName -Force

# ─── 接続情報の出力 ─────────────────────────────────────────────

Write-Step "7/7 接続情報の確認・保存"

$storageKey = az storage account keys list `
    --account-name $StorageAccount `
    --resource-group $ResourceGroup `
    --query "[0].value" --output tsv

$connectionString = az storage account show-connection-string `
    --name $StorageAccount `
    --resource-group $ResourceGroup `
    --query "connectionString" --output tsv

# 設定ファイルに保存（git ignore 対象にすること）
$configContent = @"
# Azure Storage 接続設定 (自動生成 - git に含めないこと)
# 生成日時: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

AZURE_RESOURCE_GROUP=$ResourceGroup
AZURE_LOCATION=$Location
AZURE_STORAGE_ACCOUNT=$StorageAccount
AZURE_CONTAINER_NAME=$ContainerName
AZURE_STORAGE_CONNECTION_STRING=$connectionString
"@

$configPath = Join-Path $PSScriptRoot "..\scripts\.env.storage"
$configContent | Out-File -FilePath $configPath -Encoding UTF8 -Force

Write-Success "接続設定を保存しました: scripts/.env.storage"
Write-Info "※ .env.storage は機密情報を含むため、git にコミットしないでください。"

Write-Host "`n====================================" -ForegroundColor Green
Write-Host " Azure Storage セットアップ完了！" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host "  Storage Account: $StorageAccount"
Write-Host "  Container      : $ContainerName"
Write-Host "  URL            : https://$StorageAccount.blob.core.windows.net/$ContainerName"
Write-Host ""
Write-Host "次のステップ: .\scripts\02_upload_unstructured_data.ps1 を実行してください。"
