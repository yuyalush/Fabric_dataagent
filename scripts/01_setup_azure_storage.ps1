<#
.SYNOPSIS
    Azure Storage アカウントのセットアップスクリプト（Managed Identity 対応版）
    
.DESCRIPTION
    製造業 Data Agent PoC 用の Azure Blob Storage を作成します。
    Resource Group、Storage Account、Blob コンテナ、フォルダ構造を作成します。
    
    【セキュリティ】
    アカウントキー・接続文字列を一切使用しません。
    すべての操作は --auth-mode login（Entra ID トークン）で行い、
    Storage Account の共有キーアクセスも作成後に無効化します。
    Fabric（Warehouse COPY INTO / Lakehouse ショートカット）は
    Workspace Managed Identity に Storage Blob Data Reader ロールを付与して統合します。
    
.PREREQUISITES
    - Azure CLI (az) がインストール済みであること
    - az login で認証済みであること
    - 適切なサブスクリプション権限があること
      （Storage Account 作成: Contributor 以上）
      （RBAC 付与: User Access Administrator または Owner）
    - Fabric ワークスペースの Managed Identity Object ID が手元にあること
      （Fabric ポータル → ワークスペース設定 → 「ワークスペース ID」で確認）

.USAGE
    .\scripts\01_setup_azure_storage.ps1
    .\scripts\01_setup_azure_storage.ps1 -ResourceGroup "my-rg" -Location "eastus"
    .\scripts\01_setup_azure_storage.ps1 -FabricWorkspaceMiObjectId "<object-id>"
#>

[CmdletBinding()]
param(
    [string]$ResourceGroup              = "rg-fabric-dataagent-poc",
    [string]$Location                   = "japaneast",
    [string]$StorageAccount             = "",       # 空の場合は自動生成
    [string]$ContainerName              = "manufacturing-docs",
    [string]$FabricWorkspaceMiObjectId  = ""        # Fabric Workspace MI の Object ID（RBAC 付与に使用）
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

# ─── 共有キーアクセスの無効化 ───────────────────────────────────

Write-Step "7/8 Storage Account の共有キーアクセスを無効化（Managed Identity のみに制限）"

az storage account update `
    --name $StorageAccount `
    --resource-group $ResourceGroup `
    --allow-shared-key-access false `
    --output none

Write-Success "共有キー（アカウントキー / 接続文字列）でのアクセスを無効化しました。"
Write-Info "以降のすべてのアクセスは Entra ID（--auth-mode login）または Managed Identity で行われます。"

# ─── Fabric Workspace Identity への RBAC 付与 ──────────────────

Write-Step "8/8 接続情報の保存 および Fabric Managed Identity への RBAC 付与"

$storageScope = $(az storage account show `
    --name $StorageAccount `
    --resource-group $ResourceGroup `
    --query "id" --output tsv)

if ($FabricWorkspaceMiObjectId) {
    Write-Info "Fabric Workspace MI ($FabricWorkspaceMiObjectId) に Storage Blob Data Reader を付与中..."

    az role assignment create `
        --role "Storage Blob Data Reader" `
        --assignee-object-id $FabricWorkspaceMiObjectId `
        --assignee-principal-type ServicePrincipal `
        --scope $storageScope `
        --output none

    Write-Success "RBAC 付与が完了しました。"
    Write-Info "Fabric Warehouse の COPY INTO および Lakehouse ショートカットで Managed Identity が使用できます。"
} else {
    Write-Info "FabricWorkspaceMiObjectId が未指定のため、RBAC 付与はスキップしました。"
    Write-Info "後から付与する場合は scripts/04_assign_rbac.ps1 を実行してください。"
}

# ─── 設定ファイルの保存（キーレス）───────────────────────────────

$configContent = @"
# Azure Storage 設定 (自動生成 - git に含めないこと)
# 生成日時: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# 認証方式: Managed Identity / az login (接続文字列・アカウントキー不使用)

AZURE_RESOURCE_GROUP=$ResourceGroup
AZURE_LOCATION=$Location
AZURE_STORAGE_ACCOUNT=$StorageAccount
AZURE_CONTAINER_NAME=$ContainerName
AZURE_STORAGE_URL=https://$StorageAccount.blob.core.windows.net
AZURE_STORAGE_SCOPE=$storageScope
"@

$configPath = Join-Path $PSScriptRoot ".env.storage"
$configContent | Out-File -FilePath $configPath -Encoding UTF8 -Force

Write-Success "設定を保存しました: scripts/.env.storage（接続文字列・キーは含まれていません）"

Write-Host "`n====================================" -ForegroundColor Green
Write-Host " Azure Storage セットアップ完了！" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host "  Storage Account    : $StorageAccount"
Write-Host "  Container          : $ContainerName"
Write-Host "  URL                : https://$StorageAccount.blob.core.windows.net/$ContainerName"
Write-Host "  共有キーアクセス  : 無効（Managed Identity / Entra ID のみ）"
if ($FabricWorkspaceMiObjectId) {
    Write-Host "  Fabric RBAC       : 付与済み (Storage Blob Data Reader)"
} else {
    Write-Host "  Fabric RBAC       : 未付与 → scripts/04_assign_rbac.ps1 を実行してください"
}
Write-Host ""
Write-Host "次のステップ:"
Write-Host "  1. .\scripts\02_upload_unstructured_data.ps1 を実行"
if (-not $FabricWorkspaceMiObjectId) {
    Write-Host "  2. Fabric ポータルでワークスペース ID を確認後、04_assign_rbac.ps1 を実行"
    Write-Host "  3. スプリント1 Step 6: Lakehouse ショートカットをワークスペース ID で作成"
} else {
    Write-Host "  2. スプリント1 Step 6: Lakehouse ショートカットをワークスペース ID で作成"
}
