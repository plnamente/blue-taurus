# ==============================================================================
# BLUE-TAURUS: BOM REMOVER
# Descrição: Remove a marca Byte Order Mark (BOM) dos arquivos SQL.
# ==============================================================================

$ProjectName = "blue-taurus"
Write-Host "[FIX] Iniciando remocao de BOM (Byte Order Mark)..." -ForegroundColor Cyan

# Verifica pasta
$MigrationPath = "crates/server/migrations"
if (-not (Test-Path $MigrationPath)) {
    # Tenta caminho relativo se estiver fora
    $MigrationPath = "$ProjectName/crates/server/migrations"
}

if (-not (Test-Path $MigrationPath)) {
    Write-Host "[ERROR] Pasta de migrations nao encontrada!" -ForegroundColor Red
    exit 1
}

# Configura UTF-8 SEM BOM
$Utf8NoBom = New-Object System.Text.UTF8Encoding $False

# Busca arquivos .sql e reescreve
$Files = Get-ChildItem -Path $MigrationPath -Filter "*.sql"

foreach ($file in $Files) {
    Write-Host " -> Processando: $($file.Name)" -ForegroundColor Yellow
    
    # Le o conteudo
    $content = Get-Content $file.FullName
    
    # Reescreve sem o BOM
    [System.IO.File]::WriteAllLines($file.FullName, $content, $Utf8NoBom)
    
    Write-Host "    [OK] BOM removido." -ForegroundColor Green
}

Write-Host "[SUCCESS] Arquivos limpos. Pode rodar o server!" -ForegroundColor Cyan