# C# Guardrails for Claude Code

A global setup that makes Claude Code follow your C# standards, write and run unit tests,
peer review changes, flag technical debt and reverse-merge `dev` before committing, with
review agents tailored to **junior, mid and senior** developers. Claude is never added as a
contributor: commits and PRs carry no Claude co-author or "Generated with Claude Code" lines.

## Quick start (new machine)

1. Install **Git**, the **.NET SDK** (8+) and **Claude Code** (desktop app or CLI), then sign in to Claude.
2. Clone this repo and run the installer with your level:
   ```powershell
   git clone https://github.com/michaeljohnkearney83/csharp-guardrails.git
   cd csharp-guardrails
   powershell -ExecutionPolicy Bypass -File install.ps1 -Level mid
   ```
3. Restart Claude Code.
4. Check it's working by asking Claude: *"Which C# guardian agent will you use for me?"* It should name `csharp-guardian-mid`.

### Starting a new C# project
Ask Claude: *"Create a new .NET solution called Acme.Orders with a Web API, a class library and an xUnit
test project, our .editorconfig, git, and a `dev` branch."* Or do it yourself:
```powershell
dotnet new sln -n Acme.Orders
dotnet new classlib -n Acme.Orders.Core
dotnet new xunit -n Acme.Orders.Core.Tests
dotnet sln add Acme.Orders.Core Acme.Orders.Core.Tests
Copy-Item <path-to>\csharp-guardrails\templates\.editorconfig .
git init; git add .; git commit -m "Initial solution"; git branch dev
```
Push to a remote that has a `dev` branch. Until `origin/dev` exists, the reverse-merge check is skipped.
Then work on feature branches cut from `dev`.

## Installer options

```powershell
.\install.ps1 -Level junior|mid|senior [-BaseBranch dev] [-ClaudeHome <path>] [-DryRun]
```

| Option | Default | Meaning |
|---|---|---|
| `-Level` | (required) | Which guardian agent Claude uses for you. |
| `-BaseBranch` | `dev` | Branch that must be reverse-merged before commits. |
| `-ClaudeHome` | `$env:CLAUDE_CONFIG_DIR` or `~\.claude` | Where to install. |
| `-DryRun` | off | Show what would be written, without changing anything. |

The installer:
- copies agents, standards and hooks into `~/.claude`;
- adds a marked `<!-- csharp-guardrails -->` section to `~/.claude/CLAUDE.md`;
- **merges** permissions, hooks and `env.CLAUDE_BASE_BRANCH` into `~/.claude/settings.json`, keeping your own entries;
- turns off Claude Code's commit/PR attribution (`"attribution": {"commit": "", "pr": ""}` and `"includeCoAuthoredBy": false`);
- backs up `CLAUDE.md` and `settings.json` (`*.bak-<timestamp>`) before changing them.

It's safe to re-run: to **update** after a `git pull`, or to **change level**, just run it again.

## What's in here

| File | What it does |
|---|---|
| `standards/csharp.md` | The C# coding standards. One source of truth. |
| `standards/csharp-review-workflow.md` | Shared review steps and guardrails used by all three agents. |
| `agents/csharp-guardian-junior.md` | Teaching style: plain language, hints before answers, top 5 findings, exercises. |
| `agents/csharp-guardian-mid.md` | Balanced: concrete fixes, design trade-offs, up to 10 findings. |
| `agents/csharp-guardian-senior.md` | Terse peer review: architecture, concurrency, operability, tech-debt risk register. |
| `CLAUDE.snippet.md` | Template for the CLAUDE.md section: level, standards import, dev-merge rule, no-attribution rule. |
| `hooks/dotnet-guard.ps1` | **Stop hook:** build + format check + tests must pass before Claude can finish. |
| `hooks/commit-guard.ps1` | **PreToolUse hook:** blocks Claude's `git commit` / `gh pr` if it adds Claude attribution, and blocks `git commit` if the branch is behind `origin/<base>`. |
| `settings.snippet.json` | Template for the settings, permissions and hooks the installer merges. |
| `git-hooks/pre-commit` | Optional: the same dev-merge rule for commits made by people. |
| `git-hooks/commit-msg` | Optional: strips Claude co-author / "Generated with Claude Code" lines from any commit message. |
| `templates/.editorconfig` | Per-repo style rules enforced by `dotnet format`, the IDE and the Stop hook. |
| `install.ps1` | The installer. |

