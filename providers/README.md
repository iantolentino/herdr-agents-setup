# Adding an AI coding client

Each `*.ps1` file here is one provider. Drop in a new file and it appears in
`setup.bat -Providers`, profile definitions, and the per-tab restart menu. No
other script needs editing. Then add a profile for it in `config/team.psd1`.

The file must evaluate to a hashtable:

| Key | Required | Meaning |
| --- | --- | --- |
| `Name` | yes | Provider id used in profiles and menus (lowercase). |
| `Tool` | yes | Executable name without extension, found on PATH. |
| `Launch` | yes | `{ param($Exe, $Context) ; $args }` outputs the interactive CLI arguments. |
| `TestReady` | yes | `{ param($Exe) }` throws if not logged in / too old; may return a status line. |
| `Install` | no | Installs the client. Helpers: `Install-OfficialScript <url>`, `Install-NodeJs`, `Update-TeamPath`. |
| `Login` | no | `{ param($Exe) }` runs the client's interactive subscription login. |
| `DisplayName`, `LoginHint`, `LoginCommand` | no | Text shown in setup and errors. |
| `ShimTargets` | no | For npm `.cmd` shims: paths relative to the shim's folder to run instead (`.js` runs via node). |
| `ClearEnvironment` | no | Env vars removed from the agent process so API keys never override subscription login. |
| `SupportsResume` | no | `$true` if `Launch` honors `$Context.Resume` (continue the same conversation on restart). |

`$Context` fields passed to `Launch`:

- `Role`, `Project`, `TeamDir` (state folder; grant tool access to it), `RunDir`, `Manifest`
- `Brief`: the startup message (roster/handoff paths, wait for a task)
- `Instructions`: full TEAM.md + role text, for clients that accept a system prompt
- `ReadInstructions`: a sentence pointing at the instruction files, for clients that don't
- `Options`: merged hashtable from `RoleOptions.<provider>` in the config
- `SessionId`: a UUID per role conversation; `Resume`: `$true` when the user asked to continue it

Rules: never pass flags that bypass all permission prompts, and never read or
copy credentials. Run `tests\Unit.ps1` after adding a provider.
