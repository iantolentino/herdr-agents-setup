[CmdletBinding()]
param([switch]$SkipLogin)
$ErrorActionPreference = 'Stop'
if (-not $PSScriptRoot) { throw 'Download/clone this repository first, then run setup.bat. Remote iex installation is no longer supported.' }
. "$PSScriptRoot/scripts/Common.ps1"
if (-not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell.' }
function Install-OfficialScript([string]$Uri) {
    $file = Join-Path ([IO.Path]::GetTempPath()) ('herdr-team-' + [guid]::NewGuid() + '.ps1')
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $file
        Invoke-Native (Get-PowerShell) @('-NoProfile','-ExecutionPolicy','Bypass','-File',$file) -Interactive
    } finally { if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force } }
    Update-TeamPath
}
Update-TeamPath
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { throw 'Install Git for Windows from https://git-scm.com/download/win and rerun setup.bat.' }
    Invoke-Native 'winget.exe' @('install','--id','Git.Git','--exact','--accept-source-agreements','--accept-package-agreements') -Interactive
    Update-TeamPath
}
if (-not (Find-Tool 'herdr-app')) { Install-OfficialScript 'https://releases.herdr.dev/app/install.ps1' }
if (-not (Find-Tool 'hc')) { Install-OfficialScript 'https://releases.herdr.dev/core/install.ps1' }
if (-not (Find-Tool 'codex')) {
    if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { throw 'Install Node.js LTS from https://nodejs.org and rerun setup.bat.' }
        Invoke-Native 'winget.exe' @('install','--id','OpenJS.NodeJS.LTS','--exact','--accept-source-agreements','--accept-package-agreements') -Interactive
        Update-TeamPath
    }
    & npm.cmd install -g @openai/codex
    if ($LASTEXITCODE -ne 0) { throw 'Codex installation failed.' }
    Update-TeamPath
}
if (-not (Find-Tool 'claude')) { Install-OfficialScript 'https://claude.ai/install.ps1' }
foreach ($tool in @('herdr-app','hc','codex','claude')) {
    $path = Find-Tool $tool
    if (-not $path) { throw "$tool is missing. Open a new terminal and rerun setup.bat." }
    Write-Host "$tool : $path"
}
if (-not $SkipLogin) {
    Clear-ProviderEnvironment
    $choice = Read-Host 'Log in: 1 = Codex, 2 = Claude, 3 = both, 4 = later [3]'
    if ($choice -in @('','1','3')) {
        Write-Host 'Sign in using your ChatGPT account (subscription access).'
        Invoke-Native (Find-Tool 'codex') @('login') -Interactive
    }
    if ($choice -in @('','2','3')) {
        Write-Host 'Sign in using your Claude subscription account, not Console/API billing.'
        Invoke-Native (Find-Tool 'claude') @('auth','login') -Interactive
    }
}
Write-Host 'Setup complete. Double-click launch.bat, choose a project folder and provider.'
