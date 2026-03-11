<#
.SYNOPSIS
    Fabric Workspace Managed Identity に Azure Storage の RBAC ロールを付与するスクリプト

.DESCRIPTION
    01_setup_azure_storage.ps1 で FabricWorkspaceMiObjectId を指定しなかった場合、
    または後から Fabric ワークスペースを作成した場合に実行します。
    
    付与するロール:
      - Storage Blob Data Reader: Lakehouse ショートカット（読み取り）・COPY INTO に必要
    
    【前提知識】
    Fabric ワークスペースの Managed Identity (Workspace Identity) は、
    Fabric ポータル → ワークスペース設定 → 「ワークスペース ID」メニューで確認できます。
    "オブジェクト ID" の値をこのスクリプトに渡してください。

.PREREQUISITES
    - Azure CLI で az login 済み（RBAC 付与には Owner または User Access Administrator ロールが必要）
    - 01_setup_azure_storage.ps1 が実行済み（scripts/.env.storage が存在する）
    - Fabric ワークスペースが作成済みで、Workspace Identity が有効になっていること

.USAGE
    .\scripts\04_assign_rbac.ps1 -FabricWorkspaceMiObjectId "<object-id>"

    # Object ID の確認方法（Fabric ポータルで確認できない場合）
    # az ad sp list --display-name "<ワークスペース名>" --query "[].id" --output tsv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FabricWorkspaceMiObjectId,

    [string]$EnvFile = ""   # 省略時は scripts/.env.storage を自動検索
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── ヘルパー関数 ───────────────────────────────────────────────

function Write-Step   { param([string]$M); Write-Host "`n[STEP] $M" -ForegroundColor Cyan }
function Write-Success{ param([string]$M); Write-Host "[OK]   $M" -ForegroundColor Green }
function Write-Info   { param([string]$M); Write-Host "[INFO] $M" -ForegroundColor Yellow }
function Write-Warn   { param([string]$M); Write-Host "[WARN] $M" -ForegroundColor Magenta }

# ─── 設定読み込み ────────────────────────────────────────────────

Write-Step "1/4 設定ファイルの読み込み"

if ([string]::IsNullOrEmpty($EnvFile)) {
    $EnvFile = Join-Path $PSScriptRoot ".env.storage"
}

if (-not (Test-Path $EnvFile)) {
    Write-Error ".env.storage が見つかりません: $EnvFile`n先に 01_setup_azure_storage.ps1 を実行してください。"
    exit 1
}

$envVars = @{}
Get-Content $EnvFile | Where-Object { $_ -match "^[^#].*=.*" } | ForEach-Object {
    $p = $_ -split "=", 2
    $envVars[$p[0].Trim()] = $p[1].Trim()
}

$resourceGroup   = $envVars["AZURE_RESOURCE_GROUP"]
$storageAccount  = $envVars["AZURE_STORAGE_ACCOUNT"]
$storageScope    = $envVars["AZURE_STORAGE_SCOPE"]

if (-not $storageAccount) {
    Write-Error ".env.storage から AZURE_STORAGE_ACCOUNT を読み込めませんでした。"
    exit 1
}

# .env.storage に AZURE_STORAGE_SCOPE がない場合は az で取得
if (-not $storageScope) {
    Write-Info "AZURE_STORAGE_SCOPE が未設定のため az で取得します..."
    $storageScope = az storage account show `
        --name $storageAccount `
        --resource-group $resourceGroup `
        --query "id" --output tsv
}

Write-Success "Storage: $storageAccount"
Write-Success "Scope  : $storageScope"
Write-Success "MI     : $FabricWorkspaceMiObjectId"

# ─── ログイン確認 ────────────────────────────────────────────────

Write-Step "2/4 Azure ログイン確認"

$account = az account show --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $account) {
    Write-Info "ログインが必要です..."
    az login
    $account = az account show --output json | ConvertFrom-Json
}
Write-Success "ログイン済み: $($account.user.name) | $($account.name)"

# ─── 既存の RBAC ロール確認 ─────────────────────────────────────

Write-Step "3/4 既存の RBAC ロール確認"

$existingAssignments = az role assignment list `
    --assignee $FabricWorkspaceMiObjectId `
    --scope $storageScope `
    --output json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

$roles = @(
    "Storage Blob Data Reader"
)

foreach ($role in $roles) {
    $exists = $existingAssignments | Where-Object { $_.roleDefinitionName -eq $role }
    if ($exists) {
        Write-Info "ロール '$role' は既に付与済みです。スキップします。"
    } else {
        Write-Info "ロール '$role' を付与します..."

        az role assignment create `
            --role $role `
            --assignee-object-id $FabricWorkspaceMiObjectId `
            --assignee-principal-type ServicePrincipal `
            --scope $storageScope `
            --output none

        Write-Success "付与完了: $role"
    }
}

# ─── 共有キーアクセスの無効化確認 ────────────────────────────────

Write-Step "4/4 Storage Account の共有キーアクセス設定を確認"

$allowSharedKey = az storage account show `
    --name $storageAccount `
    --resource-group $resourceGroup `
    --query "allowSharedKeyAccess" --output tsv

if ($allowSharedKey -eq "true" -or $allowSharedKey -eq "True") {
    Write-Warn "共有キーアクセスがまだ有効です。Managed Identity のみに制限するため無効化します..."

    az storage account update `
        --name $storageAccount `
        --resource-group $resourceGroup `
        --allow-shared-key-access false `
        --output none

    Write-Success "共有キーアクセスを無効化しました。"
} else {
    Write-Success "共有キーアクセスは既に無効化されています。"
}

# ─── 完了 ────────────────────────────────────────────────────────

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Managed Identity RBAC 設定完了！" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "付与済みロール:"
Write-Host "  Storage Blob Data Reader → Fabric Workspace MI ($FabricWorkspaceMiObjectId)"
Write-Host ""
Write-Host "次のステップ:"
Write-Host "  1. Fabric ポータルで Lakehouse ショートカットをワークスペース ID で再作成"
Write-Host "     （既存のショートカットは削除 → 認証方式:ワークスペース ID で再作成）"
Write-Host "  2. Warehouse の COPY INTO を実行して動作確認"
Write-Host "     （scripts/copy_into_commands.sql / scripts/verify_data.sql を使用）"
Write-Host "  3. sprint2/README.md の Step 3 を参照"
