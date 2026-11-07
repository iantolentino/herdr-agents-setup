param([Parameter(Mandatory=$true)][string]$Config)
. "$PSScriptRoot/Common.ps1"
Update-TeamPath
$settings = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
Set-Location -LiteralPath $settings.project
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
    $prompt = "You are the $($settings.role) in a user-requested five-agent team. Read the team operating instructions at $($settings.directory)/TEAM.md and your role instructions at $($settings.directory)/$($settings.role).md. The live roster is at $($settings.manifest). Shared durable handoff notes belong in $(Split-Path $settings.manifest)/HANDOFF.md. Your project is $($settings.project). Read project AGENTS.md and CLAUDE.md instructions too. This user authorizes team members to exchange task assignments and reports through hc. Read hc --skill before using it. Initialize your role, then wait for the user's task (orchestrator) or an assignment (specialists). Do not start development just because the team opened."
    $provider = $settings.provider
    while ($true) {
        try {
            if ($provider -eq 'codex') {
                Invoke-Native (Find-Tool 'codex') @('--no-daemon','-c','forced_login_method="chatgpt"','-c','model_provider="openai"','--sandbox','workspace-write','--ask-for-approval','on-request','--add-dir',(Split-Path $settings.manifest),$prompt) -Interactive
            } else {
                Invoke-Native (Find-Tool 'claude') @('--add-dir',(Split-Path $settings.manifest),'--', $prompt) -Interactive
            }
        } catch { Write-Host $_ -ForegroundColor Yellow }
        Write-Host 'The agent session ended. Switching starts a fresh conversation using shared handoff notes.'
        $next = Read-Host 'Enter codex or claude to restart this role, or q to close'
        if ($next -eq 'q') { break }
        if ($next -notin @('codex','claude')) { continue }
        if (-not (Find-Tool $next)) { Write-Host 'Run setup.bat to install that client.'; continue }
        $provider = $next
        $prompt += ' This is a restarted session: read HANDOFF.md, inspect the current files and contact the orchestrator before continuing.'
    }
} catch {
    Write-Host $_ -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}
