$ErrorActionPreference = 'Stop'

$bundleRoot = Split-Path $PSScriptRoot -Parent
$sourceRoot = Join-Path $bundleRoot 'source'
$exportRoot = Join-Path $bundleRoot 'dist'
$version = (Get-Content (Join-Path $sourceRoot 'apps\kimi-code\package.json') -Raw | ConvertFrom-Json).version
$staging = Join-Path $exportRoot "CustomKIMI-$version"
$archive = Join-Path $exportRoot "CustomKIMI-$version.zip"

Remove-Item $staging, $archive -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$staging\source", "$staging\config", "$staging\scripts" -Force | Out-Null

$secretLike = Get-ChildItem $bundleRoot -Force -File | Where-Object {
  $_.Name -match '^\.env|^config\.toml$|\.log$'
}
if ($secretLike) {
  throw 'Refusing to export: possible secret/config files found in the bundle root.'
}

$excludedDirectories = @('node_modules', '.git', 'dist', 'dist-single', 'dist-native', 'coverage', '.tmp', '.vitest-results', '.vite', '.kimi-code')
$excludedFiles = @('.env', '.env.*', 'config.toml', '*.log')
$robocopyArgs = @($sourceRoot, "$staging\source", '/E', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/XD') + $excludedDirectories + @('/XF') + $excludedFiles
& robocopy @robocopyArgs | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Source staging copy failed with robocopy exit code $LASTEXITCODE." }
Copy-Item (Join-Path $bundleRoot 'custom') "$staging\custom" -Recurse
Copy-Item (Join-Path $bundleRoot 'config\config.toml.example') "$staging\config\config.toml.example"
Copy-Item (Join-Path $bundleRoot 'README.md') "$staging\README.md"
Copy-Item (Join-Path $bundleRoot 'AI-INSTALL-GUIDE.md') "$staging\AI-INSTALL-GUIDE.md"
Copy-Item (Join-Path $bundleRoot 'scripts\install.ps1'), (Join-Path $bundleRoot 'scripts\install.sh'), (Join-Path $bundleRoot 'scripts\update.sh'), (Join-Path $bundleRoot 'scripts\export.ps1'), (Join-Path $bundleRoot 'scripts\export.sh') "$staging\scripts" -Force

$stagingSecrets = Get-ChildItem $staging -Recurse -Force -File | Where-Object {
  $_.Name -match '^\.env|^config\.toml$|\.log$'
}
if ($stagingSecrets) {
  Remove-Item $staging -Recurse -Force
  throw 'Refusing to export: secret-like file entered the staging directory.'
}

$keyFiles = Get-ChildItem $staging -Recurse -Force -File |
  Select-String -Pattern 'closerouter_[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{40,}|sk-or-v1-[A-Za-z0-9]{32,}' -CaseSensitive -List |
  Select-Object -ExpandProperty Path
if ($keyFiles) {
  Remove-Item $staging -Recurse -Force
  throw "Refusing to export: an API key was found in: $($keyFiles -join ', ')"
}

Compress-Archive -Path $staging -DestinationPath $archive -CompressionLevel Optimal
Remove-Item $staging -Recurse -Force
Write-Host "Created $archive"
