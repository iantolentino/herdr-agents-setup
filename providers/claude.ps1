# Claude Code provider. Uses Claude subscription login (Pro/Max), never API billing.
# See providers/README.md for the provider contract.
@{
    Name           = 'claude'
    DisplayName    = 'Claude Code'
    Tool           = 'claude'
    SupportsResume = $true
    # npm installs a claude.cmd shim; run its real target directly.
    ShimTargets    = @('node_modules/@anthropic-ai/claude-code/bin/claude.exe', 'node_modules/@anthropic-ai/claude-code/cli.js')
    ClearEnvironment = @('ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_BASE_URL', 'CLAUDE_CODE_OAUTH_TOKEN', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY')
    LoginHint      = 'Sign in using your Claude subscription account (Pro/Max), not Console/API billing.'
    LoginCommand   = 'claude auth login'

    Install = { Install-OfficialScript 'https://claude.ai/install.ps1' }

    Login = { param($Exe) Invoke-Native $Exe @('auth', 'login') -Interactive }

    TestReady = {
        param($Exe)
        $auth = Invoke-Native $Exe @('auth', 'status') | ConvertFrom-Json
        if (-not $auth.loggedIn -or $auth.authMethod -ne 'claude.ai') { throw 'Run claude auth login and choose your Claude subscription account first.' }
        $plan = $auth.PSObject.Properties['subscriptionType']
        if ($plan -and $plan.Value) { "Claude Code: signed in with a $($plan.Value) subscription." } else { 'Claude Code: signed in with a Claude subscription.' }
    }

    Launch = {
        param($Exe, $Context)
        $o = $Context.Options
        $a = @('--add-dir', $Context.TeamDir, '--name', $Context.Role)
        if ($o['Model']) { $a += @('--model', [string]$o['Model']) }
        if ($o['Effort']) { $a += @('--effort', [string]$o['Effort']) }
        if ($o['PermissionMode']) { $a += @('--permission-mode', [string]$o['PermissionMode']) }
        # Pre-approve only read/notify coordination commands, not hc kill or anything else.
        $allowed = @()
        if ($o['AllowTeamMessaging'] -ne $false) {
            foreach ($tool in @('Bash', 'PowerShell')) {
                foreach ($verb in @('send', 'get', 'wait', 'read', 'ls')) { $allowed += ('{0}(hc {1}:*)' -f $tool, $verb) }
                $allowed += ('{0}(hc --skill)' -f $tool)
            }
        }
        if ($o['AllowedTools']) { $allowed += @($o['AllowedTools']) }
        if ($allowed.Count) { $a += '--allowedTools'; $a += $allowed }
        if ($o['DisallowedTools']) { $a += '--disallowedTools'; $a += @($o['DisallowedTools']) }
        # Role rules live in the system prompt: better adherence, no startup file reads.
        $a += @('--append-system-prompt', $Context.Instructions)
        if ($Context.Resume) { $a += @('--resume', $Context.SessionId) }
        else { $a += @('--session-id', $Context.SessionId, '--', $Context.Brief) }
        $a
    }
}
