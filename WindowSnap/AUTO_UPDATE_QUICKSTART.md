# Auto-Update Quick Start

## One-Time Setup

1. **Install Sparkle tools:**
   ```bash
   brew install sparkle
   ```

2. **Generate signing keys:**
   ```bash
   bash WindowSnap/scripts/generate-sparkle-keys.sh
   ```

3. **Update Info.plist with public key:**
   - The script will output the public key
   - Open `WindowSnap/WindowSnap/App/Info.plist`
   - Replace `REPLACE_WITH_PUBLIC_KEY_AFTER_RUNNING_generate-sparkle-keys.sh` with the actual public key

## How It Works

- **Automatic checks:** App checks for updates every 24 hours in the background
- **Manual check:** Users can click "Check for Updates..." in the menu bar
- **Release process:** The `release.sh` script automatically generates and uploads the appcast

## Next Release

When you run `bash scripts/release.sh`, it will:
1. Build and sign the app
2. Create GitHub release
3. Generate `appcast.xml` (Sparkle update feed)
4. Upload appcast to GitHub release
5. Users' apps will automatically detect the update

That's it! Auto-updates are now enabled.

## Troubleshooting

- **Keys not found:** Run `generate-sparkle-keys.sh` first
- **Appcast generation fails:** Ensure `brew install sparkle` is installed
- **Updates not appearing:** Check that `appcast.xml` is accessible at the URL in `Info.plist`

For detailed documentation, see `docs/AUTO_UPDATE_SETUP.md`.




