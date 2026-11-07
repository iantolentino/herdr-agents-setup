# Integration test against the installed Herdr, without model calls or credentials.
[CmdletBinding()]
param()
. "$PSScriptRoot/../scripts/Common.ps1"
Update-TeamPath
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw "FAIL: $Message" }; Write-Host "PASS: $Message" }
$repo = Split-Path $PSScriptRoot
$project = Join-Path $repo ('.local/smoke O''Brien [test] ' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $project -Force | Out-Null
$statePath = Join-Path (Get-TeamDirectory $project) 'team.json'
try {
    # Test the actual Windows argument boundary with JSON, spaces and shell metacharacters.
    $payload = '{"path":"C:\\a b\\","quote":"say \"hello\"","literal":"$() & |"}'
    $echo = Join-Path $project 'argv.js'
    [IO.File]::WriteAllText($echo, 'process.stdout.write(process.argv[2]);')
    $roundtrip = Invoke-Native (Get-Command node.exe).Source @($echo,$payload)
    Assert ($roundtrip -ceq $payload) 'Native argument escaping preserves exact JSON and metacharacters'
    & "$repo/scripts/Start-Team.ps1" -Project $project -Profile mixed -SmokeTest
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    Assert ($state.roles.Count -eq 5) 'Five roles are recorded'
    Assert (($state.roles | Where-Object role -eq orchestrator).provider -eq 'claude') 'Mixed profile uses Claude lead'
    Assert (($state.roles | Where-Object role -eq coder).provider -eq 'codex') 'Mixed profile uses Codex coder'
    $view = Invoke-Native (Find-Tool 'herdr-app') @('ls') | ConvertFrom-Json
    $space = $view.spaces | Where-Object id -eq $state.space
    Assert ($space.tabs.Count -eq 5) 'Five visible tabs in the intended Herdr space'
    foreach ($role in $state.roles) {
        # hc wait --output matches future output, so inspect startup with a bounded retry.
        $screen = ''
        for ($i=0; $i -lt 30; $i++) {
            $screen = Invoke-Native (Find-Tool 'hc') @('read',$role.terminal,'--lines','0')
            if ($screen -match "SMOKE READY: $($role.role)") { break }
            Start-Sleep -Milliseconds 200
        }
        Assert ($screen -match "SMOKE READY: $($role.role)") "$($role.role) wrapper started in a path with spaces, apostrophe and brackets"
    }
    $target = $state.roles[1].terminal
    $null = Invoke-Native (Find-Tool 'hc') @('send',$target,'hello-team')
    $screen = Invoke-Native (Find-Tool 'hc') @('read',$target,'--lines','0')
    Assert ($screen -match 'SMOKE RECEIVED: hello-team') 'hc delivers a task to a specialist'
    & "$repo/scripts/Start-Team.ps1" -Project $project -Profile mixed -SmokeTest
    $again = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    Assert ($again.runId -eq $state.runId) 'Relaunch reuses the same team'
    $rejected = $false
    try { & "$repo/scripts/Start-Team.ps1" -Project $project -Profile claude -SmokeTest } catch { $rejected = $true }
    Assert $rejected 'Provider change refuses to duplicate a live team'
    $state.runId = 'not-the-owner'
    Save-Json $statePath $state
    $rejected = $false
    try { & "$repo/scripts/Stop-Team.ps1" -Project $project } catch { $rejected = $true }
    $state.runId = $again.runId
    Save-Json $statePath $state
    Assert $rejected 'Stop refuses terminals with a different ownership label'
    $null = Invoke-Native (Find-Tool 'hc') @('kill',$state.roles[4].terminal)
    $rejected = $false
    try { & "$repo/scripts/Start-Team.ps1" -Project $project -Profile mixed -SmokeTest } catch { $rejected = $true }
    Assert $rejected 'Partial teams are detected instead of duplicated'
} finally {
    if (Test-Path -LiteralPath $statePath) { & "$repo/scripts/Stop-Team.ps1" -Project $project }
}
$live = (Invoke-Native (Find-Tool 'hc') @('ls','--json') | ConvertFrom-Json).terminals
Assert (@($live | Where-Object { $_.address -in @($state.roles.terminal) }).Count -eq 0) 'Stop ends only this test team'
Write-Host 'Smoke integration passed. Test files are retained under .local for inspection.'
