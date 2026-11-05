# C# Coding Standards

The single source of truth for C# style in every project. The `csharp-guardian`
agent reviews against this file, and the global CLAUDE.md imports it so Claude
follows it while writing code.

If a repository has its own `.editorconfig` or standards doc, **the repository wins**
where they conflict.

## 1. Naming

| Element | Convention | Example |
|---|---|---|
| Namespaces, types, methods, properties, events, public fields | PascalCase | `OrderService`, `CalculateTotal` |
| Interfaces | `I` + PascalCase | `IOrderRepository` |
| Parameters, locals | camelCase | `orderId` |
| Private / internal fields | `_camelCase` | `_logger` |
| Constants | PascalCase | `MaxRetryCount` |
| Async methods | `Async` suffix | `GetOrderAsync` |
| Generic type params | `T` or `T` + name | `TEntity` |
| Booleans | Read as a question | `isActive`, `HasItems` |

- Use full, descriptive names. Avoid abbreviations except well-known ones (`Id`, `Url`, `Http`).
- Avoid Hungarian notation and type prefixes (`strName`, `iCount`).

## 2. Layout and syntax

- File-scoped namespaces (`namespace Acme.Orders;`).
- One top-level type per file, and the file name matches the type name.
- Always use braces, even for single-line `if`/`for`/`while`.
- Order members: constants, fields, constructors, properties, public methods, then private methods.
- Use `var` when the type is obvious from the right-hand side. Otherwise write the type.
- Use expression-bodied members only for simple one-liners.
- Use string interpolation (`$"..."`) instead of `string.Format` or concatenation.
- Use `using` declarations (`using var stream = ...;`) for disposables.
- Use `record` for immutable DTOs and value objects.
- Keep `<Nullable>enable</Nullable>` on. Don't silence warnings with `!` unless a comment says why.

## 3. Design

- Keep methods small (aim for about 30 lines or fewer) with a single responsibility.
- Keep classes focused. More than about 300 lines or 7+ constructor dependencies is a smell.
- Use constructor dependency injection. No service locator, and no `new` for services.
- Depend on interfaces at boundaries (I/O, time, randomness, external APIs) so code is testable.
- No magic numbers or strings: use named constants, options classes or configuration.
- No mutable static state.
- Prefer composition over inheritance. Seal classes that are not designed for inheritance.
- Use guard clauses at public entry points: `ArgumentNullException.ThrowIfNull(order);`.

## 4. Async

- Use async all the way. Never use `.Result`, `.Wait()` or `.GetAwaiter().GetResult()` on tasks.
- No `async void` except in event handlers.
- Accept and pass through a `CancellationToken` on async public APIs.
- Use `ConfigureAwait(false)` in library code (not in ASP.NET Core app code).
- Don't use `Task.Run` to fake async around synchronous I/O.

## 5. Errors and logging

- Catch specific exceptions. Never swallow exceptions silently (`catch { }`).
- Use `throw;` to rethrow, never `throw ex;` (it loses the stack trace).
- Don't use exceptions for normal control flow.
- Use structured logging with message templates: `_logger.LogInformation("Order {OrderId} created", id);`
  Don't use interpolated strings in log calls.
- Never log secrets, tokens, passwords or full personal data.

## 6. Security

- Use parameterized queries or EF Core. No string-built SQL.
- No secrets in source code or `appsettings.json` committed to git. Use user-secrets or a vault.
- Validate all external input (API models, files, query strings).
- Don't disable TLS or certificate validation.

## 7. Performance

- Avoid N+1 queries. Use `Include`, projections, or batching.
- Use `AsNoTracking()` for read-only EF queries.
- Don't call `.ToList()` mid-chain without a reason. Don't enumerate an `IEnumerable` more than once.
- Use `StringBuilder` for string concatenation inside loops.
- Use `IHttpClientFactory` and don't `new HttpClient()` per call.

## 8. Unit tests

- Use the test framework the repo already uses (xUnit, NUnit or MSTest). Default to **xUnit** for new test projects.
- Use the mocking/assertion libraries the repo already uses. Don't add new packages without asking.
- Name test projects `<Project>.Tests` and mirror the source folder structure.
- Name tests `MethodName_StateUnderTest_ExpectedBehavior`.
- Use Arrange / Act / Assert sections, separated by blank lines.
- Test one behaviour per test. No `if`/loops in tests (use `[Theory]`/`[TestCase]` for data).
- Tests must be deterministic: no real time, network, file system or random values. Inject them.
- Cover the happy path, edge cases (null, empty, boundaries) and failure paths.
- Never change production code just to make a test pass without flagging it.

## 9. Comments and docs

- XML doc comments (`///`) on public APIs of libraries.
- Comments explain *why*, not *what*.
- `TODO` comments must include an owner or ticket: `// TODO(ABC-123): ...`.
