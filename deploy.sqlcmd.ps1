[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ServerInstance,
    [string]$Database = 'RestaurantOrderManagement',
    [switch]$TrustServerCertificate
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sqlFiles = @(
    'sql/00_create_database.sql',
    'sql/01_schema.sql',
    'sql/02_seed_data.sql',
    'sql/03_indexes.sql',
    'sql/04_views.sql',
    'sql/05_functions.sql',
    'sql/06_stored_procedures.sql',
    'sql/07_triggers.sql',
    'sql/08_analysis_queries.sql',
    'sql/09_test_cases.sql',
    'sql/extensions/12_recipe_ingredient_bom.sql',
    'sql/extensions/13_tax_service_charge_rules.sql',
    'sql/extensions/14_refunds_and_demo_gateway.sql',
    'sql/extensions/15_database_security_roles.sql'
)
foreach ($relativePath in $sqlFiles) {
    $file = Join-Path $root $relativePath
    if (-not (Test-Path $file)) { throw "Required SQL file not found: $file" }
    Write-Host "Deploying $relativePath ..."
    $args = @('-S', $ServerInstance, '-i', $file, '-b', '-r', '1')
    if ($TrustServerCertificate) { $args += '-C' }
    & sqlcmd @args
    if ($LASTEXITCODE -ne 0) { throw "Deployment failed at $relativePath (sqlcmd exit $LASTEXITCODE)." }
}
Write-Host 'Deployment scripts completed. Run the optional synthetic-data and performance scripts separately.' -ForegroundColor Green
