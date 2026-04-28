param(
    [string]$RepoName = "minecraft-legacy-rus",
    [string]$Description = "Неофициальный русификатор для Minecraft Legacy Console Edition Windows64",
    [string]$Version = "0.1.0",
    [switch]$Private
)

$ErrorActionPreference = "Stop"

$Gh = "gh"
if (Test-Path "C:\Program Files\GitHub CLI\gh.exe") {
    $Gh = "C:\Program Files\GitHub CLI\gh.exe"
}

& $Gh auth status

$Visibility = "--public"
if ($Private) {
    $Visibility = "--private"
}

$CurrentBranch = (git branch --show-current).Trim()
if ($CurrentBranch -ne "main") {
    git branch -M main
}

& $Gh repo create $RepoName $Visibility --description $Description --source . --remote origin --push

$Tag = "v$Version"

powershell -ExecutionPolicy Bypass -File .\scripts\build-release.ps1 -Version $Version
& $Gh release create $Tag ".\release\Minecraft-Legacy-Rus.zip" --title "Русификатор $Tag" --notes-file ".\docs\РЕЛИЗ.md" --target main --latest

Write-Host "Готово. Репозиторий и релиз опубликованы."
