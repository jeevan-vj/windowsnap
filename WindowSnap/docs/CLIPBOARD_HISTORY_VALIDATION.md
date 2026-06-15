# Clipboard History Validation

## Fast local loop

```bash
cd WindowSnap
swift build
swift test
bash scripts/quick-run.sh
```

## Manual checklist

See [CLIPBOARD_HISTORY_BEHAVIOR_CONTRACT.md](CLIPBOARD_HISTORY_BEHAVIOR_CONTRACT.md) for the locked behavior contract.

- [ ] Open with Cmd+Shift+V
- [ ] Search filters list (debounced)
- [ ] Type filter chips toggle and combine with search
- [ ] Arrow keys skip section headers
- [ ] Enter pastes and closes window
- [ ] Cmd+C copies without paste
- [ ] Cmd+P toggles pin and preserves selection
- [ ] Cmd+Backspace deletes selected item
- [ ] Space toggles Quick Look
- [ ] Tab switches search/table focus
- [ ] Clear history shows confirmation

## CI

Pull requests run `.github/workflows/pr-validation.yml`: debug build, release build, and `swift test`.
