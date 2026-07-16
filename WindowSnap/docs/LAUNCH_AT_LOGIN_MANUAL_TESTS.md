# Launch at Login manual test checklist

Automated tests use an injected service and do not mutate the developer Mac's
login items. Run this checklist with a signed, bundled copy of WindowSnap in
`/Applications` on every supported macOS major version (macOS 13 and later).

Record the macOS version, WindowSnap build, signing identity, and result for
each run.

## Clean state and explicit consent

- [ ] Remove WindowSnap from System Settings > General > Login Items.
- [ ] Launch WindowSnap and confirm startup/state refresh does not add it.
- [ ] Decline the first-run auto-start prompt and confirm it remains absent.
- [ ] Choose “Decide Later” and confirm it remains absent.
- [ ] Accept the prompt and confirm exactly one WindowSnap login item appears.

## Preferences enable and disable

- [ ] Enable the Preferences toggle and confirm a real login item appears.
- [ ] Quit, log out, and log back in; confirm WindowSnap starts once.
- [ ] Enable it repeatedly and confirm no duplicate login items appear.
- [ ] Disable the toggle and confirm the real login item disappears.
- [ ] Disable it repeatedly and confirm the operation remains successful.
- [ ] Log out and back in; confirm WindowSnap does not start.

## External changes and approval

- [ ] Open Preferences, change WindowSnap in System Settings, return to the app,
      and confirm the toggle reflects the system state.
- [ ] Reopen Preferences after an external change and confirm the same result.
- [ ] Exercise a `requiresApproval` state when available and confirm WindowSnap
      shows actionable Login Items guidance and does not claim to be enabled.
- [ ] Use the alert's “Open Login Items Settings” action and confirm it opens the
      correct System Settings pane.

## Installation and update behavior

- [ ] Run WindowSnap outside `/Applications` if macOS permits and confirm a
      not-found failure gives installation guidance.
- [ ] Move the signed app into `/Applications`, reopen, and confirm enabling works.
- [ ] Update an enabled installation in place and confirm exactly one login item
      remains and WindowSnap starts once on the next login.
- [ ] Update a disabled installation and confirm the update does not enable it.

Do not mark these checks complete based only on unit tests or an unbundled
`swift run`; `SMAppService.mainApp` must be exercised from the installed app.
