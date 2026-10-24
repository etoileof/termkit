$ErrorActionPreference = 'Stop'

$bundleRoot = Split-Path $PSScriptRoot -Parent
$sourceRoot = Join-Path $bundleRoot 'source'
$configTemplate = Join-Path $bundleRoot 'config\config.toml.example'
$configDirectory = Join-Path $HOME '.kimi-code'
$configPath = Join-Path $configDirectory 'config.toml'
$tuiConfigPath = Join-Path $configDirectory 'tui.toml'

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw 'Node.js 24.15 or newer is required. Install Node.js and rerun this script.'
}

$nodeVersion = [version]((node --version).TrimStart('v'))
if ($nodeVersion -lt [version]'24.15.0') {
  throw "Node.js 24.15 or newer is required; found $nodeVersion."
}

if (-not (Get-Command corepack -ErrorAction SilentlyContinue)) {
  throw 'Corepack is required to activate the pnpm version declared by the source workspace.'
}

if (-not $env:CLOSEROUTER_API_KEY) {
  $secureKey = Read-Host 'Enter your CloseRouter API key (leave blank to configure it later)' -AsSecureString
  if ($secureKey.Length -gt 0) {
    $env:CLOSEROUTER_API_KEY = [System.Net.NetworkCredential]::new('', $secureKey).Password
  }
}

Push-Location $sourceRoot
try {
  corepack pnpm --version | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Could not activate pnpm through Corepack.' }

  if (-not (Test-Path $configPath)) {
    New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
    Copy-Item $configTemplate $configPath
    Write-Host "Created Kimi configuration at $configPath"
  } else {
    Write-Host "Keeping existing Kimi configuration at $configPath"
  }

  # Kimi's auto-updater would replace this custom build with the official npm release.
  if (-not (Test-Path $tuiConfigPath)) {
    [System.IO.File]::WriteAllText($tuiConfigPath, "[upgrade]`nauto_install = false`n")
    Write-Host "Disabled Kimi auto-update in $tuiConfigPath"
  } else {
    $tuiConfig = [System.IO.File]::ReadAllText($tuiConfigPath)
    if ($tuiConfig -match '(?m)^auto_install = true') {
      [System.IO.File]::WriteAllText($tuiConfigPath, ($tuiConfig -replace '(?m)^auto_install = true', 'auto_install = false'))
      Write-Host "Disabled Kimi auto-update in $tuiConfigPath"
    }
  }

  corepack pnpm install
  if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
  corepack pnpm run build:packages
  if ($LASTEXITCODE -ne 0) { throw 'Workspace package build failed.' }
  corepack pnpm --filter @moonshot-ai/kimi-code run build
  if ($LASTEXITCODE -ne 0) { throw 'Kimi Code build failed.' }
  Push-Location (Join-Path $sourceRoot 'apps\kimi-code')
  try {
    npm link
    if ($LASTEXITCODE -ne 0) { throw 'Global Kimi link failed.' }
  } finally {
    Pop-Location
  }
} finally {
  Pop-Location
}

if ($env:CLOSEROUTER_API_KEY) {
  Write-Host 'CloseRouter key is available for this PowerShell session.'
} else {
  Write-Host 'No key entered. Set CLOSEROUTER_API_KEY before launching kimi.'
}
Write-Host 'CustomKIMI is installed. Run: kimi --version'
