#Requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-PSDebug -Trace 0

function Set-ConsoleColor ($bc, $fc) {
    $Host.UI.RawUI.BackgroundColor = $bc
    $Host.UI.RawUI.ForegroundColor = $fc
    # Clear-Host
}
Set-ConsoleColor 'DarkCyan' 'White'

$Config = @{ }

# https://stackoverflow.com/questions/27794898/powershell-pass-named-parameters-to-argumentlist
([string]$args).split('-') | %{
    if ($_.Split(' ')[0].ToUpper() -eq "ConfigFile") {
        $configFile = $_.Split(' ')[1]
        . ("$PSScriptRoot\$configFile.ps1")
        echo "configuration file is $configFile..."
    }
}

$host.UI.RawUI.WindowTitle = "Packaging Detailed Textures"

Import-Module $PSScriptRoot\powershell\Package-Release.psm1 -Force -DisableNameChecking

$rootDir = ${PSScriptRoot}.Trimend('\')
$gameFolder = $Config['gameFolder'] ?? "ice_beta2"

Detailed-Textures-Pack-Release $rootDir $gameFolder

Set-Location -Path ${PSScriptRoot}