`{{LEVEL}}`, `{{BASE_BRANCH}}` and `{{CLAUDE_HOME}}` in the templates are filled in by the installer.

## How the layers work together

1. **Guidance:** CLAUDE.md sets your level and imports the standards, so Claude codes to them from the start.
2. **Review:** after C# changes, Claude runs the guardian for your level. Every level follows the same steps
   (dev-merge check → build → existing tests → standards → new tests → peer review → tech debt) and the same rules
   (never edits production code, never weakens tests, never adds packages or commits). Only the communication style differs.
3. **Enforcement:**
   - Before `git commit`: blocked unless `origin/<base>` is merged into the branch.
   - Before `git commit` / `gh pr create|edit|comment`: blocked if the message or body (including `-F` / `--body-file` files)
     contains a Claude co-author trailer or "Generated with Claude Code".
   - Before Claude finishes: `dotnet build`, `dotnet format --verify-no-changes` (changed files) and `dotnet test` must pass.
4. **Permissions:** force-push, `reset --hard`, `git clean -fd`, NuGet publish and `ef database drop` are denied.
   Push, commit, `dotnet add package` and `ef database update` need approval.

## Use

- Claude picks the agent for your level automatically after C# changes.
- Ask for a specific one: *"Use csharp-guardian-senior to review this PR"* or
  *"Have csharp-guardian-junior write tests for `InvoiceCalculator` and walk me through them"*.
- Leads can run the junior agent on a junior's branch to get a ready-made mentoring review.

## Per-repo setup

- Copy `templates/.editorconfig` to the repo root, or merge it with the existing one.
- Optional: apply the rules to every commit, not just Claude's. Copy `git-hooks/pre-commit` (dev-merge check) and
  `git-hooks/commit-msg` (strips Claude attribution) into `.git/hooks/`, or for a team, commit them to `.githooks/` and
  have everyone run `git config core.hooksPath .githooks`. The base branch comes from
  `git config hooks.baseBranch <name>` (default `dev`).
- Overrides: a repo's `.claude/agents/<same name>.md` replaces the global agent. The repo's `.editorconfig` and docs override the global standards.

## Switches

| Env var | Effect |
|---|---|
| `CLAUDE_DOTNET_GUARD=off` | Disable the build/format/test Stop hook. |
| `CLAUDE_DOTNET_GUARD_SKIP_TESTS=1` | Build and format only (for slow test suites). |
| `CLAUDE_BASE_BRANCH=<name>` | Base branch for the commit check (the installer sets this in `settings.json`). |

## Sharing with a team

Each developer clones this repo and runs `install.ps1` with their own level. For rules people can't
turn off, put the permissions and hooks in Claude Code *managed settings*.

## Uninstall

Delete `~/.claude/agents/csharp-guardian-*.md`, `~/.claude/standards/csharp*.md` and
`~/.claude/hooks/{dotnet-guard,commit-guard}.ps1`. Then remove the marked section from
`~/.claude/CLAUDE.md`, and the two hook entries and the `attribution` / `includeCoAuthoredBy` settings from
`~/.claude/settings.json`. Or restore the `.bak-*` backups.

## Notes and limits

- Windows only for now (the hooks are PowerShell).
- The commit check fetches `origin/<base>` on each commit. If the fetch fails, it uses the last fetched ref. Repos without
  `origin/<base>`, the first commit, merge-completion commits and commits on the base branch itself are allowed.
- The Stop hook runs only when `.cs`/`.csproj` files have uncommitted changes. It builds the first `*.sln`/`*.slnx` in the
  folder (or the first `*.csproj` up to 2 levels deep), and blocks at most once per turn so it can't loop.
- Large solutions can take a while to test. Raise `timeout` in settings or use `SKIP_TESTS`.
