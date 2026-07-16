# WindowSnap production releases

Public releases must be universal, signed with a Developer ID Application certificate, notarized, stapled, and verified. `WindowSnap/scripts/release.sh` is the only production release entry point. Supporting scripts are internal stages and must not be used to publish artifacts independently.

## One-time setup

1. Install a valid `Developer ID Application` certificate in the login Keychain.
2. Store notarization credentials in Keychain without adding credentials to the command line, repository, or shell history:

   ```bash
   xcrun notarytool store-credentials "windowsnap-notary"
   ```

   Follow the secure interactive prompts for Apple ID, team ID, and the app-specific password. The secret is entered without being embedded in the command and is saved by `notarytool` in Keychain.

3. Export only the identity and Keychain profile names:

   ```bash
   export CODESIGN_ID="Developer ID Application: Your Name (TEAM_ID)"
   export NOTARY_PROFILE="windowsnap-notary"
   ```

4. Configure a GitHub repository ruleset with tag protection for `v*`: restrict
   creation to release maintainers and prevent tag updates or deletion. Release
   tags should be immutable after they are pushed. The release script rechecks
   the remote tag immediately before publishing, but server-side protection is
   the primary defense against accidental or malicious tag movement.

Do not commit certificates, private keys, passwords, profile exports, or notarization credentials. The scripts intentionally do not print credentials or Keychain contents.

## Canonical command

Set the desired semantic version in `WindowSnap/VERSION`, then run:

```bash
cd WindowSnap
./scripts/release.sh
```

This command fails closed if signing, either architecture, notarization acceptance, stapling, strict signature checks, Gatekeeper checks, or artifact metadata checks fail. It writes reviewed candidates under `WindowSnap/dist/production/` and does not publish them automatically.

To create a draft release from a fresh fully verified run, use:

```bash
./scripts/release.sh --publish --draft
```

Review the draft's uploaded artifacts and smoke-test them before manually publishing the draft. Remove `--draft` only when an immediate public GitHub release is intended. There is no production option to skip notarization. Local ad-hoc builds use `./scripts/build-adhoc-release.sh` and are isolated under `dist/local-only/`; never upload them.

## Automated verification

Run deterministic release-policy tests without Apple credentials:

```bash
./tests/release_pipeline_test.sh
```

The production pipeline additionally verifies the live artifact with `lipo`, `codesign`, `stapler`, `spctl`, `ditto`, and `hdiutil`. ZIP and DMG contents must match the expected `CFBundleShortVersionString` and `CFBundleVersion`.

## Clean-machine smoke test

Use a supported Mac that did not build the release and has no previous WindowSnap installation or Accessibility grant.

- Download both assets from the draft release and verify their SHA-256 files.
- Unzip the ZIP; confirm WindowSnap launches without a Gatekeeper override.
- Mount the DMG; drag WindowSnap to `/Applications`, eject the DMG, and launch the copied app.
- Confirm the menu-bar icon appears.
- Confirm first-run Accessibility permission onboarding appears and opens the correct System Settings pane.
- Grant Accessibility permission, relaunch if prompted, and snap a normal window left, right, maximize, and center.
- Confirm the About/version UI reports the release version and build.
- Repeat at least once on Apple Silicon and once on Intel hardware (or the supported Intel test environment).
- Record macOS versions, architectures, artifact checksums, and results in the release notes before publishing the draft.

If any check fails, leave the release as a draft, remove its candidate assets, fix the pipeline or application, and create a fresh build. Never document a Gatekeeper workaround for a failed production artifact.
