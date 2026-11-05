# Claude Code "Stop" hook: a hard guardrail for C# projects.
#
# When Claude tries to finish a turn after changing .cs/.csproj files, this runs:
#   1. dotnet build
#   2. dotnet format --verify-no-changes (changed files only)
#   3. dotnet test
# If any step fails, it exits with code 2. Claude Code then shows stderr to
# Claude and makes it keep working until the problem is fixed.
#
# Set CLAUDE_DOTNET_GUARD=off to disable it for a session.
# Set CLAUDE_DOTNET_GUARD_SKIP_TESTS=1 to build and format only.

$ErrorActionPreference = 'Continue'

if ($env:CLAUDE_DOTNET_GUARD -eq 'off') { exit 0 }

$raw = [Console]::In.ReadToEnd()
try { $evt = $raw | ConvertFrom-Json } catch { exit 0 }

# Avoid infinite loops: if we already blocked once and Claude is stopping again, let it.
if ($evt.stop_hook_active) { exit 0 }

$cwd = $evt.cwd
if (-not $cwd) { $cwd = (Get-Location).Path }
Set-Location -LiteralPath $cwd

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { exit 0 }

git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { exit 0 }

$status = @(git status --porcelain -- '*.cs' '*.csproj')
if ($status.Count -eq 0) { exit 0 }

# Changed files that still exist (handles renames "old -> new", skips deletions).
$changedCs = @()
foreach ($line in $status) {
    if ($line.Length -lt 4) { continue }
    $path = $line.Substring(3).Trim('"')
    if ($path -match ' -> ') { $path = ($path -split ' -> ')[-1].Trim('"') }
    if ($path -like '*.cs' -and (Test-Path -LiteralPath $path)) { $changedCs += $path }
}

$target = Get-ChildItem -Path $cwd -File | Where-Object { $_.Extension -in '.sln', '.slnx' } | Select-Object -First 1
if (-not $target) {
    $target = Get-ChildItem -Path $cwd -Filter *.csproj -File -Recurse -Depth 2 | Select-Object -First 1
}
if (-not $target) { exit 0 }

function Fail($title, $output) {
    [Console]::Error.WriteLine("C# guardrail failed: $title")
    [Console]::Error.WriteLine("Fix these before finishing. Do not skip, delete or weaken tests to get past this.")
    $output | Select-Object -Last 60 | ForEach-Object { [Console]::Error.WriteLine("$_") }
    exit 2
}

$build = dotnet build "$($target.FullName)" --nologo -v q 2>&1
if ($LASTEXITCODE -ne 0) { Fail "dotnet build" $build }

if ($changedCs.Count -gt 0) {
    $format = dotnet format "$($target.FullName)" --verify-no-changes --no-restore --include $changedCs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Fail "dotnet format (style/analyzer rules from .editorconfig). Run 'dotnet format --include <files>' or fix manually" $format
    }
}

if ($env:CLAUDE_DOTNET_GUARD_SKIP_TESTS -ne '1') {
    $test = dotnet test "$($target.FullName)" --no-build --nologo -v q 2>&1
    if ($LASTEXITCODE -ne 0) { Fail "dotnet test" $test }
}

exit 0
