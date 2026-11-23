# Herdr subscription agent team for Windows

Double-click a BAT file to open **Herdr with an agent team in tabs**. Give your
task to the orchestrator; it delegates coding, review, testing and release 
preparation. Uses official coding clients with **subscription login**: Claude
Code by default, Codex optional. No API keys, router or key rotation needed.
AI clients are plug-ins; see [Adding another AI](#adding-another-ai).

## First setup

1. Clone this repository or download its ZIP and extract it.
2. Double-click **setup.bat** and press Enter to set up **Claude Code** (the
   default). It installs missing Git, Herdr/Core and Claude Code; Windows may
   request elevation. To also use Codex: `setup.bat -Providers claude,codex`.
3. Log in with your **Claude subscription account (Pro/Max)**, not Console/API
   billing. You may skip and run `claude auth login` later.
4. Create a folder for your program (or use an existing project). Double-click
   **launch.bat**, enter its full folder path, and pick a profile (default
   **claude**; see below).
5. Complete first-use trust/permission prompts in the tabs. Give your request to
   **orchestrator**. Subsequent double-clicks remember the last project/profile
   and focus an existing team instead of duplicating it.

Requirements: Windows x64, Windows PowerShell 5.1+, internet, and an active plan
that includes the selected coding client. Herdr App and Herdr TUI are different
products; this repository targets **Herdr App (`herdr-app`) and Core (`hc`)**.

## The team

| Tab | Responsibility | Default Claude model |
| --- | --- | --- |
| orchestrator | Plans, assigns work, integrates results, keeps handoff notes | sonnet |
| coder | Implements scoped changes; default sole source writer | sonnet |
| reviewer | Independent code review and concrete findings | sonnet |
| tester | Checks acceptance criteria, tests and product flows | sonnet |
| deployer | Build/release preparation; deploys when you authorize the target | haiku |

| Profile | Roles | Clients |
| --- | --- | --- |
| `claude` (default) | all five | Claude Code |
| `claude-lite` | orchestrator, coder, reviewer (reviewer also tests) | Claude Code |
| `mixed` | all five | Claude orchestrator + reviewer, Codex for the rest |
| `codex` | all five | Codex |

The roster is a deliberate limit: no recursive agent or subagent spawning. The role instructions
coordinate a shared working folder so workers do not compete to edit the same
files. Review/testing happens after the coder pauses changes. Agent behavior is
instruction-driven, not a deterministic workflow engine or a guarantee of correctness.
The clients retain their normal permission prompts; login, trust, approvals and
quota errors can still require your attention. No bypass-all-permissions flags.

Example task for the orchestrator:

> Build a task tracker in this project. Plan first, assign implementation to the
> coder, have the reviewer and tester verify it, fix their findings, then have
> the deployer prepare deployment instructions. Keep HANDOFF.md current.

## Launch another project or choose a provider

From CMD in this repository:

```bat
launch.bat -Project "C:\Projects\My App" -Profile claude
launch.bat -Project "C:\Projects\My App" -Profile claude-lite
launch.bat -Project "C:\Projects\My App" -Profile mixed
```

PowerShell equivalent:

```powershell
.\scripts\Start-Team.ps1 -Project 'C:\Projects\My App' -Profile claude
```

Before changing the whole team's provider, ask the orchestrator to update its
handoff notes and finish/stop active work, then:

```bat
stop.bat -Project "C:\Projects\My App"
launch.bat -Project "C:\Projects\My App" -Profile claude
```

`stop.bat` ends this team's processes (including unfinished work). It preserves
project files and notes. It checks terminal ownership and never stops the entire
Herdr server. Quitting Herdr's window alone does **not** stop the agents.

For one role, exit its coding client normally. The wrapper then offers `r` to
**resume the same Claude conversation** (each Claude tab has its own pinned
session ID, so context survives a crash or `/exit`), a provider name (`claude`,
`codex`, ...) to start a fresh conversation from the shared handoff notes, or
`q` to close. This is **manual switching**, not automatic quota
detection, conversation transfer, or extra subscription allowance. The roster's
provider fields record the launch profile; per-tab switches keep the same terminal
ID but do not rewrite that profile.

## Claude Pro tips

All tabs share one Claude subscription's usage limits. Pro has the tightest
limits, so the Claude setup is tuned to stretch them:

- **Role rules go into Claude's system prompt** (`--append-system-prompt`), so
  agents don't spend turns reading instruction files at startup.
- **Team messaging is pre-approved**: `hc send/get/wait/read/ls` and `hc --skill`
  run without a prompt each time. Everything else (edits, other commands,
  `hc kill`) still asks as usual. Disable with `AllowTeamMessaging = $false`.
- **Models per role**: `sonnet` for the thinking roles, `haiku` for the deployer.
  If your plan includes it and you have headroom, set the orchestrator or
  reviewer to `opus`.
- **`claude-lite`** runs three tabs instead of five for long sessions on Pro.
- The team rules include a *usage economy* section: block on `hc wait` instead
  of polling, short messages, no needless rereads or reruns, stop on limit messages.
- Tabs are named after their role (`--name`), so `/resume` lists them clearly.

## Configuration

Settings live in [config/team.psd1](config/team.psd1): default profile, profiles,
roster, and per-role options (`Model`, `Effort`, `PermissionMode`, `AllowedTools`,
`DisallowedTools`). Copy it to `config/team.local.psd1` (Git-ignored) to customize
without merge conflicts; the local file replaces the default one. Example:

```powershell
RoleOptions = @{
    claude = @{
        '*'          = @{ Model = 'sonnet' }
        orchestrator = @{ Model = 'opus'; Effort = 'high' }
        deployer     = @{ Model = 'haiku' }
    }
}
```

## Adding another AI

Each client is one file in [providers/](providers/README.md): `claude.ps1` and
`codex.ps1`. To add another CLI (Gemini CLI, OpenCode, Aider, ...), copy one,
change its install, login, auth-check and launch-argument blocks, then add a
profile that uses it in the config. setup.bat, launch.bat and the restart menu
pick it up automatically. The contract is in `providers/README.md`.

## Subscriptions and login

- Claude Code uses an eligible active Claude subscription via `claude auth
  login`. Launch refuses API-key/Console auth so usage never bills an API account.
- Codex (optional) can use your ChatGPT subscription via `codex login`. This
  launcher requires ChatGPT login and starts Codex with `--no-daemon`.
- All tabs share your account's applicable usage limits. They do not grant
  separate quotas. Login success does not prove quota remains.
- Setup does not collect or copy credentials. Official clients store their own
  credentials. Launch wrappers remove common API-key/provider environment
  overrides **only from their process**; existing user/system settings remain.
  Custom client settings can still affect auth and behavior: check `/status` in
  Claude if you previously configured API billing or a custom gateway.

Sources: [OpenAI authentication](https://learn.chatgpt.com/docs/auth),
[Claude subscription access](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-max-or-ultra-plan),
[Herdr guide](https://herdr.dev/guide/).

## State and recovery

Local state lives at `%LOCALAPPDATA%\HerdrAgentTeams\<project-hash>\`:

- `team.json`: exact space/tab/terminal IDs and initial provider mapping.
- `HANDOFF.md`: durable task context written by the orchestrator.
- A run-specific folder holds role configs, operating instructions and reports.
- `launcher.json` in the parent folder remembers the last successful selection.

No project instruction files are overwritten. A per-project file lock prevents
double-click races. Partial creation is retained for inspection, not silently
treated as success. Use `stop.bat` before retrying a partial team. After a reboot,
Herdr may restore shell panes, not active AI conversations; stop the old team and
launch fresh, then ask the orchestrator to continue from HANDOFF.md.

## Verification and troubleshooting

```powershell
# Offline: config, profiles, provider arguments and quoting. No Herdr or login.
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Unit.ps1

# Checks actual tab creation, task delivery, argument quoting, reuse and cleanup.
# Opens its own temporary Herdr space. No AI calls or login required.
powershell -NoProfile -ExecutionPolicy Bypass -File tests\Smoke.ps1

# Install/check clients without opening account login:
.\setup.bat -SkipLogin
```

- **Not logged in / expired access:** log into the appropriate client or choose
  the other provider. There is no automatic fallback to paid API calls.
- **Trust or permission screen:** resolve it in that tab. The launcher never
  types approval answers automatically. An idle status isn't proof of readiness.
- **Missing executable:** run setup.bat again (add `-Providers <name>` for a
  client you skipped). Existing tools are preserved;
  update old clients using their official updater if needed.
- **`pwsh.exe` not found:** Herdr was likely started by an app with a temporary
  PowerShell runtime PATH. Close the Herdr window (agents keep running) and run
  launch.bat again. The launcher starts Herdr using the persistent Windows PATH.
- **Permission blocks `hc`:** approve the specific coordination command in the
  client's normal permission UI. Sandbox settings aren't silently disabled.
- **Repo renamed:** clone the new GitHub URL. Scripts use their own directory,
  so their operation does not depend on the repository's GitHub name.

The previous API-based Python scripts remain recoverable in Git history.
