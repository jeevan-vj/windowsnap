# Launch at Login

## Supported macOS versions

WindowSnap requires macOS 13 Ventura or later. Launch at Login uses
`SMAppService.mainApp` exclusively. macOS 12 and the legacy
`SMLoginItemSetEnabled` path are intentionally unsupported because the legacy
API requires a separately bundled and signed helper; the main app bundle ID is
not a valid substitute.

## Consent and behavior

WindowSnap never registers itself merely because it launched or because state
was refreshed. Registration can only follow an explicit user action:

- accepting the one-time first-run prompt, or
- enabling “Launch WindowSnap at login” in Preferences.

Declining or postponing the prompt leaves the login item untouched. Repeating
enable or disable is idempotent, so app updates do not create duplicate items.

## Source of truth

`SMAppService.mainApp.status` is the source of truth. The stored preference is
only a synchronized cache. WindowSnap refreshes system state:

- at application startup,
- whenever Preferences opens, and
- whenever the app becomes active while Preferences is visible.

Consequently, changes made directly in System Settings are reflected when the
user returns to WindowSnap.

## Status and error handling

`LaunchAtLoginManager` maps every service state into a testable app state:

- `enabled`
- `disabled` (`notRegistered`)
- `requiresApproval`
- `notFound`
- `unknown` for future system states

`requiresApproval` directs the user to **System Settings > General > Login
Items**. `notFound` asks the user to move WindowSnap to Applications and reopen
it. Registration and removal failures preserve the actual system state in the
Preferences control and include an action to open Login Items settings.

## Automated tests

Run the focused tests from `WindowSnap/`:

```bash
swift test --filter LaunchAtLoginManagerTests
```

The suite covers state mapping, no registration during read-only refresh,
enable/disable behavior, idempotency, external state changes, preference
synchronization, approval, not-found, and operation failures.

Actual login-item registration is macOS-owned behavior and is covered by the
manual checklist in `WindowSnap/docs/LAUNCH_AT_LOGIN_MANUAL_TESTS.md`.
