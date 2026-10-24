# Runs the packaged setup.ps1 end to end on a Windows runner (Windows PowerShell 5.1):
# install with only a 7api key, add a CloseRouter key, remove it, uninstall.
param(
  [Parameter(Mandatory = $true)][string]$Package,
  [Parameter(Mandatory = $true)][string]$Version
)

$ErrorActionPreference = 'Stop'
$setup = Join-Path $Package 'setup.ps1'
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\termkit'
$exe = Join-Path $installDir 'kimi.exe'
$configPath = Join-Path $env:USERPROFILE '.kimi-code\config.toml'
$tuiPath = Join-Path $env:USERPROFILE '.kimi-code\tui.toml'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\termkit'
$marker = '# termkit-setup: no CloseRouter key'

function Check([bool]$Condition, [string]$What) {
  if (-not $Condition) { throw "FAILED: $What" }
  Write-Host "ok - $What"
}

function Run-Setup([string[]]$Arguments) {
  Write-Host ''
  Write-Host ">> setup.ps1 $($Arguments -join ' ')"
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup @Arguments
  if ($LASTEXITCODE -ne 0) { throw "setup.ps1 $($Arguments -join ' ') exited with $LASTEXITCODE" }
}

function User-Env([string]$Name) { [Environment]::GetEnvironmentVariable($Name, 'User') }

function User-Path {
  $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
  try {
    return New-Object PSObject -Property @{
      Value = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
      Kind = $key.GetValueKind('Path')
    }
  } finally {
    $key.Close()
  }
}

function Path-Count {
  return @((User-Path).Value -split ';' | Where-Object { $_.TrimEnd('\') -eq $installDir }).Count
}

function Marker-Count { @(Select-String -LiteralPath $configPath -SimpleMatch $marker).Count }

function Doctor {
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $env:KIMI_CODE_NO_AUTO_UPDATE = '1'
  $output = & $exe doctor config 2>&1 | Out-String
  $code = $LASTEXITCODE
  $ErrorActionPreference = $previous
  Write-Host $output.Trim()
  return $code
}

# A %VARIABLE% entry must survive the PATH rewrite unexpanded.
[Environment]::SetEnvironmentVariable('Path', '%USERPROFILE%\ck-sentinel;' + (User-Path).Value, 'User')

Run-Setup @('-NoPrompt', '-SkipKeyCheck', '-SevenApiKey', 'ci-7api-key')
Check (Test-Path -LiteralPath $exe) 'kimi.exe installed'
$env:KIMI_CODE_NO_AUTO_UPDATE = '1'
Check ((& $exe --version | Out-String).Trim() -eq $Version) "kimi --version prints $Version"
Check ((Path-Count) -eq 1) 'install dir is on the user PATH once'
Check (((User-Path).Value -split ';')[0].TrimEnd('\') -eq $installDir) 'install dir comes first on the user PATH'
Check ((User-Path).Value.Contains('%USERPROFILE%\ck-sentinel')) 'other PATH entries stay unexpanded'
Check ((User-Path).Kind -eq [Microsoft.Win32.RegistryValueKind]::ExpandString) 'user PATH stays REG_EXPAND_SZ'
Check ((User-Env 'SEVENAPI_API_KEY') -eq 'ci-7api-key') '7api key saved'
Check (-not (User-Env 'CLOSEROUTER_API_KEY')) 'CloseRouter key skipped'
Check ((User-Env 'KIMI_CODE_NO_AUTO_UPDATE') -eq '1') 'KIMI_CODE_NO_AUTO_UPDATE=1 saved'
Check ((Get-Content -LiteralPath $tuiPath -Raw) -match '(?m)^auto_install = false') 'tui.toml disables auto-update'
Check ((Get-Content -LiteralPath $configPath -TotalCount 1) -eq 'default_model = "7api/gpt-6-astra"') 'default model switched to 7api'
Check ((Marker-Count) -eq 2) 'CloseRouter refresh disabled on both CloseRouter providers'
Check (Test-Path -LiteralPath $uninstallKey) 'listed in Installed apps'
Check ((Doctor) -eq 0) 'kimi doctor config accepts the config'

Run-Setup @('-NoPrompt', '-SkipKeyCheck', '-CloseRouterKey', 'ci-closerouter-key')
Check ((User-Env 'CLOSEROUTER_API_KEY') -eq 'ci-closerouter-key') 'CloseRouter key saved'
Check ((User-Env 'SEVENAPI_API_KEY') -eq 'ci-7api-key') '7api key kept'
Check ((Marker-Count) -eq 0) 'CloseRouter refresh re-enabled'
Check ((Get-Content -LiteralPath $configPath -TotalCount 1) -eq 'default_model = "7api/gpt-6-astra"') 'existing default model kept'
Check ((Path-Count) -eq 1) 'install dir still on the user PATH once'
Check ((Doctor) -eq 0) 'kimi doctor config still accepts the config'

Run-Setup @('-NoPrompt', '-SkipKeyCheck', '-CloseRouterKey', '-')
Check (-not (User-Env 'CLOSEROUTER_API_KEY')) 'CloseRouter key removed'
Check ((Marker-Count) -eq 2) 'CloseRouter refresh disabled again'
Check ((Doctor) -eq 0) 'kimi doctor config accepts the config again'

Run-Setup @('-Uninstall', '-NoPrompt', '-RemoveKeys')
Check (-not (Test-Path -LiteralPath $installDir)) 'install dir removed'
Check ((Path-Count) -eq 0) 'install dir removed from the user PATH'
Check ((User-Path).Value.Contains('%USERPROFILE%\ck-sentinel')) 'other PATH entries kept'
Check (-not (Test-Path -LiteralPath $uninstallKey)) 'removed from Installed apps'
Check (-not (User-Env 'SEVENAPI_API_KEY')) '7api key removed'
Check (-not (User-Env 'KIMI_CODE_NO_AUTO_UPDATE')) 'KIMI_CODE_NO_AUTO_UPDATE removed'
Check (Test-Path -LiteralPath $configPath) 'config.toml kept'

Write-Host ''
Write-Host 'Installer test passed.'
