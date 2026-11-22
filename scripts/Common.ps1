Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:TeamRoot = Split-Path $PSScriptRoot
$script:TeamProviders = $null
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
        # cmd.exe would re-parse arguments; run the shim's real target instead.
        $tool = [IO.Path]::GetFileNameWithoutExtension($File)
        $targets = (Get-Providers).Values | Where-Object { $_.Tool -eq $tool -and $_['ShimTargets'] } | ForEach-Object { $_['ShimTargets'] }
        $entry = @($targets | ForEach-Object { Join-Path (Split-Path $File) $_ } | Where-Object { Test-Path -LiteralPath $_ }) | Select-Object -First 1
        if (-not $entry) { throw "Unsupported batch executable (no known entrypoint): $File" }
        if ($entry -match '\.(c|m)?js$') {
            $Arguments = @($entry) + $Arguments
            $File = (Get-Command node.exe -ErrorAction Stop).Source
        } else { $File = $entry }
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
    foreach ($provider in (Get-Providers).Values) {
        foreach ($name in @($provider['ClearEnvironment'])) { if ($name) { [Environment]::SetEnvironmentVariable($name, $null, 'Process') } }
    }
}
# --- Providers and configuration -------------------------------------------
function Get-Providers {
    if ($null -eq $script:TeamProviders) {
        $found = [ordered]@{}
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $script:TeamRoot 'providers') -Filter '*.ps1' | Sort-Object Name) {
            $p = & $file.FullName
            if ($p -isnot [hashtable]) { throw "Provider $($file.Name) must return a hashtable." }
            foreach ($key in @('Name','Tool','Launch','TestReady')) { if (-not $p[$key]) { throw "Provider $($file.Name) is missing '$key'." } }
            if ($found.Contains($p.Name)) { throw "Duplicate provider name '$($p.Name)'." }
            $found[$p.Name] = $p
        }
        $script:TeamProviders = $found
    }
    $script:TeamProviders
}
function Get-Provider([string]$Name) {
    $all = Get-Providers
    if (-not $Name -or -not $all.Contains($Name)) { throw "Unknown provider '$Name'. Known: $(@($all.Keys) -join ', ')." }
    $all[$Name]
}
function Get-ProviderLabel($Provider) { if ($Provider['DisplayName']) { $Provider.DisplayName } else { $Provider.Name } }
function Get-TeamConfig {
    $local = Join-Path $script:TeamRoot 'config/team.local.psd1'
    $path = if (Test-Path -LiteralPath $local) { $local } else { Join-Path $script:TeamRoot 'config/team.psd1' }
    Import-PowerShellDataFile -LiteralPath $path
}
function Get-ProfileNames([hashtable]$Config) {
    $names = @($Config['ProfileOrder'] | Where-Object { $_ -and $Config.Profiles.Contains($_) })
    $names + @($Config.Profiles.Keys | Sort-Object | Where-Object { $_ -notin $names })
}
# Returns ordered role/provider pairs for a profile, validated against providers and role files.
function Resolve-TeamProfile([hashtable]$Config, [string]$Profile) {
    if (-not $Profile -or -not $Config.Profiles.Contains($Profile)) { throw "Unknown profile '$Profile'. Choose: $((Get-ProfileNames $Config) -join ', ')." }
    $def = $Config.Profiles[$Profile]
    $roles = if ($def['Roles']) { @($def.Roles) } else { @($Config.Roles) }
    if ($roles.Count -lt 1 -or $roles[0] -ne 'orchestrator') { throw "Profile '$Profile' must list orchestrator first." }
    foreach ($role in $roles) {
        if (-not (Test-Path -LiteralPath (Join-Path $script:TeamRoot "roles/$role.md"))) { throw "Profile '$Profile' uses role '$role' but roles/$role.md is missing." }
    }
    foreach ($role in $roles) {
        $provider = $def.Default
        if ($def['Assign'] -and $def.Assign[$role]) { $provider = $def.Assign[$role] }
        $null = Get-Provider $provider
        [pscustomobject]@{ role = $role; provider = $provider }
    }
}
function Get-RoleOptions([hashtable]$Config, [string]$Provider, [string]$Role) {
    $merged = @{}
    $byProvider = if ($Config['RoleOptions']) { $Config.RoleOptions[$Provider] } else { $null }
    if ($byProvider) {
        foreach ($key in @('*', $Role)) {
            if ($byProvider[$key]) { foreach ($entry in $byProvider[$key].GetEnumerator()) { $merged[$entry.Key] = $entry.Value } }
        }
    }
    $merged
}
function ConvertTo-Hashtable($Object) {
    $table = @{}
    if ($null -ne $Object) { foreach ($property in $Object.PSObject.Properties) { $table[$property.Name] = $property.Value } }
    $table
}
# --- Installation helpers used by provider Install blocks --------------------
function Install-OfficialScript([string]$Uri) {
    $file = Join-Path ([IO.Path]::GetTempPath()) ('herdr-team-' + [guid]::NewGuid() + '.ps1')
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $file
        Invoke-Native (Get-PowerShell) @('-NoProfile','-ExecutionPolicy','Bypass','-File',$file) -Interactive
    } finally { if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force } }
    Update-TeamPath
}
function Install-WingetPackage([string]$Id, [string]$ManualHint) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { throw $ManualHint }
    Invoke-Native 'winget.exe' @('install','--id',$Id,'--exact','--accept-source-agreements','--accept-package-agreements') -Interactive
    Update-TeamPath
}
function Install-NodeJs {
    if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { Install-WingetPackage 'OpenJS.NodeJS.LTS' 'Install Node.js LTS from https://nodejs.org and rerun setup.bat.' }
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
