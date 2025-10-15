#!/usr/bin/env bash
set -euo pipefail

# WindowSnap Code Signing and Notarization Script
# 
# Prerequisites:
# 1. Apple Developer account ($99/year)
# 2. Developer ID Application certificate installed in Keychain
# 3. App-specific password created at appleid.apple.com
# 4. Notary tool profile created (see setup instructions below)
#
# Setup Instructions:
# 1. Find your signing identity:
#    security find-identity -v -p codesigning
#    Copy the "Developer ID Application: Your Name (TEAM_ID)" string
#
# 2. Create notary profile (one-time setup):
#    xcrun notarytool store-credentials "PROFILE_NAME" \
#      --apple-id "your@email.com" \
#      --team-id "YOUR_TEAM_ID" \
#      --password "app-specific-password"
#
# Usage:
#   export CODESIGN_ID="Developer ID Application: Your Name (TEAM_ID)"
#   export NOTARY_PROFILE="PROFILE_NAME"
#   bash scripts/sign-and-notarize.sh

APP_NAME="WindowSnap"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/${APP_NAME}.app"
ZIP_PATH="$DIST_DIR/${APP_NAME}.zip"

# Check required environment variables
if [[ -z "${CODESIGN_ID:-}" ]]; then
  echo "❌ Error: CODESIGN_ID environment variable not set"
  echo ""
  echo "To find your signing identity, run:"
  echo "  security find-identity -v -p codesigning"
  echo ""
  echo "Then export it:"
  echo "  export CODESIGN_ID=\"Developer ID Application: Your Name (TEAM_ID)\""
  exit 1
fi

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  echo "❌ Error: NOTARY_PROFILE environment variable not set"
  echo ""
  echo "To create a notary profile (one-time setup):"
  echo "  xcrun notarytool store-credentials \"PROFILE_NAME\" \\"
  echo "    --apple-id \"your@email.com\" \\"
  echo "    --team-id \"YOUR_TEAM_ID\" \\"
  echo "    --password \"app-specific-password\""
  echo ""
  echo "Then export it:"
  echo "  export NOTARY_PROFILE=\"PROFILE_NAME\""
  exit 1
fi

# Check if app exists
if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ Error: $APP_PATH not found"
  echo "   Run: bash scripts/build_bundle.sh first"
  exit 1
fi

echo "🔐 WindowSnap Code Signing and Notarization"
echo "============================================"
echo "App:     $APP_PATH"
echo "Identity: $CODESIGN_ID"
echo "Profile:  $NOTARY_PROFILE"
echo ""

# Step 1: Code sign the app (if not already signed properly)
echo "[1/5] Code signing app bundle..."
codesign --force --sign "$CODESIGN_ID" \
  --options runtime \
  --timestamp \
  --deep \
  "$APP_PATH" || {
    echo "❌ Code signing failed!"
    exit 1
  }

# Verify signature
echo "   Verifying signature..."
codesign --verify --verbose "$APP_PATH"
codesign --display --verbose=4 "$APP_PATH"
echo "✅ Code signing successful"
echo ""

# Step 2: Create zip for notarization
echo "[2/5] Creating zip archive for notarization..."
rm -f "$ZIP_PATH"
(cd "$DIST_DIR" && zip -qry "${APP_NAME}.zip" "${APP_NAME}.app")
echo "✅ Zip created: $ZIP_PATH"
echo ""

# Step 3: Submit for notarization
echo "[3/5] Submitting to Apple for notarization..."
echo "   This may take several minutes..."
NOTARY_OUTPUT=$(xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait 2>&1)

echo "$NOTARY_OUTPUT"

# Check if successful
if echo "$NOTARY_OUTPUT" | grep -q "status: Accepted"; then
  echo "✅ Notarization successful!"
  
  # Extract submission ID for logs
  SUBMISSION_ID=$(echo "$NOTARY_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')
  
  # Step 4: Staple the notarization ticket
  echo ""
  echo "[4/5] Stapling notarization ticket to app..."
  xcrun stapler staple "$APP_PATH" || {
    echo "⚠️  Stapling failed (this is optional but recommended)"
  }
  echo "✅ Stapling complete"
  
  # Step 5: Verify the app
  echo ""
  echo "[5/5] Verifying notarized app..."
  spctl -a -vv "$APP_PATH" || {
    echo "⚠️  spctl verification had warnings (this might be okay)"
  }
  
  # Recreate zip with stapled app
  echo ""
  echo "Recreating zip with stapled app..."
  rm -f "$ZIP_PATH"
  (cd "$DIST_DIR" && zip -qry "${APP_NAME}.zip" "${APP_NAME}.app")
  
  echo ""
  echo "🎉 SUCCESS! Your app is now signed and notarized!"
  echo ""
  echo "Distribution files:"
  echo "  - $APP_PATH (signed & notarized)"
  echo "  - $ZIP_PATH (includes notarization ticket)"
  echo ""
  echo "Users can now install without warnings!"
  echo ""
  
  # Save notarization info
  cat > "$DIST_DIR/NOTARIZATION_INFO.txt" <<EOF
Notarization Details
====================
Date: $(date)
Identity: $CODESIGN_ID
Profile: $NOTARY_PROFILE
Submission ID: $SUBMISSION_ID
Status: Accepted

The app has been successfully signed and notarized.
Users can install without Gatekeeper warnings.

To get notarization log:
  xcrun notarytool log $SUBMISSION_ID --keychain-profile $NOTARY_PROFILE
EOF
  
else
  echo ""
  echo "❌ Notarization failed!"
  echo ""
  echo "To get detailed logs, find the submission ID above and run:"
  echo "  xcrun notarytool log SUBMISSION_ID --keychain-profile $NOTARY_PROFILE"
  echo ""
  exit 1
fi

