# Herdr subscription agent team for Windows 

Double-click a BAT file to open **Herdr with five agent tabs**. Give your task to
the orchestrator; it delegates coding, review, testing and release preparation.
Uses the official **Codex CLI and Claude Code** with account login. No OpenCode,
Python API router, or API-key rotation is needed.

## First setup  

1. Clone this repository or download its ZIP and extract it.
2. Double-click **setup.bat**. It installs missing Herdr/Core, Codex and Claude Code.
   Git and Node.js LTS are installed through winget when needed. Windows or an
   installer may request elevation. Without winget, it tells you what to install.
3. Choose which account(s) to log into. Use **ChatGPT** for Codex and your **Claude
   subscription account**, not API/Console billing, for Claude Code. You may skip
   login and do it later with `codex login` or `claude auth login`.
4. Create a folder for your program (or use an existing project). Double-click
   **launch.bat**, enter its full folder path, and choose Codex, Claude or mixed.
5. Complete first-use trust/permission prompts in the tabs. Give your request to
   **orchestrator**. Subsequent double-clicks remember the last project/profile
   and focus an existing team instead of duplicating it.

Requirements: Windows x64, Windows PowerShell 5.1+, internet, and an active plan
that includes the selected coding client. Herdr App and Herdr TUI are different
products; this repository targets **Herdr App (`herdr-app`) and Core (`hc`)**.

## The team

| Tab | Responsibility | Mixed profile |
| --- | --- | --- |
| orchestrator | Plans, assigns work, integrates results, keeps handoff notes | Claude |
| coder | Implements scoped changes; default sole source writer | Codex |
| reviewer | Independent code review and concrete findings | Claude |
| tester | Checks acceptance criteria, tests and product flows | Codex |
| deployer | Build/release preparation; deploys when you authorize the target | Codex |

Codex-only and Claude-only profiles use that provider for all five roles.
Five is a deliberate limit: no recursive agent spawning. The role instructions
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
launch.bat -Project "C:\Projects\My App" -Profile codex
launch.bat -Project "C:\Projects\My App" -Profile claude
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

For one role, exit its coding client normally; the wrapper offers `codex`,
`claude`, or `q`. The new provider starts a fresh conversation and reads the
same shared handoff notes. This is **manual switching**, not automatic quota
detection, conversation transfer, or extra subscription allowance. The roster's
provider fields record the launch profile; per-tab switches keep the same terminal
ID but do not rewrite that profile.

## Subscriptions and login

- Codex can use your ChatGPT subscription via `codex login`. This launcher
  requires ChatGPT login and starts Codex with `--no-daemon` for Herdr messaging.
- Claude Code can use an eligible active Claude subscription via `claude auth
  login`. Your Claude subscription is independent of your Codex access, so you
  can select Claude-only after Codex expires, provided Claude access is active.
- Five sessions share your account's applicable usage limits. They do not grant
  five separate quotas. Login success does not prove quota remains.
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
- **Missing executable:** run setup.bat again. Existing tools are preserved;
  update old clients using their official updater if needed.
- **`pwsh.exe` not found:** Herdr was likely started by an app with a temporary
  PowerShell runtime PATH. Close the Herdr window (agents keep running) and run
  launch.bat again. The launcher starts Herdr using the persistent Windows PATH.
- **Permission blocks `hc`:** approve the specific coordination command in the
  client's normal permission UI. Sandbox settings aren't silently disabled.
- **Repo renamed:** clone the new GitHub URL. Scripts use their own directory,
  so their operation does not depend on the repository's GitHub name.

The previous API-based Python scripts remain recoverable in Git history.
