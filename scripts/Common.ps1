Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-PowerShell { Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe' }
function Update-TeamPath {
    $extra = @("$env:LOCALAPPDATA/Programs/herdr-app", "$env:LOCALAPPDATA/Programs/herdr-core", "$env:LOCALAPPDATA/Programs/OpenAI/Codex/bin", "$env:USERPROFILE/.local/bin", "$env:APPDATA/npm", "$env:ProgramFiles/nodejs", "$env:ProgramFiles/Git/cmd")
    $env:Path = ($extra + @($env:Path, [Environment]::GetEnvironmentVariable('Path','Machine'), [Environment]::GetEnvironmentVariable('Path','User'))) -join ';'
}
function Find-Tool([string]$Name) {
    $cmd = Get-Command "$Name.exe" -ErrorAction SilentlyContinue
    if (-not $cmd) { $cmd = Get-Command "$Name.cmd" -ErrorAction SilentlyContinue }
    if ($cmd) { return $cmd.Source }
    return $null
}
# CommandLineToArgvW escaping: preserve JSON quotes and trailing backslashes on PS 5.1.
function ConvertTo-NativeArgument([AllowEmptyString()][string]$Value) {
    '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}
function Invoke-Native {
    param([string]$File, [string[]]$Arguments = @(), [switch]$Interactive, [switch]$IncludeStderr, [int]$TimeoutSeconds = 30)
    if ($File -like '*.cmd') {
        if ([IO.Path]::GetFileName($File) -ne 'codex.cmd') { throw "Unsupported batch executable: $File" }
        $entry = Join-Path (Split-Path $File) 'node_modules/@openai/codex/bin/codex.js'
        if (-not (Test-Path -LiteralPath $entry)) { throw "Codex entrypoint missing: $entry" }
        $Arguments = @($entry) + $Arguments
        $File = (Get-Command node.exe -ErrorAction Stop).Source
    }
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $File
    $info.Arguments = (@($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' ')
    $info.UseShellExecute = $false
    $info.CreateNoWindow = -not $Interactive
    $info.WorkingDirectory = (Get-Location).Path
    $info.RedirectStandardOutput = -not $Interactive
    $info.RedirectStandardError = -not $Interactive
    if (-not $Interactive) {
        $info.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
        $info.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        if ($Interactive) { $process.WaitForExit() }
        else {
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
                $process.Kill()
                throw "$File timed out; inspect Herdr before retrying a creation command."
            }
            $output = $stdout.Result
            $errors = $stderr.Result
        }
        if ($process.ExitCode -ne 0) {
            if ($Interactive) { throw "$File exited with code $($process.ExitCode)." }
            throw "$File exited with code $($process.ExitCode): $errors $output"
        }
        if (-not $Interactive) { if ($IncludeStderr) { return $output + $errors }; return $output }
    } finally { $process.Dispose() }
}
function Invoke-App([string]$Command, [hashtable]$Data) {
    $json = ConvertTo-Json -InputObject $Data -Depth 12 -Compress
    $result = Invoke-Native (Find-Tool 'herdr-app') @('do',$Command,$json)
    $result | ConvertFrom-Json
}
function Clear-ProviderEnvironment {
    foreach ($name in @('OPENAI_API_KEY','OPENAI_BASE_URL','ANTHROPIC_API_KEY','ANTHROPIC_AUTH_TOKEN','ANTHROPIC_BASE_URL','CLAUDE_CODE_OAUTH_TOKEN','CLAUDE_CODE_USE_BEDROCK','CLAUDE_CODE_USE_VERTEX','CLAUDE_CODE_USE_FOUNDRY')) {
        [Environment]::SetEnvironmentVariable($name, $null, 'Process')
    }
}
function Get-TeamDirectory([string]$Project) {
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $id = -join ($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($Project.TrimEnd('\','/').ToLowerInvariant())) | ForEach-Object { $_.ToString('x2') }) }
    finally { $hash.Dispose() }
    Join-Path $env:LOCALAPPDATA "HerdrAgentTeams/$($id.Substring(0,16))"
}
function Save-Json([string]$Path, $Value) {
    $temp = "$Path.tmp"
    [IO.File]::WriteAllText($temp, (ConvertTo-Json -InputObject $Value -Depth 15), (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temp -Destination $Path -Force
}
function Resolve-Project([string]$Project) {
    if (-not $Project) { $Project = Read-Host 'Full path of project folder (create the folder first)' }
    $item = Get-Item -LiteralPath $Project -ErrorAction Stop
    if (-not $item.PSIsContainer) { throw 'Project must be a folder.' }
    $item.FullName
}
