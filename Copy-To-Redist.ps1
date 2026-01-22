#Requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-PSDebug -Trace 0

function Set-ConsoleColor ($bc, $fc) {
    $Host.UI.RawUI.BackgroundColor = $bc
    $Host.UI.RawUI.ForegroundColor = $fc
}
Set-ConsoleColor 'DarkCyan' 'White'

$host.UI.RawUI.WindowTitle = "Copy Detail Textures to Redist"

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Copy Detail Textures to Redist" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

$detailedTexturesRoot = $PSScriptRoot
$redistRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'redist'

# Verify paths exist
if (-not (Test-Path $redistRoot)) {
    Write-Error "Redist directory not found: $redistRoot"
    exit 1
}

# Copy maps folder (detail texture mapping files)
$sourceMaps = Join-Path $detailedTexturesRoot 'maps'
$destMaps = Join-Path $redistRoot 'maps'

if (Test-Path $sourceMaps) {
    Write-Host "Copying detail texture mapping files..." -ForegroundColor Yellow
    # Clean existing detail files before copying
    if (Test-Path $destMaps) {
        Write-Host "  Cleaning existing detail mapping files..." -ForegroundColor Cyan
        Get-ChildItem -Path $destMaps -Filter '*_detail.txt' | Remove-Item -Force
    }
        $detailFiles = Get-ChildItem -Path $sourceMaps -Filter '*_detail.txt'
    foreach ($file in $detailFiles) {
        Copy-Item -Path $file.FullName -Destination $destMaps -Force
        Write-Host "  Copied: $($file.Name)" -ForegroundColor Green
    }
    
    Write-Host "Copied $($detailFiles.Count) detail mapping files" -ForegroundColor Green
} else {
    Write-Warning "Maps directory not found: $sourceMaps"
}

Write-Host ""

# Copy gfx folder (detail texture TGA files)
$sourceGfx = Join-Path $detailedTexturesRoot 'gfx'
$destGfx = Join-Path $redistRoot 'gfx'

if (Test-Path $sourceGfx) {
    Write-Host "Copying detail texture TGA files..." -ForegroundColor Yellow
    
    # Ensure destination gfx/detail directory exists
    $destGfxDetail = Join-Path $destGfx 'detail'
    if (-not (Test-Path $destGfxDetail)) {
        New-Item -ItemType Directory -Path $destGfxDetail -Force | Out-Null
        Write-Host "  Created directory: gfx\detail" -ForegroundColor Cyan
    } else {
        # Clean existing files before copying
        Write-Host "  Cleaning existing detail textures..." -ForegroundColor Cyan
        Get-ChildItem -Path $destGfxDetail -Filter '*.tga' | Remove-Item -Force
    }
    
    # Copy all TGA files from gfx/detail
    $sourceGfxDetail = Join-Path $sourceGfx 'detail'
    if (Test-Path $sourceGfxDetail) {
        $tgaFiles = Get-ChildItem -Path $sourceGfxDetail -Filter '*.tga'
        foreach ($file in $tgaFiles) {
            Copy-Item -Path $file.FullName -Destination $destGfxDetail -Force
        }
        Write-Host "  Copied $($tgaFiles.Count) TGA files to gfx\detail" -ForegroundColor Green
    } else {
        Write-Warning "Detail textures directory not found: $sourceGfxDetail"
    }
} else {
    Write-Warning "GFX directory not found: $sourceGfx"
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Copy completed successfully!" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Detail textures are now available in redist for testing in-game."
