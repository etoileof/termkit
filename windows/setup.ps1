# termkit setup for Windows.
#
# Installs kimi.exe for the current user (no admin needed), asks for the
# CloseRouter and 7api API keys (either one can be skipped) and prepares
# ~/.kimi-code. Run it through "Install.cmd" / "Uninstall.cmd".
#
# Non-interactive use (CI):
#   setup.ps1 -NoPrompt [-CloseRouterKey <key>] [-SevenApiKey <key>] [-SkipKeyCheck]
#   setup.ps1 -Uninstall -NoPrompt [-RemoveKeys]
# A key that is omitted or empty keeps the saved one; '-' removes it.

[CmdletBinding()]
param(
  [switch]$Uninstall,
  [switch]$NoPrompt,
  [string]$CloseRouterKey = '',
  [string]$SevenApiKey = '',
  [switch]$SkipKeyCheck,
  [switch]$RemoveKeys,
  [switch]$PauseAtEnd
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\termkit'
$ExePath = Join-Path $InstallDir 'kimi.exe'
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\termkit'
$StaticMarker = '# termkit-setup: no CloseRouter key'
$SevenApiDefaultModel = '7api/gpt-6-astra'
$CloseRouterProviders = @('providers.closerouter', 'providers.closerouter-anthropic')

function Say([string]$Text) { Write-Host "   $Text" }
function Ok([string]$Text) { Write-Host "   $Text" -ForegroundColor Green }
function Warn([string]$Text) { Write-Host "   ! $Text" -ForegroundColor Yellow }
function Step([string]$Text) {
  Write-Host ''
  Write-Host "== $Text" -ForegroundColor Cyan
}

function Get-KimiHome {
  if ($env:KIMI_CODE_HOME) { return $env:KIMI_CODE_HOME }
  return Join-Path $env:USERPROFILE '.kimi-code'
}

function Write-TextFile([string]$Path, [string]$Text) {
  [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

# --- user environment -------------------------------------------------------

function Get-UserEnv([string]$Name) {
  return [Environment]::GetEnvironmentVariable($Name, 'User')
}

# Writes HKCU\Environment and tells running programs about it. An empty value deletes the variable.
function Set-UserEnv([string]$Name, [string]$Value) {
  if ($Value) {
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
  } else {
    [Environment]::SetEnvironmentVariable($Name, $null, 'User')
    [Environment]::SetEnvironmentVariable($Name, $null, 'Process')
  }
}

function Get-EffectiveEnv([string]$Name) {
  $value = Get-UserEnv $Name
  if (-not $value) { $value = [Environment]::GetEnvironmentVariable($Name, 'Machine') }
  return $value
}

# The user PATH is read and written raw so %VARIABLES% in it stay unexpanded (REG_EXPAND_SZ).
function Get-UserPathEntries {
  $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
  try {
    $raw = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
  } finally {
    $key.Close()
  }
  return @($raw -split ';' | Where-Object { $_ -ne '' })
}

function Set-UserPathEntries([string[]]$Entries) {
  $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
  try {
    if ($Entries.Count -gt 0) {
      $key.SetValue('Path', ($Entries -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)
    } else {
      $key.DeleteValue('Path', $false)
    }
  } finally {
    $key.Close()
  }
}

function Test-SameDir([string]$A, [string]$B) {
  $a = [Environment]::ExpandEnvironmentVariables($A).Trim().TrimEnd('\')
  $b = [Environment]::ExpandEnvironmentVariables($B).Trim().TrimEnd('\')
  return $a -eq $b
}

function Add-InstallDirToPath {
  $others = @(Get-UserPathEntries | Where-Object { -not (Test-SameDir $_ $InstallDir) })
  Set-UserPathEntries (@($InstallDir) + $others)
  $env:Path = "$InstallDir;$env:Path"
}

function Remove-InstallDirFromPath {
  $entries = @(Get-UserPathEntries)
  $others = @($entries | Where-Object { -not (Test-SameDir $_ $InstallDir) })
  if ($others.Count -ne $entries.Count) { Set-UserPathEntries $others }
}

# The first kimi a new terminal would run, when it is not ours.
function Find-ShadowingKimi {
  $dirs = @()
  $dirs += [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
  $dirs += Get-UserPathEntries
  foreach ($dir in $dirs) {
    if (-not $dir) { continue }
    if (Test-SameDir $dir $InstallDir) { return $null }
    $expanded = [Environment]::ExpandEnvironmentVariables($dir).Trim()
    foreach ($ext in @('.exe', '.cmd', '.bat', '.ps1')) {
      try {
        $candidate = Join-Path $expanded "kimi$ext"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
      } catch {
      }
    }
  }
  return $null
}

# --- API keys ---------------------------------------------------------------

function Read-Secret([string]$Prompt) {
  $secure = Read-Host -Prompt $Prompt -AsSecureString
  if ($null -eq $secure -or $secure.Length -eq 0) { return '' }
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Format-KeyHint([string]$Key) {
  if ($Key.Length -le 8) { return 'the saved key' }
  return 'the saved key ...' + $Key.Substring($Key.Length - 4)
}

function Get-HttpStatus($ErrorRecord) {
  $response = $ErrorRecord.Exception.Response
  if ($null -eq $response) { return $null }
  try { return [int]$response.StatusCode } catch { return $null }
}

# Returns $true (accepted), $false (rejected) or $null (could not check).
function Test-ApiKey([string]$Label, [string]$Url, [string]$Key) {
  try {
    $response = Invoke-WebRequest -Uri $Url -Headers @{ Authorization = "Bearer $Key" } -UseBasicParsing -TimeoutSec 20
  } catch {
    $status = Get-HttpStatus $_
    if ($status -eq 401 -or $status -eq 403) {
      Warn "$Label rejected this key (HTTP $status)."
      return $false
    }
    if ($status) {
      Warn "Could not check the $Label key (HTTP $status). It is saved anyway."
    } else {
      Warn "Could not reach $Label to check the key ($($_.Exception.Message)). It is saved anyway."
    }
    return $null
  }
  $detail = ''
  if ($Label -eq 'CloseRouter') {
    try {
      $json = $response.Content | ConvertFrom-Json
      foreach ($candidate in @($json.data, $json)) {
        if ($null -ne $candidate -and $candidate.PSObject.Properties['total_credits']) {
          $detail = " (balance: $($candidate.total_credits))"
          break
        }
      }
    } catch {
    }
  }
  Ok "$Label key works$detail."
  return $true
}

function Resolve-ApiKey([string]$Label, [string]$EnvName, [string]$CheckUrl, [string]$Given) {
  $saved = Get-UserEnv $EnvName
  $answer = $Given
  if (-not $NoPrompt) {
    if ($saved) {
      $answer = Read-Secret "$Label API key (Enter = keep $(Format-KeyHint $saved), - = remove)"
    } else {
      $answer = Read-Secret "$Label API key (Enter = skip)"
    }
  }

  while ($true) {
    $answer = $answer.Trim().Trim([char[]]@([char]'"', [char]"'")).Trim()
    if ($answer -eq '-') {
      if ($saved) {
        Set-UserEnv $EnvName ''
        Warn "$Label key removed."
      } else {
        Say "$Label skipped."
      }
      return ''
    }
    if (-not $answer) {
      if ($saved) {
        Ok "$Label key kept."
        return $saved
      }
      Say "$Label skipped."
      return ''
    }
    if ($answer -match '\s') {
      Warn "That $Label key contains spaces; keys never do."
      if ($NoPrompt) { throw "Invalid $Label key." }
      $answer = Read-Secret "$Label API key (Enter = skip)"
      continue
    }

    Set-UserEnv $EnvName $answer
    if ($SkipKeyCheck) {
      Ok "$Label key saved."
      return $answer
    }
    $accepted = Test-ApiKey $Label $CheckUrl $answer
    if ($accepted -ne $false -or $NoPrompt) {
      if ($accepted -ne $true) { Say "$Label key saved." }
      return $answer
    }
    $retry = Read-Secret "Paste the $Label key again (Enter = keep the one you typed)"
    if (-not $retry.Trim()) {
      Warn "$Label key saved, but $Label did not accept it. Run the installer again to replace it."
      return $answer
    }
    $answer = $retry
  }
}

# --- config.toml ------------------------------------------------------------

function Get-TomlTable([string]$Line) {
  if ($Line -match '^\s*\[\[?\s*([^\]]+?)\s*\]\]?\s*(#.*)?$') {
    return ($Matches[1] -replace '["''\s]', '')
  }
  return $null
}

# With no CloseRouter key, `model_source = "static"` stops Kimi from refreshing (and warning about)
# the CloseRouter models on every start. The lines carry a marker so a later run can take them out.
function Update-CloseRouterRefresh([string]$Path, [bool]$Disable) {
  $text = [System.IO.File]::ReadAllText($Path)
  $newline = "`n"
  if ($text.Contains("`r`n")) { $newline = "`r`n" }
  $lines = @($text -split '\r?\n')

  $ownSetting = @{}
  $table = ''
  foreach ($line in $lines) {
    $header = Get-TomlTable $line
    if ($null -ne $header) { $table = $header; continue }
    if ($line -match '^\s*model_source\s*=' -and -not $line.Contains($StaticMarker)) { $ownSetting[$table] = $true }
  }

  $out = New-Object System.Collections.Generic.List[string]
  $changed = $false
  $table = ''
  foreach ($line in $lines) {
    if ($line.Contains($StaticMarker)) {
      $changed = $true
      continue
    }
    $out.Add($line)
    $header = Get-TomlTable $line
    if ($null -ne $header) { $table = $header; continue }
    if ($Disable -and ($CloseRouterProviders -contains $table) -and -not $ownSetting[$table] -and $line -match '^\s*api_key_env\s*=') {
      $out.Add("model_source = `"static`" $StaticMarker")
      $changed = $true
    }
  }
  $updated = [string]::Join($newline, $out.ToArray())
  if ($changed -and $updated -ne $text) { Write-TextFile $Path $updated }
}

function Set-DefaultModel([string]$Path, [string]$Model) {
  $text = [System.IO.File]::ReadAllText($Path)
  $regex = New-Object System.Text.RegularExpressions.Regex('(?m)^default_model\s*=.*?(?=\r?$)')
  if ($regex.IsMatch($text)) {
    $text = $regex.Replace($text, "default_model = `"$Model`"", 1)
  } else {
    $text = "default_model = `"$Model`"`n" + $text
  }
  Write-TextFile $Path $text
}

# Kimi's auto-updater would replace this build with the plain official release.
function Disable-AutoUpdate([string]$KimiHome) {
  $tuiPath = Join-Path $KimiHome 'tui.toml'
  if (-not (Test-Path -LiteralPath $tuiPath)) {
    Write-TextFile $tuiPath "[upgrade]`nauto_install = false`n"
  } else {
    $tui = [System.IO.File]::ReadAllText($tuiPath)
    if ($tui -match '(?m)^\s*auto_install\s*=\s*true') {
      Write-TextFile $tuiPath ($tui -replace '(?m)^(\s*)auto_install\s*=\s*true', '${1}auto_install = false')
    } elseif ($tui -notmatch '(?m)^\s*auto_install\s*=') {
      if ($tui -match '(?m)^\s*\[upgrade\]') {
        Write-TextFile $tuiPath ($tui -replace '(?m)^(\s*\[upgrade\][^\r\n]*)', "`${1}`nauto_install = false")
      } else {
        Write-TextFile $tuiPath ($tui.TrimEnd() + "`n`n[upgrade]`nauto_install = false`n")
      }
    }
  }
  Set-UserEnv 'KIMI_CODE_NO_AUTO_UPDATE' '1'
  Ok "Kimi's own auto-update is off (it would replace this build with the plain release)."
}

function Confirm-Choice([string]$Question) {
  if ($NoPrompt) { return $false }
  $reply = Read-Host -Prompt "$Question [y/N]"
  return $reply -match '^\s*(y|yes)\s*$'
}

# Windows PowerShell turns a native command's stderr into terminating errors under 'Stop'.
function Invoke-Kimi([string[]]$Arguments) {
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = @(& $ExePath @Arguments 2>&1 | ForEach-Object { "$_" })
    return New-Object PSObject -Property @{ Code = $LASTEXITCODE; Text = ($output -join "`n").Trim() }
  } catch {
    return New-Object PSObject -Property @{ Code = -1; Text = $_.Exception.Message }
  } finally {
    $ErrorActionPreference = $previous
  }
}

# --- install ----------------------------------------------------------------

function Install-Termkit {
  $payload = Join-Path $PSScriptRoot 'kimi.exe'
  $template = Join-Path $PSScriptRoot 'config.toml.example'
  if (-not (Test-Path -LiteralPath $payload) -or -not (Test-Path -LiteralPath $template)) {
    throw 'kimi.exe or config.toml.example is missing next to setup.ps1. Extract the whole zip first, then run Install.cmd from the extracted folder.'
  }
  if (Test-SameDir $PSScriptRoot $InstallDir) {
    throw 'This is the installed copy. Run Install.cmd from the downloaded folder instead.'
  }
  $version = ''
  $versionFile = Join-Path $PSScriptRoot 'version.txt'
  if (Test-Path -LiteralPath $versionFile) { $version = ([System.IO.File]::ReadAllText($versionFile)).Trim() }

  Write-Host ''
  Write-Host ("termkit $version setup" -replace '\s+', ' ') -ForegroundColor Cyan
  Say "kimi.exe goes to $InstallDir and is added to your PATH."

  Step 'API keys'
  if (-not $NoPrompt) {
    Say 'Paste a key and press Enter. What you type is hidden (shown as *).'
    Say 'Press Enter on an empty line to skip a key. Run this installer again to change keys later.'
    Write-Host ''
  }
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $null = Resolve-ApiKey 'CloseRouter' 'CLOSEROUTER_API_KEY' 'https://api.closerouter.dev/v1/credits' $CloseRouterKey
  $null = Resolve-ApiKey '7api' 'SEVENAPI_API_KEY' 'https://7api.st/v1/models' $SevenApiKey
  $hasCloseRouter = [bool](Get-EffectiveEnv 'CLOSEROUTER_API_KEY')
  $hasSevenApi = [bool](Get-EffectiveEnv 'SEVENAPI_API_KEY')

  Step 'Installing kimi.exe'
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  Get-ChildItem -LiteralPath $InstallDir -Filter 'kimi.exe.old-*' -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
  if (Test-Path -LiteralPath $ExePath) {
    try {
      Remove-Item -LiteralPath $ExePath -Force
    } catch {
      # A running kimi.exe cannot be replaced, but it can be renamed out of the way.
      Rename-Item -LiteralPath $ExePath -NewName ('kimi.exe.old-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    }
  }
  Copy-Item -LiteralPath $payload -Destination $ExePath -Force
  Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $InstallDir 'setup.ps1') -Force
  Copy-Item -LiteralPath $template -Destination (Join-Path $InstallDir 'config.toml.example') -Force
  if (Test-Path -LiteralPath $versionFile) { Copy-Item -LiteralPath $versionFile -Destination (Join-Path $InstallDir 'version.txt') -Force }
  Get-ChildItem -LiteralPath $InstallDir -File | Unblock-File
  Add-InstallDirToPath
  Ok "Installed $ExePath"

  $displayVersion = ($version -split ' ')[0]
  New-Item -Path $UninstallKey -Force | Out-Null
  Set-ItemProperty -Path $UninstallKey -Name 'DisplayName' -Value 'termkit'
  Set-ItemProperty -Path $UninstallKey -Name 'DisplayVersion' -Value $displayVersion
  Set-ItemProperty -Path $UninstallKey -Name 'Publisher' -Value 'termkit'
  Set-ItemProperty -Path $UninstallKey -Name 'InstallLocation' -Value $InstallDir
  Set-ItemProperty -Path $UninstallKey -Name 'DisplayIcon' -Value $ExePath
  Set-ItemProperty -Path $UninstallKey -Name 'UninstallString' -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\setup.ps1`" -Uninstall -PauseAtEnd"
  New-ItemProperty -Path $UninstallKey -Name 'NoModify' -Value 1 -PropertyType DWord -Force | Out-Null
  New-ItemProperty -Path $UninstallKey -Name 'NoRepair' -Value 1 -PropertyType DWord -Force | Out-Null
  New-ItemProperty -Path $UninstallKey -Name 'EstimatedSize' -Value ([int]((Get-Item -LiteralPath $ExePath).Length / 1KB)) -PropertyType DWord -Force | Out-Null

  Step 'Configuration'
  $kimiHome = Get-KimiHome
  New-Item -ItemType Directory -Force -Path $kimiHome | Out-Null
  $configPath = Join-Path $kimiHome 'config.toml'
  $created = $false
  if (Test-Path -LiteralPath $configPath) {
    $existing = [System.IO.File]::ReadAllText($configPath)
    if ($existing -notmatch '(?m)^\s*\[providers\.closerouter\]' -and $existing -notmatch '(?m)^\s*\[providers\.7api\]') {
      Warn "$configPath has no CloseRouter or 7api providers (probably from the official Kimi)."
      if (Confirm-Choice '   Replace it with the termkit config? A backup is kept.') {
        $backup = "$configPath.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Copy-Item -LiteralPath $configPath -Destination $backup
        Copy-Item -LiteralPath $template -Destination $configPath -Force
        $created = $true
        Ok "Replaced it; the old one is $backup"
      } else {
        Say 'Kept it. The termkit template is in the install folder: config.toml.example'
      }
    } else {
      Ok "Keeping your existing $configPath"
    }
  } else {
    Copy-Item -LiteralPath $template -Destination $configPath
    $created = $true
    Ok "Created $configPath"
  }
  if ($created -and -not $hasCloseRouter -and $hasSevenApi) {
    Set-DefaultModel $configPath $SevenApiDefaultModel
    Ok "Default model: $SevenApiDefaultModel (no CloseRouter key). Switch any time with /model."
  }
  Update-CloseRouterRefresh $configPath (-not $hasCloseRouter)
  Disable-AutoUpdate $kimiHome

  Step 'Checking'
  $env:KIMI_CODE_NO_AUTO_UPDATE = '1'
  $installed = Invoke-Kimi @('--version')
  if ($installed.Code -ne 0 -or -not $installed.Text) {
    throw "kimi.exe was installed but does not start: $($installed.Text)`nIf Windows Security or Smart App Control blocked it, allow $ExePath and run the installer again."
  }
  Ok "kimi $($installed.Text) runs."
  $doctor = Invoke-Kimi @('doctor', 'config')
  if ($doctor.Code -ne 0) {
    Warn 'kimi doctor config found a problem in config.toml:'
    Write-Host $doctor.Text
  } else {
    Ok 'config.toml is valid.'
  }
  $shadow = Find-ShadowingKimi
  if ($shadow) {
    Warn "Another kimi comes first on your PATH: $shadow"
    Warn 'New terminals would start that one. Remove it (for an npm install: npm uninstall -g @moonshot-ai/kimi-code),'
    Warn "or start termkit with its full path: $ExePath"
  }
  if (-not $hasCloseRouter -and -not $hasSevenApi) {
    Warn 'No API key is set, so kimi cannot reach any model yet. Run Install.cmd again to add one.'
  }

  Step 'Done'
  Ok 'termkit is installed.'
  Say 'Close this window and open a NEW terminal (PowerShell or Windows Terminal),'
  Say 'go to your project folder and type:  kimi'
}

# --- uninstall --------------------------------------------------------------

function Uninstall-Termkit {
  Write-Host ''
  Write-Host 'termkit uninstall' -ForegroundColor Cyan
  Set-Location -LiteralPath $env:TEMP

  Step 'Removing kimi.exe'
  if (Test-Path -LiteralPath $InstallDir) {
    # The executables go first: a running kimi.exe stops the uninstall before anything else is gone.
    try {
      Get-ChildItem -LiteralPath $InstallDir -Filter 'kimi.exe*' -File |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
      Remove-Item -LiteralPath $InstallDir -Recurse -Force
      Ok "Removed $InstallDir"
    } catch {
      throw "Could not remove $InstallDir ($($_.Exception.Message)). Close every kimi window and run the uninstaller again."
    }
  } else {
    Say 'kimi.exe was not installed.'
  }
  Remove-InstallDirFromPath
  if (Test-Path -LiteralPath $UninstallKey) { Remove-Item -LiteralPath $UninstallKey -Recurse -Force }
  Ok 'Removed it from PATH and from Installed apps.'

  Step 'API keys'
  $savedKeys = @('CLOSEROUTER_API_KEY', 'SEVENAPI_API_KEY') | Where-Object { Get-UserEnv $_ }
  if (-not $savedKeys) {
    Say 'No saved keys.'
  } elseif ($RemoveKeys -or (Confirm-Choice '   Also delete your saved CloseRouter / 7api keys?')) {
    foreach ($name in $savedKeys) { Set-UserEnv $name '' }
    Ok 'Keys deleted.'
  } else {
    Say "Kept $($savedKeys -join ', ') in your user environment."
  }
  Set-UserEnv 'KIMI_CODE_NO_AUTO_UPDATE' ''

  Step 'Done'
  Ok 'termkit is uninstalled.'
  Say "Your settings and sessions are still in $(Get-KimiHome); delete that folder to remove them too."
}

$exitCode = 0
try {
  if ($Uninstall) { Uninstall-Termkit } else { Install-Termkit }
} catch {
  Write-Host ''
  Write-Host "Setup failed: $($_.Exception.Message)" -ForegroundColor Red
  $exitCode = 1
}
if ($PauseAtEnd -and -not $NoPrompt) {
  Write-Host ''
  Read-Host -Prompt 'Press Enter to close' | Out-Null
}
exit $exitCode
