# Offline checks for configuration, providers and argument building.
# Needs only Windows PowerShell and Node.js: no Herdr, no login, no AI calls.
[CmdletBinding()]
param()
. "$PSScriptRoot/../scripts/Common.ps1"
Update-TeamPath
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw "FAIL: $Message" }; Write-Host "PASS: $Message" }
$config = Get-TeamConfig
$providers = Get-Providers
Assert ($providers.Contains('claude') -and $providers.Contains('codex')) 'Claude and Codex providers load'
Assert ($config.DefaultProfile -eq 'claude') 'Claude is the default profile'
foreach ($name in Get-ProfileNames $config) {
    $roster = @(Resolve-TeamProfile $config $name)
    Assert ($roster[0].role -eq 'orchestrator' -and $roster.Count -ge 1) "Profile '$name' resolves with the orchestrator first ($($roster.Count) roles)"
}
$mixed = @(Resolve-TeamProfile $config 'mixed')
Assert ((($mixed | Where-Object role -eq orchestrator).provider -eq 'claude') -and (($mixed | Where-Object role -eq coder).provider -eq 'codex')) 'Mixed profile maps Claude lead and Codex coder'
Assert (@(Resolve-TeamProfile $config 'claude-lite').Count -eq 3) 'claude-lite uses three roles'
$rejected = $false; try { $null = Resolve-TeamProfile $config 'nope' } catch { $rejected = $true }
Assert $rejected 'Unknown profiles are rejected'
Assert ((Get-RoleOptions $config 'claude' 'coder').Model -eq 'sonnet') 'Claude wildcard role options apply'
Assert ((Get-RoleOptions $config 'claude' 'deployer').Model -eq 'haiku') 'Claude per-role options override the wildcard'

$context = @{
    Role = 'coder'; Project = 'C:\p'; TeamDir = 'C:\t'; RunDir = 'C:\t\r'; Manifest = 'C:\t\team.json'
    Brief = 'brief text'; Instructions = "line one`r`nsay ""hi"" \"; Options = @{ Model = 'sonnet'; DisallowedTools = @('WebSearch') }
    SessionId = [guid]::NewGuid().ToString(); Resume = $false; ReadInstructions = 'read files'
}
$claude = Get-Provider 'claude'
$a = @(& $claude.Launch 'claude.exe' $context)
Assert (($a -join ' ') -match '--model sonnet') 'Claude launch passes the role model'
Assert ($a[[array]::IndexOf($a, '--session-id') + 1] -eq $context.SessionId) 'Claude launch pins a session id'
Assert ($a[[array]::IndexOf($a, '--append-system-prompt') + 1] -ceq $context.Instructions) 'Claude role rules go into the system prompt'
Assert ($a -contains 'Bash(hc send:*)' -and $a -notcontains 'Bash(hc kill:*)') 'Claude pre-approves only coordination hc commands'
Assert ($a[-2] -eq '--' -and $a[-1] -eq 'brief text') 'Claude brief is passed after --'
Assert ($a -contains '--disallowedTools' -and $a -contains 'WebSearch') 'Claude disallowed tools pass through'
$context.Resume = $true
$r = @(& $claude.Launch 'claude.exe' $context)
Assert ($r[[array]::IndexOf($r, '--resume') + 1] -eq $context.SessionId -and $r -notcontains '--session-id' -and $r -notcontains 'brief text') 'Claude restart resumes the same conversation'
$context.Resume = $false
$c = @(& (Get-Provider 'codex').Launch 'codex.exe' $context)
Assert ($c -contains '--no-daemon' -and $c[-1] -eq 'read files brief text') 'Codex launch keeps --no-daemon and file-based instructions'

# Exercise the real Windows argument boundary, including the npm .cmd shim path.
$node = (Get-Command node.exe -ErrorAction Stop).Source
$temp = Join-Path ([IO.Path]::GetTempPath()) ('herdr-unit-' + [guid]::NewGuid().ToString('N'))
try {
    $pkg = Join-Path $temp 'node_modules/@anthropic-ai/claude-code'
    New-Item -ItemType Directory -Force -Path $pkg | Out-Null
    [IO.File]::WriteAllText((Join-Path $pkg 'cli.js'), 'process.stdout.write(JSON.stringify(process.argv.slice(2)));')
    [IO.File]::WriteAllText((Join-Path $temp 'claude.cmd'), '@echo off')
    $echoed = Invoke-Native (Join-Path $temp 'claude.cmd') $a | ConvertFrom-Json
    Assert (($echoed -join "`n") -ceq ($a -join "`n")) 'npm claude.cmd shim runs its entrypoint with exact multi-line arguments'
} finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host 'Unit checks passed.'
