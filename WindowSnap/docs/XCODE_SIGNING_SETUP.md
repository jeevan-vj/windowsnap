# Xcode Signing Setup Guide

## Step 1: Add Your Apple Developer Account to Xcode

1. **Open Xcode Settings:**
   - Xcode → Settings (or press `⌘,`)
   - Click the **"Accounts"** tab

2. **Add Your Account:**
   - Click the **"+"** button (bottom left)
   - Select **"Apple ID"**
   - Enter your Apple Developer account email and password
   - Click **"Sign In"**

3. **Verify Your Team:**
   - You should see your team listed
   - Note your **Team ID** (shown in parentheses)

## Step 2: Download Certificates

1. **In Xcode Settings → Accounts:**
   - Select your Apple ID
   - Select your Team
   - Click **"Manage Certificates..."** button

2. **Create Certificates:**
   - Click the **"+"** button (bottom left)
   - For **outside App Store distribution**, select:
     - **"Developer ID Application"**
   - For **App Store distribution**, select:
     - **"Apple Distribution"**
   - Xcode will automatically create and download the certificates

## Step 3: Configure Signing in Xcode

### Option A: Swift Package (Current Setup)

Since you're using a Swift Package, signing is limited. Here's what to do:

1. **In Xcode with Package.swift open:**
   - Click on **"WindowSnap"** in the Project Navigator (left sidebar)
   - In the main editor, you should see package settings
   - Look for **"Signing & Capabilities"** or build settings

2. **If Signing tab is not visible:**
   - Swift Packages don't have full signing UI
   - You'll need to use command line or create an Xcode project

### Option B: Create Xcode Project (Recommended)

For full signing support, create an Xcode project:

1. **File → New → Project**
2. **Select:** macOS → App
3. **Configure:**
   - Product Name: `WindowSnap`
   - Team: Select your team
   - Organization Identifier: `com.windowsnap` (or your domain)
   - Bundle Identifier: `com.windowsnap.app`
   - Language: Swift
   - Interface: SwiftUI (or AppKit)
   - Click **"Next"** and save

4. **Add Your Source Files:**
   - Delete the default files Xcode created
   - Right-click the project → **"Add Files to WindowSnap..."**
   - Navigate to `WindowSnap/WindowSnap/` directory
   - Select all folders: `App`, `Core`, `UI`, `Models`, `Utils`
   - **IMPORTANT:** Uncheck **"Copy items if needed"**
   - Check **"Create groups"**
   - Click **"Add"**

5. **Configure Signing:**
   - Select the **"WindowSnap"** target
   - Go to **"Signing & Capabilities"** tab
   - Check **"Automatically manage signing"**
   - Select your **Team** from dropdown
   - Xcode will automatically:
     - Register the bundle ID
     - Create provisioning profiles
     - Configure signing

6. **Copy Info.plist:**
   - Make sure `WindowSnap/WindowSnap/App/Info.plist` is included
   - Or configure build settings to use it

7. **Add Entitlements:**
   - In Signing & Capabilities, click **"+ Capability"**
   - Add any needed capabilities
   - Or manually set entitlements file to `WindowSnap.entitlements`

## Step 4: Archive and Distribute

1. **Select Scheme:**
   - Product → Scheme → Edit Scheme
   - Archive → Build Configuration: **Release**

2. **Archive:**
   - Product → Archive (or `⌘B` then Product → Archive)
   - Wait for build to complete

3. **Distribute:**
   - Organizer window opens automatically
   - Select your archive
   - Click **"Distribute App"**
   - You should now see:
     - ✅ **App Store Connect** (if bundle ID registered)
     - ✅ **Developer ID** (for outside App Store)
     - ✅ **Development**
     - ✅ **Ad Hoc**

## Troubleshooting

**"No signing certificate found":**
- Go to Settings → Accounts → Manage Certificates
- Create the missing certificate type

**"Bundle identifier is not available":**
- Register it at: https://developer.apple.com/account/resources/identifiers/list
- Or let Xcode register it automatically when you enable signing

**"Provisioning profile not found":**
- Enable "Automatically manage signing" in Signing & Capabilities
- Xcode will create it automatically

**Swift Package doesn't show Signing tab:**
- Swift Packages have limited signing support in Xcode
- Use command line signing (see scripts) or create an Xcode project



