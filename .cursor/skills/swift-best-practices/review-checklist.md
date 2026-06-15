# Swift Code Review Rubric

Use when reviewing Swift changes. Label each finding by severity.

## Severity labels

- 🔴 **Critical** — must fix before merge (crashes, data loss, leaks, unsafe unwraps)
- 🟡 **Suggestion** — should improve (clarity, structure, conventions)
- 🟢 **Nice to have** — optional polish

## 🔴 Critical — block the merge

- Force-unwrap (`!`), `try!`, or `as!` on values that can realistically be nil/fail.
- Retain cycle: `self` captured strongly in a stored/escaping closure, timer, or `Task`.
- UI/AppKit mutated off the main thread (missing `@MainActor`).
- Swallowed error that the caller must know about (`try?` discarding, empty `catch`).
- Blocking the main thread (sync I/O, `semaphore.wait()`, `sleep`).
- Data race on shared mutable state not protected by an actor/queue.

## 🟡 Suggestion — should address

- Names that don't read as English phrases at the call site, or that repeat type info.
- `class` used where a `struct`/`enum` would do; missing `final`.
- Boolean flags / optionals where an `enum` models the states better.
- Access level too broad (public/internal where private fits).
- Giant view `body` or controller; logic that belongs in a model living in the view.
- GCD used for new code where Swift Concurrency fits.
- Missing `///` doc comment on non-trivial public/internal API.

## 🟢 Nice to have

- Trailing-closure / single-expression simplifications.
- `// MARK:` grouping for long files.
- Consistent ordering: stored props → init → public API → private helpers.
- Replace `ObservableObject`/`@Published` with `@Observable` on supported OS targets.

## Output format

For each file, list findings as:

```
path/to/File.swift
  🔴 L42  Force-unwrap on `URL(string:)` — use guard let + throw.
  🟡 L88  `makeRequest` reads better as `request(for:)`.
  🟢 L10  Group helpers under `// MARK: - Private`.
```

End with a one-line verdict: **Approve**, **Approve with nits**, or **Request changes**.
