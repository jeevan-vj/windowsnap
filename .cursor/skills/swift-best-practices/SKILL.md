---
name: swift-best-practices
description: Write, refactor, and review Swift and SwiftUI/AppKit code following official Swift API Design Guidelines and modern best practices (concurrency, value types, error handling, memory safety). Use when writing or editing .swift files, reviewing Swift code, designing APIs/types, or when the user mentions Swift, SwiftUI, AppKit, async/await, actors, or Combine.
---

# Swift Best Practices

Authoritative rules for writing well-maintained Swift. Grounded in the official
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
and the Swift Programming Language book. Apply these whenever you author or edit Swift.

## Golden rule

Clarity at the point of use is the most important goal. Code is read far more
than it is written. Prefer clear over brief, but never add words that don't carry their weight.

## Quick checklist (apply to every change)

- [ ] Names read as grammatical English phrases at the call site
- [ ] `struct`/`enum` by default; `class` only when reference semantics or AppKit/ObjC interop is required
- [ ] `let` over `var`; smallest possible access level (`private`/`fileprivate` first)
- [ ] No force-unwrap (`!`), no force-`try!`, no force-cast (`as!`) in non-test code
- [ ] Errors are typed `enum`s conforming to `Error`; thrown and handled, not swallowed
- [ ] Concurrency uses `async/await` + actors; UI mutation on `@MainActor`
- [ ] No retain cycles: `[weak self]` in escaping closures that outlive the call
- [ ] Public/internal API has `///` doc comments with a summary sentence
- [ ] No compiler warnings introduced; no dead code or leftover `print` debugging

## Naming (from the official guidelines)

- Include all words needed to avoid ambiguity; omit needless words that merely
  repeat type information. `remove(at: index)` not `removeElement(at: index)`.
- Name by **role**, not type: `var greeting: String` not `var string: String`.
- Methods/functions read as imperative verb phrases when they have side effects
  (`list.sort()`, `view.insert(at:)`); noun phrases when they return a value
  without side effects (`x.distance(to: y)`, `i.successor()`).
- Mutating/non-mutating pairs: `sort()`/`sorted()`, `reverse()`/`reversed()`.
- Booleans read as assertions: `isEmpty`, `hasPrefix`, `canShare`.
- Protocols describing what something **is** are nouns (`Collection`); protocols
  describing a **capability** end in `-able`/`-ible`/`-ing` (`Equatable`, `ProgressReporting`).
- Types and protocols `UpperCamelCase`; everything else `lowerCamelCase`.
- First argument label flows from the function name; use prepositions when the
  argument plays a grammatical role (`move(to:)`, `add(_:to:)`).
- Don't abbreviate. `URLSession` keeps established acronyms uppercased fully.

## Types and value semantics

- Default to `struct` and `enum`. Reach for `class` only for shared mutable
  identity, `NSObject` subclasses, delegates, or framework requirements.
- Model mutually exclusive states with `enum`s + associated values, not optional
  soup or boolean flags. Make illegal states unrepresentable.
- Mark classes `final` unless designed for subclassing.
- Use `@MainActor` on view models and types that touch UIKit/AppKit.

## Optionals and safety

- Never `!`-force-unwrap, `try!`, or `as!` outside tests. Use `guard let`,
  `if let`, `??`, optional chaining, or `guard ... else { throw/return }`.
- Use `guard` for early exit to keep the happy path unindented.
- Prefer non-optional types with sensible defaults over optionals when a value
  always exists.

## Error handling

- Define domain errors as `enum MyFeatureError: Error` (add `LocalizedError` when
  surfaced to users). One error type per subsystem.
- Use `throws`/`try`; propagate with typed `do/catch`. Never silently `try?` away
  errors that the caller needs to know about — log or handle them.
- `Result` is for stored/deferred outcomes and callback APIs; prefer `throws` for
  synchronous and `async` call sites.

## Concurrency (Swift Concurrency first)

- Prefer `async/await`, `Task`, `actor`, and `AsyncSequence` over GCD/completion
  handlers and over Combine for new code.
- Protect mutable shared state with `actor`s, not locks.
- All UI state mutation happens on `@MainActor`.
- Don't capture `self` strongly in long-lived `Task`s without a cancellation
  story; honor `Task.isCancelled` / `try Task.checkCancellation()`.
- Avoid blocking the main thread; never `DispatchSemaphore.wait()` on it.

## SwiftUI

- Pick the right property wrapper: `@State` (view-owned value), `@Binding`
  (two-way ref to parent state), `@Observable`/`@StateObject` (owned reference
  model), `@ObservedObject`/`@Environment` (injected), `@Bindable` for bindings
  into `@Observable` models.
- Prefer the modern `@Observable` macro over `ObservableObject`/`@Published` on
  macOS 14+/iOS 17+; otherwise `ObservableObject` + `@Published`.
- Keep `body` pure and cheap. Extract subviews and use `@ViewBuilder` helpers
  instead of giant view trees. Give `ForEach` stable, unique `id`s.
- Move logic out of `body` into the model; views describe, models decide.
- Use `.task {}` for async work tied to view lifecycle (auto-cancels).

## AppKit / macOS interop (this project)

- This is an AppKit-hosted macOS app; respect existing patterns: `NSWindowController`,
  `NSStatusItem`, delegates, target/action.
- Bridge AppKit callbacks into `async` with continuations where it improves call sites.
- Keep AppKit objects on the main thread; annotate controllers `@MainActor`.

## Project conventions (WindowSnap)

- Layered layout: `App/` (lifecycle), `Core/` (managers, engines, logic),
  `Models/` (value types), `UI/` (windows, views, controllers), `Utils/` (helpers).
- One primary type per file; filename matches the type.
- `Manager`/`Controller`/`Engine`/`Service` suffixes denote their role — match
  the existing vocabulary, don't invent synonyms.
- Tests live in `Tests/WindowSnapTests`; add coverage for new `Core`/`Models` logic.

## Formatting

- 4-space indentation, no tabs. Braces on the same line (K&R).
- One statement per line. Keep lines reasonably short (~120 cols).
- Group with `// MARK: -` sections; order: stored properties → init → public API
  → private helpers.
- Prefer trailing closure syntax; omit `return` in single-expression closures/funcs.

## Anti-patterns to flag in review

- Force-unwraps, `try!`, `as!` in production code.
- Massive view bodies or massive view controllers; God objects in `Core/`.
- Stringly-typed state where an `enum` belongs.
- Retain cycles from `self` captured strongly in stored/escaping closures.
- Mixing GCD and Swift Concurrency arbitrarily; `DispatchQueue.main.async` inside
  already-`@MainActor` code.
- Swallowed errors (`try?` / empty `catch`), leftover `print`/`NSLog` debugging.

## When unsure about an API

Consult the official Swift docs via the context7/docs tooling rather than
guessing — Swift evolves fast (concurrency, macros, `@Observable`).

## Additional resources

- For longer, copy-pasteable examples of each rule, see [examples.md](examples.md)
- For the review-only rubric and severity labels, see [review-checklist.md](review-checklist.md)
