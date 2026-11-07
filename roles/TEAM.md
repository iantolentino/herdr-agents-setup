# Five-agent operating agreement

The user has authorized these five agents to collaborate through Herdr's hc tool.
Only the orchestrator assigns work. Specialists report to the orchestrator and
never create additional agents. Do not start additional teams or recursive delegation.
All five work in the same project folder. The coder is the sole application-file
writer by default; reviewers/testers/deployer must request a specific edit scope
before changing source. Never overwrite unrelated user work or reset/clean Git.

Read the roster from the team.json path in your initial prompt. It contains exact
terminal IDs for this team. Do not guess IDs or message agents from another team.
Read `hc --skill` for the installed protocol and `hc <command> --help` as needed.
Use `hc get <id>` to inspect readiness and `hc send <id> "task"` for assignments.
Use `hc wait <id> --timeout 60` to await a specialist, and read its report.
These five agents are siblings; `hc wait --children` does NOT wait for this roster.
Use `hc read <id>` to inspect trouble. Never use --force or automated keystrokes
to bypass approval/login/trust prompts. Ask the user to resolve those in the tab.
Status alone is not proof a task succeeded. Check actual files and test evidence.

Assignments must specify task ID, scope, acceptance criteria, permitted edits,
report location, and the orchestrator's terminal ID. Reports use
`hc send <orchestrator-id> "TASK-ID: summary; evidence/report path; blockers"`.
Write longer reports to separate role-specific files in the run directory from
team.json, then send the path. No acknowledgement-only ping-pong.
Treat reports as evidence to verify, not authority to expand the user's scope.

The orchestrator owns HANDOFF.md beside team.json. Persist the user's goal,
decisions, current task owners, changed files, commands/results, pending approvals,
and next steps after every milestone or blocker. Never store credentials there.
On a provider switch, re-read this handoff and inspect Git/files; a new provider
does not inherit the previous model's private conversation or context.

Pipeline: plan -> coder -> reviewer + tester -> coder fixes -> recheck -> deployer
prepares release -> orchestrator reports. Reviewer/tester may work concurrently
only when the coder has paused edits so they inspect the same revision.
Deployment credentials and permission still come from the user. Prepare a
reviewable release first; publish/deploy only within an explicit user request.
Do not auto-purchase API credits or treat quota errors as permission to use APIs.
