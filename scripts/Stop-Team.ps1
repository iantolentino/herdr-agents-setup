param([string]$Project)
. "$PSScriptRoot/Common.ps1"
Update-TeamPath
$Project = Resolve-Project $Project
$path = Join-Path (Get-TeamDirectory $Project) 'team.json'
if (-not (Test-Path -LiteralPath $path)) { Write-Host 'No saved team for this project.'; return }
$state = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
foreach ($role in $state.roles) {
    try { $terminal = Invoke-Native (Find-Tool 'hc') @('get',$role.terminal,'--json') | ConvertFrom-Json }
    catch { if ($_ -match 'not_found') { Write-Host "$($role.role) is already unavailable."; continue }; throw }
    $label = $terminal.labels.PSObject.Properties['team.run']
    if (-not $label -or $label.Value -ne $state.runId) { throw "Terminal ownership mismatch: $($role.terminal). Refusing to stop it." }
    if ($terminal.state -eq 'finished') { continue }
    $null = Invoke-Native (Find-Tool 'hc') @('kill',$role.terminal)
}
$state.ready = $false
Save-Json $path $state
$spaces = (Invoke-Native (Find-Tool 'herdr-app') @('ls') | ConvertFrom-Json).spaces
$space = @($spaces | Where-Object { $_.id -eq $state.space })
if ($space.Count -eq 1) {
    $unexpected = @($space[0].tabs | ForEach-Object { $_.terminals } | Where-Object { $_.terminal -notin @($state.roles | ForEach-Object { $_.terminal }) })
    if ($unexpected.Count -eq 0) { $null = Invoke-App 'space.close' @{id=$state.space;confirmed=$true} }
}
Write-Host 'Stopped this team. Handoff notes and project files are preserved. You can launch with another provider now.'
