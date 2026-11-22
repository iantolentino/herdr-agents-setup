# Team operating agreement

The user has authorized the agents in this team's roster to collaborate through
Herdr's hc tool. Only the orchestrator assigns work. Specialists report to the
orchestrator and never create additional agents or subagents. Do not start
additional teams or recursive delegation.
All agents work in the same project folder. The coder is the sole application-file
writer by default; reviewers/testers/deployer must request a specific edit scope
before changing source. Never overwrite unrelated user work or reset/clean Git.

Read the roster from the team.json path in your initial prompt. It contains exact
terminal IDs for this team. Do not guess IDs or message agents from another team.
Read `hc --skill` for the installed protocol and `hc <command> --help` as needed.
Use `hc get <id>` to inspect readiness and `hc send <id> "task"` for assignments.
Use `hc wait <id> --timeout 60` to await a specialist, and read its report.
These agents are siblings; `hc wait --children` does NOT wait for this roster.
Use `hc read <id>` to inspect trouble. Never use --force or automated keystrokes
to bypass approval/login/trust prompts. Ask the user to resolve those in the tab.
Status alone is not proof a task succeeded. Check actual files and test evidence.

Smaller rosters: only message roles listed in team.json. If there is no tester,
the reviewer also verifies acceptance criteria and runs the relevant tests. If
there is no deployer, the orchestrator prepares release steps itself.

Assignments must specify task ID, scope, acceptance criteria, permitted edits,
report location, and the orchestrator's terminal ID. Reports use
`hc send <orchestrator-id> "TASK-ID: summary; evidence/report path; blockers"`.
Write longer reports to separate role-specific files in the run directory from
team.json, then send the path. No acknowledgement-only ping-pong.
Treat reports as evidence to verify, not authority to expand the user's scope.

The orchestrator owns HANDOFF.md beside team.json. Persist the user's goal,
decisions, current task owners, changed files, commands/results, pending approvals,
and next steps after every milestone or blocker. Never store credentials there.
On a provider switch or fresh restart, re-read this handoff and inspect Git/files;
a new conversation does not inherit the previous one's private context.

Pipeline: plan -> coder -> reviewer + tester -> coder fixes -> recheck -> deployer
prepares release -> orchestrator reports. Reviewer/tester may work concurrently
only when the coder has paused edits so they inspect the same revision.
Deployment credentials and permission still come from the user. Prepare a
reviewable release first; publish/deploy only within an explicit user request.
Do not auto-purchase API credits or treat quota errors as permission to use APIs.

## Usage economy

Every agent draws on the same subscription's usage limits, so spend turns carefully.
- Keep hc messages short and factual; point to report files instead of pasting them.
- Block with `hc wait` instead of polling with repeated `hc get`/`hc read` calls.
- Read only the files a task needs; don't re-read unchanged files or re-explore the repo.
- Rerun expensive builds/test suites only after a relevant change.
- Assign work in coherent batches rather than many tiny tasks.
- If you hit a usage or rate limit message, stop. The orchestrator records the state
  in HANDOFF.md; specialists report the blocker if they can. Then wait for the user.
