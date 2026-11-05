# C# Review Workflow (shared by all csharp-guardian agents)

The junior, mid and senior agents all follow this same workflow and these guardrails.
They differ only in **how they communicate**, which each agent file defines.

## Hard rules (guardrails)

1. **Never modify production code.** Only create or edit files inside test projects
   (`*.Tests`, `*.UnitTests`, or projects that reference a test SDK). If production code
   needs changing, report it as a finding with a suggested fix.
2. **Never weaken a test to make it pass.** Don't delete or skip tests (`Skip=`, `[Ignore]`) or loosen assertions.
3. **Don't add NuGet packages.** List them as recommendations instead.
4. **Don't run** `git push`, `git commit`, `git reset`, `dotnet nuget push`, migrations against real
   databases, or anything that deploys.
5. If the build fails, stop after step 2 and report the build errors.

## Step 0: Load the standards
Read `~/.claude/standards/csharp.md` (Windows: `%USERPROFILE%\.claude\standards\csharp.md`), plus the
repo's `.editorconfig`, `Directory.Build.props`, `CONTRIBUTING.md` and any `docs/standards*`.
**Repo rules win** where they conflict with the global file.

## Step 1: Check the branch is up to date with {{BASE_BRANCH}}
Run `git fetch origin {{BASE_BRANCH}} --quiet` and then `git merge-base --is-ancestor origin/{{BASE_BRANCH}} HEAD`.
If that fails, the branch is missing commits from `{{BASE_BRANCH}}`. Make it the **first "Must fix"**:
"Reverse-merge {{BASE_BRANCH}} before committing: `git merge origin/{{BASE_BRANCH}}`, resolve conflicts, rebuild, retest."
Review against the merged result if the user agrees to merge first. Don't merge it yourself.

## Step 2: Find the scope and build
- Use the files the caller named. Otherwise use the changed files: `git status --porcelain` and `git diff HEAD -- '*.cs'`.
- Build: `dotnet build <sln> --nologo -v q`. New warnings in changed files are findings.

## Step 3: Run the existing tests
`dotnet test <sln> --no-build --nologo -v q`. Record passed, failed and skipped counts and failing test names.
Work out from the diff whether the change caused each failure.

## Step 4: Check coding standards
Check changed files against the standards. Optionally run
`dotnet format <sln> --verify-no-changes --include <changed files>`.

## Step 5: Write new unit tests
For each changed or new public behaviour that has no test:
- Copy the existing test project's framework, mocking library, naming and folder layout.
- Cover the happy path, edge cases (null, empty, boundaries) and failure paths. Follow the standards' test rules.
- Run them. If a new test fails because of a **real bug**, keep it, mark it "exposes a bug", and don't touch production code.
- If code is untestable (`DateTime.Now`, `new HttpClient()`, statics), report it as a finding with the refactor. Don't write brittle tests.

## Step 6: Peer review
- **Correctness:** logic errors, off-by-one, null handling, missed edge cases.
- **Async:** sync-over-async, `async void`, missing `CancellationToken`, deadlocks.
- **Resources:** undisposed `IDisposable`, `HttpClient` misuse, unclosed streams or connections.
- **Errors:** swallowed exceptions, `throw ex;`, catching `Exception` too broadly.
- **Security:** SQL injection, secrets in code or config, missing validation, sensitive data in logs.
- **Performance:** N+1 queries, multiple enumeration, hot-loop allocations, missing `AsNoTracking`.
- **Readability:** naming, method length, unclear intent, dead code, misleading comments.

## Step 7: Technical debt and future problems
- Duplication, god classes or methods, tight coupling, missing abstractions at I/O boundaries.
- Hard-coded config, URLs, magic numbers, environment-specific values.
- `TODO`/`HACK`/`FIXME` without a ticket. `#pragma warning disable` or `!` without a reason.
- Obsolete APIs. Outdated or vulnerable packages (`dotnet list package --outdated` / `--vulnerable` when quick).
- Missing logging, observability or tests on risky paths.
- Scalability: unbounded collections, whole-table loads, no paging, missing timeouts or retries.

Rate each item for **impact** (Low/Med/High) and **effort** (S/M/L).

## Report skeleton
```
## Verdict: ✅ Ready / ⚠️ Ready with fixes / ❌ Needs changes
### Branch: up to date with {{BASE_BRANCH}} ✅ / behind {{BASE_BRANCH}} ❌
### Build & Tests
- Build: pass/fail (new warnings: N)
- Existing tests: X passed, Y failed, Z skipped
- New tests: N written (paths), all passing / M expose bugs
### Must fix (blocking)
### Should fix
### Technical debt / future risks
| Item | Location | Impact | Effort | Suggestion |
```
Each agent adds or adjusts sections according to its level. Always cite `File.cs:line`.
Group repeated issues instead of listing every occurrence.
