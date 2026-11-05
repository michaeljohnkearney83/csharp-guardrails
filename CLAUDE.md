# CLAUDE.md

This repo is a **Claude Code configuration package**, not an application. `install.ps1` copies its
agents, standards and hooks into a user's `~/.claude` and merges settings.

## Layout
- `standards/csharp.md`: the C# coding standards (single source of truth).
- `standards/csharp-review-workflow.md`: steps and guardrails shared by all guardian agents.
- `agents/csharp-guardian-{junior,mid,senior}.md`: thin agents that only define tone and focus and defer to the workflow file.
- `hooks/*.ps1`: Claude Code hooks (PowerShell 5.1 compatible). `git-hooks/{pre-commit,commit-msg}`: POSIX sh git hooks.
- `CLAUDE.snippet.md` and `settings.snippet.json`: templates the installer renders and merges.
- `templates/.editorconfig`: per-repo file the user copies by hand.

## Conventions
- Placeholders `{{LEVEL}}`, `{{BASE_BRANCH}}` and `{{CLAUDE_HOME}}` are replaced by `install.ps1` in `.md` files under
  `agents/` and `standards/`, and in both snippet files. Never hard-code a username or path.
- Shared behaviour goes in `csharp-review-workflow.md`, not in each agent. Agents differ only in communication style.
- Hook scripts must exit 0 when they don't apply (not a git repo, no .NET, no matching command), and exit 2 to block.
  The Stop hook must honour `stop_hook_active` to avoid loops.
- The installer must stay idempotent: re-running it replaces the marked CLAUDE.md block and our hook entries
  (matched by script file name) without touching the user's own settings.
- Files in `git-hooks/` must keep LF line endings (`.gitattributes` enforces this).
- **No Claude attribution in this repo:** never add `Co-Authored-By: Claude` trailers or "Generated with Claude Code"
  lines to commits or PRs. The owner must be the only contributor.

## Testing changes
- Installer: run `.\install.ps1 -Level mid -ClaudeHome <temp folder>` twice against a temp folder that already has a
  `settings.json` and `CLAUDE.md`. Check that user entries survive, there's no duplicate block or hooks, and no `{{` is left.
- Commit guard: in a temp repo with a bare `origin`, put `feature` one commit behind `origin/dev`. Pipe
  `{"cwd":"...","tool_input":{"command":"git commit -m x"}}` into `hooks/commit-guard.ps1` and expect exit 2.
  After `git merge origin/dev`, expect exit 0. A command or `-F` file containing `Co-Authored-By: Claude` must exit 2.
- `git-hooks/commit-msg`: run it on a message file with a Claude trailer, and the trailer must be gone afterwards.
- Parse-check PowerShell with `[System.Management.Automation.Language.Parser]::ParseFile`.

## Docs
When behaviour, options or files change, update `README.md` (and this file) in the same change.
