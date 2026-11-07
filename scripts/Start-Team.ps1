[CmdletBinding()]
param([string]$Project, [ValidateSet('codex','claude','mixed')][string]$Profile, [switch]$SmokeTest)
. "$PSScriptRoot/Common.ps1"
Update-TeamPath
$preferences = Join-Path $env:LOCALAPPDATA 'HerdrAgentTeams/launcher.json'
if (-not $Project -and (Test-Path -LiteralPath $preferences)) {
    $last = Get-Content -LiteralPath $preferences -Raw | ConvertFrom-Json
    if (Test-Path -LiteralPath $last.project -PathType Container) {
        $Project = $last.project
        if (-not $Profile) { $Profile = $last.profile }
    }
}
$Project = Resolve-Project $Project
$teamDir = Get-TeamDirectory $Project
New-Item -ItemType Directory -Force -Path $teamDir | Out-Null
# Hold a per-project lock through all creation steps to prevent double-click races.
$lock = $null
try {
    try { $lock = [IO.File]::Open((Join-Path $teamDir 'launcher.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { throw 'Another launcher is already working on this project. Wait for it to finish.' }
    foreach ($tool in @('herdr-app','hc')) {
        if (-not (Find-Tool $tool)) { throw "$tool is missing. Run setup.bat first." }
    }
    $app = Find-Tool 'herdr-app'
    try { $null = Invoke-Native $app @('status') }
    catch {
        # Use the same persistent PATH that Herdr Core refreshes for new terminals.
        # A coding tool may inject a private pwsh.exe path unavailable to the core.
        $savedPath = $env:Path
        try {
            $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
            Start-Process -FilePath $app
        } finally { $env:Path = $savedPath }
        $started = $false
        for ($attempt = 0; $attempt -lt 30; $attempt++) {
            Start-Sleep -Milliseconds 500
            try { $null = Invoke-Native $app @('status'); $started = $true; break } catch { }
        }
        if (-not $started) { throw 'Herdr did not open. Start it from the Start menu and rerun launch.bat.' }
    }
    $manifestPath = Join-Path $teamDir 'team.json'
    if (Test-Path -LiteralPath $manifestPath) {
        $old = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $live = (Invoke-Native (Find-Tool 'hc') @('ls','--json') | ConvertFrom-Json).terminals
        $owned = @($live | Where-Object { $_.address -in @($old.roles | ForEach-Object { $_.terminal }) })
        if ($owned.Count -gt 0) {
            foreach ($terminal in $owned) {
                $detail = Invoke-Native (Find-Tool 'hc') @('get',$terminal.address,'--json') | ConvertFrom-Json
                $owner = $detail.labels.PSObject.Properties['team.run']
                if (-not $owner -or $owner.Value -ne $old.runId) { throw 'Saved terminal IDs now belong to a different session. Inspect the saved team.json before proceeding.' }
            }
            if ($Profile -and $Profile -ne $old.profile) { throw 'A team is still running. Run stop.bat for this project before changing provider.' }
            if ($owned.Count -ne 5 -or -not $old.ready) { throw 'A partial team exists. Inspect it in Herdr, then use stop.bat before relaunching.' }
            if ([bool]$old.smokeTest -ne [bool]$SmokeTest) { throw 'A different test/live mode is running. Stop that team before changing modes.' }
            $null = Invoke-App 'agent.focus' @{terminal=$old.roles[0].terminal}
            Write-Host "Reopened the existing $($old.profile) team. No duplicate agents created."
            return
        }
    }
    if (-not $Profile) {
        $choice = Read-Host 'Provider: 1 = Codex, 2 = Claude, 3 = mixed (Claude lead/reviewer; Codex others) [1]'
        $Profile = switch ($choice) { '2' { 'claude' }; '3' { 'mixed' }; '' { 'codex' }; '1' { 'codex' }; default { throw 'Choose 1, 2, or 3.' } }
    }
    $providers = if ($Profile -eq 'mixed') { @('codex','claude') } else { @($Profile) }
    if (-not $SmokeTest) {
        Clear-ProviderEnvironment
        foreach ($provider in $providers) {
            $exe = Find-Tool $provider
            if (-not $exe) { throw "$provider is missing. Run setup.bat first." }
            if ($provider -eq 'codex') {
                $auth = Invoke-Native $exe @('login','status') -IncludeStderr
                if ($auth -notmatch 'ChatGPT') { throw 'Run codex login and sign in with ChatGPT before launching.' }
                $help = Invoke-Native $exe @('--help')
                if ($help -notmatch '--no-daemon') { throw 'Update Codex first: this Herdr setup requires --no-daemon.' }
            } else {
                $auth = Invoke-Native $exe @('auth','status') | ConvertFrom-Json
                if (-not $auth.loggedIn -or $auth.authMethod -ne 'claude.ai') { throw 'Run claude auth login and choose your Claude subscription account first.' }
            }
        }
    }
    $runId = [guid]::NewGuid().ToString('N')
    $runDir = Join-Path $teamDir $runId
    New-Item -ItemType Directory -Path $runDir | Out-Null
    foreach ($instruction in Get-ChildItem -LiteralPath (Join-Path (Split-Path $PSScriptRoot) 'roles') -Filter '*.md') {
        Copy-Item -LiteralPath $instruction.FullName -Destination (Join-Path $runDir $instruction.Name)
    }
    $handoff = Join-Path $teamDir 'HANDOFF.md'
    if (-not (Test-Path -LiteralPath $handoff)) { [IO.File]::WriteAllText($handoff, "# Team handoff`r`n`r`nNo task assigned yet. The orchestrator maintains this file.`r`n") }
    $state = [ordered]@{version=1; project=$Project; profile=$Profile; runId=$runId; directory=$runDir; space=''; ready=$false; smokeTest=[bool]$SmokeTest; roles=@()}
    Save-Json $manifestPath $state
    $roles = @('orchestrator','coder','reviewer','tester','deployer')
    foreach ($role in $roles) {
        $provider = if ($Profile -eq 'mixed') { if ($role -in @('orchestrator','reviewer')) { 'claude' } else { 'codex' } } else { $Profile }
        $roleFile = Join-Path $runDir "$role.json"
        Save-Json $roleFile @{role=$role; provider=$provider; project=$Project; manifest=$manifestPath; directory=$runDir; smokeTest=[bool]$SmokeTest}
        $wrapper = Join-Path $PSScriptRoot 'Run-Agent.ps1'
        # Encode only the invocation; arbitrary folder names never become executable code.
        $command = "& '" + $wrapper.Replace("'","''") + "' -Config '" + $roleFile.Replace("'","''") + "'"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $argv = @((Get-PowerShell),'-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded)
        if ($role -eq 'orchestrator') {
            $created = Invoke-App 'space.new' @{name="Team - $([IO.Path]::GetFileName($Project))";folder=$Project;tab=$role;argv=$argv}
            $state.space = $created.space
        } else {
            $created = Invoke-App 'tab.new' @{space=$state.space;name=$role;folder=$Project;argv=$argv}
        }
        $state.roles += @{role=$role;provider=$provider;terminal=$created.terminal;tab=$created.tab}
        Save-Json $manifestPath $state
        $null = Invoke-Native (Find-Tool 'hc') @('label',$created.terminal,"team.run=$runId","team.role=$role")
    }
    $state.ready = $true
    Save-Json $manifestPath $state
    [IO.File]::WriteAllText((Join-Path $runDir 'ready'), 'ready')
    $null = Invoke-App 'agent.focus' @{terminal=$state.roles[0].terminal}
    if (-not $SmokeTest) { Save-Json $preferences @{project=$Project;profile=$Profile} }
    Write-Host "Opened five $Profile agent tabs. Give your task to the orchestrator."
    Write-Host 'Complete any first-run login/trust prompts in each tab. Permission prompts are not auto-accepted.'
    Write-Host "Team state and handoff notes: $teamDir"
} finally { if ($lock) { $lock.Dispose() } }
