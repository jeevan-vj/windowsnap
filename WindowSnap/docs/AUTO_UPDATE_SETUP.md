# Auto-Update Setup Guide

WindowSnap uses [Sparkle](https://sparkle-project.org/) for automatic updates. This guide explains how to set up and maintain the auto-update system.

## Prerequisites

1. **Install Sparkle tools:**
   ```bash
   brew install sparkle
   ```

2. **Generate signing keys** (one-time setup):
   ```bash
   bash WindowSnap/scripts/generate-sparkle-keys.sh
   ```
   
   This creates:
   - `~/.sparkle_dsa_priv.pem` - Private key (KEEP SECRET!)
   - `~/.sparkle_dsa_pub.pem` - Public key

3. **Add public key to Info.plist:**
   - Run the key generation script above
   - Copy the public key output
   - Replace `REPLACE_WITH_PUBLIC_KEY_AFTER_RUNNING_generate-sparkle-keys.sh` in `Info.plist` with the actual public key

## How It Works

1. **App Configuration:**
   - `SUFeedURL` in `Info.plist` points to the appcast.xml location
   - `SUPublicEDSAKey` contains the public key for verifying updates
   - `SUScheduledCheckInterval` sets how often to check (86400 = 24 hours)

2. **Update Process:**
   - App checks for updates in the background every 24 hours
   - Users can manually check via "Check for Updates..." in the menu bar
   - When an update is found, Sparkle shows a user-friendly update dialog
   - Updates are verified using the EDSA signature

3. **Release Process:**
   - The `release.sh` script automatically generates `appcast.xml` after creating a release
   - The appcast is uploaded to GitHub releases
   - Users' apps will detect the new version and prompt for update

## Manual Appcast Generation

If you need to generate an appcast manually:

```bash
# Set private key location (if not in default location)
export SPARKLE_PRIVATE_KEY="$HOME/.sparkle_dsa_priv.pem"

# Generate appcast for a specific version
bash WindowSnap/scripts/generate-appcast.sh 1.2.7
```

The script will:
1. Copy the DMG to the appcast directory
2. Generate `appcast.xml` with proper signatures
3. Output the appcast location

## Uploading Appcast

The release script automatically uploads the appcast, but you can also do it manually:

```bash
# Upload to GitHub release
gh release upload v1.2.7 dist/appcast/appcast.xml

# Or host on your own server
# Update SUFeedURL in Info.plist to point to your server
```

## Appcast URL Options

### Option 1: GitHub Releases (Recommended)
- URL: `https://github.com/jeevan-vj/windowsnap/releases/latest/download/appcast.xml`
- Pros: Free, automatic, no server needed
- Cons: Requires uploading appcast.xml to each release

### Option 2: Custom Web Server
- Host `appcast.xml` on your own server
- Update `SUFeedURL` in `Info.plist` to point to your server
- Pros: Full control, can customize update behavior
- Cons: Requires web hosting

## Security Notes

- **Never commit the private key** (`~/.sparkle_dsa_priv.pem`) to git
- Keep the private key secure - anyone with it can sign malicious updates
- The public key in `Info.plist` is safe to commit
- Consider using environment variables or secure key storage for CI/CD

## Troubleshooting

### Updates not appearing
1. Check that `appcast.xml` is accessible at the `SUFeedURL`
2. Verify the public key in `Info.plist` matches your private key
3. Check Sparkle logs: `~/Library/Logs/SparkleUpdateLog.log`

### Appcast generation fails
1. Ensure Sparkle tools are installed: `brew install sparkle`
2. Check that the private key exists: `ls ~/.sparkle_dsa_priv.pem`
3. Verify the DMG file exists in `dist/`

### Signature verification fails
1. Regenerate keys if needed: `bash scripts/generate-sparkle-keys.sh`
2. Update the public key in `Info.plist`
3. Rebuild and redistribute the app

## Testing Updates

1. Build a test version with a higher version number
2. Generate appcast for the test version
3. Host the appcast (or upload to a test GitHub release)
4. Install the older version of the app
5. Check for updates - it should detect the new version

## Additional Resources

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Sparkle GitHub](https://github.com/sparkle-project/Sparkle)




