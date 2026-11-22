[CmdletBinding()]
param(
    # Coding clients to install/log into, e.g. -Providers claude or -Providers claude,codex.
    [string[]]$Providers,
    [switch]$SkipLogin
)
$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot) { throw 'Download/clone this repository first, then run setup.bat. Remote iex installation is no longer supported.' }
. "$PSScriptRoot/scripts/Common.ps1"
if (-not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell.' }
Update-TeamPath
$config = Get-TeamConfig
$known = @((Get-Providers).Keys)
if (-not $Providers) {
    $default = @($config.DefaultProviders) -join ','
    $answer = Read-Host "Coding clients to set up ($($known -join ', '); comma-separated) [$default]"
    $Providers = if ($answer) { $answer -split '[,\s]+' } else { @($config.DefaultProviders) }
}
$Providers = @($Providers | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ } | Select-Object -Unique)
foreach ($name in $Providers) { $null = Get-Provider $name }

if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { Install-WingetPackage 'Git.Git' 'Install Git for Windows from https://git-scm.com/download/win and rerun setup.bat.' }
if (-not (Find-Tool 'herdr-app')) { Install-OfficialScript 'https://releases.herdr.dev/app/install.ps1' }
if (-not (Find-Tool 'hc')) { Install-OfficialScript 'https://releases.herdr.dev/core/install.ps1' }
foreach ($name in $Providers) {
    $provider = Get-Provider $name
    if (-not (Find-Tool $provider.Tool)) {
        if (-not $provider['Install']) { throw "Install $(Get-ProviderLabel $provider) manually, then rerun setup.bat." }
        Write-Host "Installing $(Get-ProviderLabel $provider)..."
        & $provider.Install
        Update-TeamPath
    }
}
foreach ($tool in @('herdr-app','hc') + @($Providers | ForEach-Object { (Get-Provider $_).Tool })) {
    $path = Find-Tool $tool
    if (-not $path) { throw "$tool is missing. Open a new terminal and rerun setup.bat." }
    Write-Host "$tool : $path"
}
if (-not $SkipLogin) {
    Clear-ProviderEnvironment
    foreach ($name in $Providers) {
        $provider = Get-Provider $name
        if (-not $provider['Login']) { continue }
        $exe = Find-Tool $provider.Tool
        $status = $null
        try { $status = & $provider.TestReady $exe } catch { }
        $prompt = if ($status) { "$status Log in again? [y/N]" } else { "Log into $(Get-ProviderLabel $provider) now? [Y/n]" }
        $answer = Read-Host $prompt
        $go = if ($status) { $answer -match '^(y|yes)$' } else { $answer -notmatch '^(n|no)$' }
        if ($go) {
            if ($provider['LoginHint']) { Write-Host $provider.LoginHint }
            & $provider.Login $exe
        }
    }
}
$profileHint = if ($Providers -contains 'claude' -and $Providers.Count -eq 1) { ' (claude or claude-lite)' } else { '' }
Write-Host "Setup complete. Double-click launch.bat, choose a project folder and profile$profileHint."
