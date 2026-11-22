# Team configuration. To customize without Git conflicts, copy this file to
# config/team.local.psd1 (ignored by Git); the local copy replaces this one.
@{
    # Used when launch.bat gets no -Profile and has no remembered choice.
    DefaultProfile = 'claude'

    # Clients setup.bat installs and offers to log into when -Providers is omitted.
    DefaultProviders = @('claude')

    # Full roster in tab order. The first role must be the orchestrator.
    # Each role needs a matching roles/<role>.md file.
    Roles = @('orchestrator', 'coder', 'reviewer', 'tester', 'deployer')

    # Order of the launch menu.
    ProfileOrder = @('claude', 'claude-lite', 'mixed', 'codex')

    # Default = provider for every role; Assign = per-role overrides;
    # Roles = a smaller roster for this profile (must start with orchestrator).
    Profiles = @{
        'claude'      = @{ Description = 'Claude Code for all five roles'; Default = 'claude' }
        'claude-lite' = @{ Description = 'Claude Code, three roles (orchestrator, coder, reviewer) - stretches Pro usage limits'; Default = 'claude'; Roles = @('orchestrator', 'coder', 'reviewer') }
        'mixed'       = @{ Description = 'Claude orchestrator + reviewer, Codex for the rest'; Default = 'codex'; Assign = @{ orchestrator = 'claude'; reviewer = 'claude' } }
        'codex'       = @{ Description = 'Codex for all five roles'; Default = 'codex' }
    }

    # Per-provider, per-role launch options. '*' applies to every role; a role
    # entry overrides it. Options a provider does not use are ignored.
    #
    # Claude options:
    #   Model           alias or full name: 'sonnet', 'opus', 'haiku', ... Leave
    #                   out to use your account default. Pro plans have tighter
    #                   limits; keep heavy models for the roles that need them.
    #   Effort          'low' | 'medium' | 'high' | 'xhigh' | 'max' (optional)
    #   PermissionMode  e.g. 'acceptEdits' (optional; default asks as usual)
    #   AllowedTools    extra permission rules granted up front
    #   DisallowedTools tools to block, e.g. @('WebSearch')
    #   AllowTeamMessaging  $false to keep prompting for hc send/get/wait/read/ls
    RoleOptions = @{
        claude = @{
            '*'      = @{ Model = 'sonnet' }
            deployer = @{ Model = 'haiku' }
        }
        codex = @{}
    }
}
