<#
.SYNOPSIS
    Reset de progresso do personagem Wagstaff no DST.
    Mantem configs de mods intactas.

.DESCRIPTION
    Lista todos os mundos salvos em save/session/,
    permite selecionar qual resetar (ou todos),
    cria backup automatico antes de deletar.

.USAGE
    .\reset-wagstaff-progress.ps1
#>

$ErrorActionPreference = "Stop"

# Caminho padrao da pasta DST
$dstPath = Join-Path $env:USERPROFILE "Documents\Klei\DoNotStarveTogether"
$sessionPath = Join-Path $dstPath "save\session"
$backupPath = Join-Path $dstPath "save\_wagstaff_reset_backups"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Wagstaff Mod - Reset de Progresso" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verifica se a pasta existe
if (-not (Test-Path $dstPath)) {
    Write-Host "[ERRO] Pasta DST nao encontrada: $dstPath" -ForegroundColor Red
    Write-Host "Verifique se DST esta instalado." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $sessionPath)) {
    Write-Host "[ERRO] Pasta de sessoes nao encontrada: $sessionPath" -ForegroundColor Red
    Write-Host "Voce ja criou um mundo?" -ForegroundColor Yellow
    exit 1
}

# Lista mundos
$worlds = Get-ChildItem -Path $sessionPath -Directory | Where-Object {
    $_.Name -notmatch "^_"
}

if ($worlds.Count -eq 0) {
    Write-Host "[INFO] Nenhum mundo encontrado em $sessionPath" -ForegroundColor Yellow
    exit 0
}

# Tenta ler o nome do mundo dos saves
Write-Host "Mundos encontrados:" -ForegroundColor White
Write-Host ""

$worldList = @()
$i = 0

foreach ($world in $worlds) {
    $i++
    $worldName = $world.Name
    $worldSize = "{0:N1} MB" -f ((Get-ChildItem -Path $world.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB)

    # Tenta achar o nome do mundo no save
    $mainDir = Join-Path $world.FullName "main"
    if (Test-Path $mainDir) {
        $worldFiles = Get-ChildItem -Path $mainDir -Filter "*.sav" | Where-Object { $_.Name -notmatch "mod" }
        foreach ($wf in $worldFiles) {
            # Tenta extrair nome do arquivo (formato padrao DST)
            if ($wf.Name -match "^(.+?)_\d+") {
                $worldName = $Matches[1]
            }
        }
    }

    $worldList += @{
        Index = $i
        Path  = $world.FullName
        Name  = $worldName
        Size  = $worldSize
        Dir   = $world.Name
    }

    Write-Host "  [$i] $worldName" -ForegroundColor Green
    Write-Host "      Pasta: $($world.Name) | Tamanho: $worldSize" -ForegroundColor DarkGray
    Write-Host ""
}

Write-Host "  [T] TODOS os mundos" -ForegroundColor Red
Write-Host "  [0] Cancelar" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Selecione uma opcao"

if ($choice -eq "0" -or [string]::IsNullOrWhiteSpace($choice)) {
    Write-Host "Cancelado." -ForegroundColor Gray
    exit 0
}

# Determina quais mundos resetar
$toReset = @()

if ($choice -eq "T" -or $choice -eq "t") {
    $confirm = Read-Host "ATENCAO: Isso vai resetar TODOS os $i mundos. Continuar? (S/N)"
    if ($confirm -ne "S" -and $confirm -ne "s") {
        Write-Host "Cancelado." -ForegroundColor Gray
        exit 0
    }
    $toReset = $worldList
} else {
    $idx = [int]$choice - 1
    if ($idx -lt 0 -or $idx -ge $worldList.Count) {
        Write-Host "[ERRO] Opcao invalida." -ForegroundColor Red
        exit 1
    }
    $toReset = @($worldList[$idx])
}

# Cria pasta de backup
if (-not (Test-Path $backupPath)) {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

foreach ($w in $toReset) {
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor Yellow
    Write-Host "Resetando: $($w.Name)" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Yellow

    $backupDir = Join-Path $backupPath "${timestamp}_$($w.Dir)"
    Write-Host "[1/2] Criando backup em: $backupDir" -ForegroundColor DarkGray

    # Copia para backup
    Copy-Item -Path $w.Path -Destination $backupDir -Recurse -Force

    # Deleta o mundo original
    Write-Host "[2/2] Deletando save original..." -ForegroundColor DarkGray
    Remove-Item -Path $w.Path -Recurse -Force

    Write-Host "  OK! Mundo resetado." -ForegroundColor Green
    Write-Host "  Backup salvo em: $backupDir" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Concluido!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Mundos resetados: $($toReset.Count)" -ForegroundColor White
Write-Host "  Backups em: $backupPath" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Proximo passo: Abra o DST e crie um novo mundo." -ForegroundColor Yellow
Write-Host "  Suas configs de mods foram mantidas intactas." -ForegroundColor Yellow
Write-Host ""