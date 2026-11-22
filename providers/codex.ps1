# Codex CLI provider. Uses ChatGPT subscription login, never API billing.
# See providers/README.md for the provider contract.
@{
    Name           = 'codex'
    DisplayName    = 'Codex CLI'
    Tool           = 'codex'
    SupportsResume = $false
    ShimTargets    = @('node_modules/@openai/codex/bin/codex.js')
    ClearEnvironment = @('OPENAI_API_KEY', 'OPENAI_BASE_URL')
    LoginHint      = 'Sign in using your ChatGPT account (subscription access).'
    LoginCommand   = 'codex login'

    Install = {
        Install-NodeJs
        & npm.cmd install -g '@openai/codex'
        if ($LASTEXITCODE -ne 0) { throw 'Codex installation failed.' }
        Update-TeamPath
    }

    Login = { param($Exe) Invoke-Native $Exe @('login') -Interactive }

    TestReady = {
        param($Exe)
        $auth = Invoke-Native $Exe @('login', 'status') -IncludeStderr
        if ($auth -notmatch 'ChatGPT') { throw 'Run codex login and sign in with ChatGPT before launching.' }
        $help = Invoke-Native $Exe @('--help')
        if ($help -notmatch '--no-daemon') { throw 'Update Codex first: this Herdr setup requires --no-daemon.' }
        'Codex: signed in with ChatGPT.'
    }

    Launch = {
        param($Exe, $Context)
        $a = @('--no-daemon', '-c', 'forced_login_method="chatgpt"', '-c', 'model_provider="openai"', '--sandbox', 'workspace-write', '--ask-for-approval', 'on-request', '--add-dir', $Context.TeamDir)
        if ($Context.Options['Model']) { $a += @('-m', [string]$Context.Options['Model']) }
        $a += ($Context.ReadInstructions + ' ' + $Context.Brief)
        $a
    }
}
