$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

git config core.hooksPath githooks
Write-Host "Configured local git hooks path: githooks"
Write-Host "Verify with: git config --get core.hooksPath"
