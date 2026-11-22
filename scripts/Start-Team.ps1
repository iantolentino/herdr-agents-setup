[CmdletBinding()]
param([string]$Project, [string]$Profile, [switch]$SmokeTest)
. "$PSScriptRoot/Common.ps1"
Update-TeamPath
$config = Get-TeamConfig
# Validate an explicit profile before touching Herdr.
if ($Profile) { $null = Resolve-TeamProfile $config $Profile }
$preferences = Join-Path $env:LOCALAPPDATA 'HerdrAgentTeams/launcher.json'
if (-not $Project -and (Test-Path -LiteralPath $preferences)) {
    $last = Get-Content -LiteralPath $preferences -Raw | ConvertFrom-Json
    if (Test-Path -LiteralPath $last.project -PathType Container) {
        $Project = $last.project
        if (-not $Profile -and $last.profile -and $config.Profiles.Contains([string]$last.profile)) { $Profile = $last.profile }
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
            if ($owned.Count -ne @($old.roles).Count -or -not $old.ready) { throw 'A partial team exists. Inspect it in Herdr, then use stop.bat before relaunching.' }
            if ([bool]$old.smokeTest -ne [bool]$SmokeTest) { throw 'A different test/live mode is running. Stop that team before changing modes.' }
            $null = Invoke-App 'agent.focus' @{terminal=$old.roles[0].terminal}
            Write-Host "Reopened the existing $($old.profile) team. No duplicate agents created."
            return
        }
    }
    if (-not $Profile) {
        $names = @(Get-ProfileNames $config)
        $defaultIndex = [array]::IndexOf($names, [string]$config.DefaultProfile) + 1
        if ($defaultIndex -lt 1) { $defaultIndex = 1 }
        Write-Host 'Profiles:'
        for ($i = 0; $i -lt $names.Count; $i++) { Write-Host ("  {0} = {1}: {2}" -f ($i + 1), $names[$i], $config.Profiles[$names[$i]].Description) }
        $choice = Read-Host "Choose a profile [$defaultIndex]"
        if (-not $choice) { $choice = [string]$defaultIndex }
        $number = 0
        if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $names.Count) { $Profile = $names[$number - 1] }
        elseif ($config.Profiles.Contains($choice)) { $Profile = $choice }
        else { throw "Choose 1-$($names.Count) or a profile name." }
    }
    $roster = @(Resolve-TeamProfile $config $Profile)
    if (-not $SmokeTest) {
        Clear-ProviderEnvironment
        foreach ($name in @($roster | ForEach-Object { $_.provider } | Select-Object -Unique)) {
            $provider = Get-Provider $name
            $exe = Find-Tool $provider.Tool
            if (-not $exe) { throw "$(Get-ProviderLabel $provider) ($($provider.Tool)) is missing. Run setup.bat -Providers $name first." }
            $status = & $provider.TestReady $exe
            if ($status) { Write-Host $status }
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
    $state = [ordered]@{version=2; project=$Project; profile=$Profile; runId=$runId; directory=$runDir; space=''; ready=$false; smokeTest=[bool]$SmokeTest; roles=@()}
    Save-Json $manifestPath $state
    foreach ($entry in $roster) {
        $role = $entry.role
        $provider = $entry.provider
        $roleFile = Join-Path $runDir "$role.json"
        Save-Json $roleFile @{role=$role; provider=$provider; project=$Project; manifest=$manifestPath; directory=$runDir; smokeTest=[bool]$SmokeTest; teamSize=$roster.Count; sessionId=[guid]::NewGuid().ToString(); options=(Get-RoleOptions $config $provider $role)}
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
    Write-Host "Opened $($roster.Count) agent tabs ($Profile profile). Give your task to the orchestrator."
    Write-Host 'Complete any first-run login/trust prompts in each tab. Permission prompts are not auto-accepted.'
    Write-Host "Team state and handoff notes: $teamDir"
} finally { if ($lock) { $lock.Dispose() } }
