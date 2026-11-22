param([Parameter(Mandatory=$true)][string]$Config)
. "$PSScriptRoot/Common.ps1"
Update-TeamPath
$settings = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
Set-Location -LiteralPath $settings.project
# Build the provider-neutral launch context. Providers pick the parts they support.
function New-AgentContext($Settings, [bool]$Restarted) {
    $teamDir = Split-Path $Settings.manifest
    $runDir = $Settings.directory
    $role = $Settings.role
    $size = if ($Settings.PSObject.Properties['teamSize']) { $Settings.teamSize } else { 5 }
    $brief = "You are the $role in a user-requested $size-agent team. The live roster with exact terminal IDs is at $($Settings.manifest). Shared durable handoff notes belong in $teamDir\HANDOFF.md. Your project is $($Settings.project); follow its AGENTS.md/CLAUDE.md instructions if present. This user authorizes team members to exchange task assignments and reports through hc. Read hc --skill before using it. Initialize your role, then wait for the user's task (orchestrator) or an assignment (specialists). Do not start development just because the team opened."
    if ($Restarted) { $brief += ' This is a restarted session: read HANDOFF.md, inspect the current files and contact the orchestrator before continuing.' }
    $instructions = "# Your team role: $role`r`n`r`n" + (Get-Content -LiteralPath (Join-Path $runDir 'TEAM.md') -Raw) + "`r`n" + (Get-Content -LiteralPath (Join-Path $runDir "$role.md") -Raw)
    $sessionId = if ($Settings.PSObject.Properties['sessionId']) { $Settings.sessionId } else { [guid]::NewGuid().ToString() }
    $options = if ($Settings.PSObject.Properties['options']) { ConvertTo-Hashtable $Settings.options } else { @{} }
    @{
        Role = $role; Project = $Settings.project; TeamDir = $teamDir; RunDir = $runDir; Manifest = $Settings.manifest
        Brief = $brief; Instructions = $instructions; Options = $options; SessionId = $sessionId; Resume = $false
        ReadInstructions = "Read the team operating instructions at $runDir\TEAM.md and your role instructions at $runDir\$role.md."
    }
}
try {
    $deadline = (Get-Date).AddSeconds(120)
    while (-not (Test-Path -LiteralPath (Join-Path $settings.directory 'ready'))) {
        if ((Get-Date) -gt $deadline) { throw 'Team creation did not finish. Inspect launch errors; run stop.bat before retrying.' }
        Start-Sleep -Milliseconds 250
    }
    if ($settings.smokeTest) {
        $esc = [char]27
        [Console]::Write("$esc]7501;state=idle:app=team-smoke$esc\")
        Write-Host "SMOKE READY: $($settings.role) | $($settings.project)"
        while ($true) { $line = Read-Host; if ($line -eq 'exit') { break }; Write-Host "SMOKE RECEIVED: $line" }
        exit 0
    }
    Clear-ProviderEnvironment
    $context = New-AgentContext $settings $false
    $provider = Get-Provider $settings.provider
    while ($true) {
        try {
            $exe = Find-Tool $provider.Tool
            if (-not $exe) { throw "$(Get-ProviderLabel $provider) is not installed. Run setup.bat -Providers $($provider.Name)." }
            $arguments = & $provider.Launch $exe $context
            Invoke-Native $exe @($arguments) -Interactive
        } catch { Write-Host $_ -ForegroundColor Yellow }
        Write-Host 'The agent session ended.'
        $canResume = [bool]$provider['SupportsResume']
        $names = @((Get-Providers).Keys)
        $menu = @()
        if ($canResume) { $menu += 'r = resume this conversation' }
        $menu += "$($names -join ' / ') = fresh conversation from the handoff notes"
        $menu += 'q = close'
        $next = $null
        while ($true) {
            $next = (Read-Host ("Restart this role: " + ($menu -join ', '))).Trim().ToLowerInvariant()
            if ($next -eq 'q' -or ($next -eq 'r' -and $canResume)) { break }
            if ($next -in $names) {
                if (Find-Tool (Get-Provider $next).Tool) { break }
                Write-Host "Run setup.bat -Providers $next to install that client."
            }
        }
        if ($next -eq 'q') { break }
        if ($next -eq 'r') { $context.Resume = $true; continue }
        $provider = Get-Provider $next
        $fresh = New-AgentContext $settings $true
        $fresh.SessionId = [guid]::NewGuid().ToString()
        $fresh.Options = Get-RoleOptions (Get-TeamConfig) $provider.Name $settings.role
        $context = $fresh
    }
} catch {
    Write-Host $_ -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}
