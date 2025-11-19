# Bundle ID Registration Guide

Your bundle ID: `com.windowsnap.app`

## Method 1: Apple Developer Portal (Web)

1. **Go to Apple Developer Portal:**

   - Visit: https://developer.apple.com/account
   - Sign in with your Apple Developer account

2. **Navigate to Identifiers:**

   - Click "Certificates, Identifiers & Profiles" in the left sidebar
   - Click "Identifiers" in the left sidebar
   - Click the "+" button (top left)

3. **Select App ID:**

   - Select "App IDs"
   - Click "Continue"

4. **Choose Type:**

   - Select "App" (for macOS app)
   - Click "Continue"

5. **Enter Details:**

   - **Description:** WindowSnap
   - **Bundle ID:** Select "Explicit"
   - **Bundle ID:** `com.windowsnap.app`
   - Click "Continue"

6. **Select Capabilities:**
   - For WindowSnap, you may need:
     - ✅ App Sandbox (if using sandbox)
     - ✅ Associated Domains (if needed)
     - ✅ Push Notifications (if needed)
   - Click "Continue"
   - Review and click "Register"

## Method 2: Xcode (Automatic)

1. **Open Xcode:**

   - File → Open
   - Navigate to `WindowSnap/` and open `Package.swift`

2. **Select Target:**

   - In the Project Navigator, select the project
   - Select the "WindowSnap" target
   - Go to "Signing & Capabilities" tab

3. **Enable Automatic Signing:**

   - Check "Automatically manage signing"
   - Select your Team from the dropdown
   - Xcode will automatically register the bundle ID if it doesn't exist

4. **If Bundle ID Already Exists:**
   - Xcode will show: "Bundle identifier is already in use"
   - This means it's already registered (good!)
   - You can proceed with signing

## Method 3: Command Line (using `xcrun altool` or `xcrun notarytool`)

For Developer ID distribution (outside App Store), you don't need to register the bundle ID in App Store Connect. The bundle ID just needs to match your signing certificate.

For App Store distribution, you MUST register it via Method 1 or 2.

## Verify Registration

After registering, verify it exists:

1. Go to: https://developer.apple.com/account/resources/identifiers/list
2. Search for `com.windowsnap.app`
3. It should appear in the list

## Troubleshooting

**"Bundle ID is not available":**

- The bundle ID might already be taken by another developer
- Try a different bundle ID like: `com.yourname.windowsnap` or `com.yourcompany.windowsnap`

**"Team not found":**

- Make sure you've added your Apple Developer account in Xcode
- Xcode → Settings → Accounts → Add Apple ID

**"No signing certificate":**

- After registering bundle ID, create certificates:
  - Certificates → "+" → "Developer ID Application" (for outside App Store)
  - Certificates → "+" → "Apple Distribution" (for App Store)
