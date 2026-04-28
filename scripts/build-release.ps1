param(
    [string]$Version = "0.1.0",
    [string]$OutputDirectory = "release"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$OutputPath = Join-Path $Root $OutputDirectory
$PackageRoot = Join-Path $OutputPath "Minecraft-Legacy-Rus"
$ZipPath = Join-Path $OutputPath "Minecraft-Legacy-Rus.zip"

if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $PackageRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $PackageRoot "assets") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $PackageRoot "docs") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $PackageRoot "scripts") | Out-Null

Get-ChildItem -LiteralPath $Root -File -Filter "*.md" | Copy-Item -Destination $PackageRoot
Copy-Item -LiteralPath (Join-Path $Root "install-russian.bat") -Destination $PackageRoot
Copy-Item -LiteralPath (Join-Path $Root "restore-english.bat") -Destination $PackageRoot
Copy-Item -LiteralPath (Join-Path $Root "assets\banner.png") -Destination (Join-Path $PackageRoot "assets")
Get-ChildItem -LiteralPath (Join-Path $Root "docs") -File -Filter "*.md" | Copy-Item -Destination (Join-Path $PackageRoot "docs")
Copy-Item -LiteralPath (Join-Path $Root "scripts\install.ps1") -Destination (Join-Path $PackageRoot "scripts")

Set-Content -LiteralPath (Join-Path $PackageRoot "VERSION.txt") -Value $Version -Encoding UTF8

Compress-Archive -Path (Join-Path $PackageRoot "*") -DestinationPath $ZipPath -Force

Write-Host "Done: $ZipPath"
Write-Host "Version: $Version"
