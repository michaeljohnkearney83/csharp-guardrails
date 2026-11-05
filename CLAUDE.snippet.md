## C# / .NET (installed by csharp-guardrails, re-run install.ps1 to change)

- My developer level: **{{LEVEL}}**
- Follow these coding standards whenever you write or change C#:
  @~/.claude/standards/csharp.md
- After writing or changing C# code, run the `csharp-guardian-{{LEVEL}}` subagent before saying
  the work is done, and summarize its verdict. Use another level only if I ask for it.
- When you add or change public behaviour, add or update unit tests in the same task.
- **Before every commit, reverse-merge `{{BASE_BRANCH}}`:** `git fetch origin {{BASE_BRANCH}}` then
  `git merge origin/{{BASE_BRANCH}}`, resolve conflicts (ask me about any that aren't clear-cut), then rebuild
  and rerun tests, then commit. A hook blocks the commit if this is skipped.
- **Never add Claude as a contributor:** no `Co-Authored-By: Claude` trailers in commit messages and no
  "Generated with Claude Code" lines in PR descriptions. Commits are authored by me only.
- Explain changes at my level: what changed, why, and what to watch out for.
