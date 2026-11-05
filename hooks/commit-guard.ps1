# Claude Code "PreToolUse" hook for commits and PRs. It blocks:
#   1. Claude attribution: `Co-Authored-By: Claude ...` or "Generated with Claude Code"
#      in `git commit` messages and `gh pr create/edit` bodies.
#   2. `git commit` before the base branch (default: dev) has been reverse-merged.
#
# Exit 2 blocks the tool call, and Claude sees stderr and must fix the problem first.
# Set CLAUDE_BASE_BRANCH to use another base branch (e.g. develop, main).

$ErrorActionPreference = 'Continue'

$raw = [Console]::In.ReadToEnd()
try { $evt = $raw | ConvertFrom-Json } catch { exit 0 }

$cmd = [string]$evt.tool_input.command
$isCommit = $cmd -match '\bgit\s+(?:-[cC]\s+\S+\s+)*commit\b'
$isPr = $cmd -match '\bgh\s+pr\s+(?:create|edit|comment)\b'
if (-not ($isCommit -or $isPr)) { exit 0 }

$cwd = $evt.cwd
if (-not $cwd) { $cwd = (Get-Location).Path }
Set-Location -LiteralPath $cwd

# ---- 1. No Claude attribution ------------------------------------------
$attributionPattern = '(?im)co-authored-by:\s*claude|co-authored-by:[^\r\n]*@anthropic\.com|generated with \[?claude code'
$texts = @($cmd)
# Message or body passed via a file: git commit -F <file> / --file=<file>, gh pr --body-file <file>
foreach ($m in [regex]::Matches($cmd, '(?:-F|--file|--body-file)(?:\s+|=)("?)([^"\s]+)\1')) {
    $path = $m.Groups[2].Value
    if ($path -ne '-' -and (Test-Path -LiteralPath $path -PathType Leaf)) {
        $texts += [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $path))
    }
}
foreach ($t in $texts) {
    if ($t -match $attributionPattern) {
        [Console]::Error.WriteLine("Blocked: Claude must not be added as a contributor.")
        [Console]::Error.WriteLine("Remove any 'Co-Authored-By: Claude' trailer and any 'Generated with Claude Code' line,")
        [Console]::Error.WriteLine("then run the command again. Commits and PRs are authored by the user only.")
        exit 2
    }
}

if (-not $isCommit) { exit 0 }

# ---- 2. Base branch must be reverse-merged before committing ------------
$base = $env:CLAUDE_BASE_BRANCH
if (-not $base) { $base = 'dev' }

git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { exit 0 }

# First commit in a new repo: nothing to compare.
git rev-parse -q --verify HEAD *> $null
if ($LASTEXITCODE -ne 0) { exit 0 }

# Concluding a merge (e.g. after resolving conflicts): allow.
git rev-parse -q --verify MERGE_HEAD *> $null
if ($LASTEXITCODE -eq 0) { exit 0 }

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -eq $base) { exit 0 }

git fetch origin $base --quiet *> $null

git rev-parse -q --verify "refs/remotes/origin/$base" *> $null
if ($LASTEXITCODE -ne 0) { exit 0 }   # repo has no origin/<base>: rule doesn't apply

git merge-base --is-ancestor "origin/$base" HEAD
if ($LASTEXITCODE -eq 0) { exit 0 }

$behind = (git rev-list --count "HEAD..origin/$base").Trim()
[Console]::Error.WriteLine("Commit blocked: branch '$branch' is $behind commit(s) behind origin/$base.")
[Console]::Error.WriteLine("Reverse-merge $base first:")
[Console]::Error.WriteLine("  1. git merge origin/$base")
[Console]::Error.WriteLine("  2. Resolve any conflicts (ask the user if a conflict is not clear-cut)")
[Console]::Error.WriteLine("  3. dotnet build and dotnet test must pass")
[Console]::Error.WriteLine("  4. Then commit")
exit 2
