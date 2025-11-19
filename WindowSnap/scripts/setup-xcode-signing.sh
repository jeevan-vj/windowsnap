#!/usr/bin/env bash
set -euo pipefail

# Interactive script to help set up Xcode signing
# This guides you through the process step by step

echo "🔐 Xcode Signing Setup Guide"
echo "============================"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
  echo "❌ Xcode is not installed or not in PATH"
  echo "   Install Xcode from the App Store"
  exit 1
fi

echo "This script will help you set up code signing for WindowSnap."
echo ""

# Step 1: Check for Apple Developer account
echo "Step 1: Checking Apple Developer account..."
echo ""
echo "Please do the following in Xcode:"
echo "  1. Open Xcode"
echo "  2. Xcode → Settings (⌘,)"
echo "  3. Click 'Accounts' tab"
echo "  4. Click '+' button"
echo "  5. Add your Apple ID (the one with Apple Developer plan)"
echo ""
read -p "Have you added your Apple Developer account? (y/n): " account_added

if [[ "$account_added" != "y" && "$account_added" != "Y" ]]; then
  echo ""
  echo "Please add your account first, then run this script again."
  exit 0
fi

# Step 2: Check for certificates
echo ""
echo "Step 2: Checking code signing certificates..."
echo ""

IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null | grep -E "(Developer ID|Apple Distribution|Mac Developer)" | wc -l | tr -d ' ')

if [[ "$IDENTITIES" -eq 0 ]]; then
  echo "⚠️  No signing certificates found"
  echo ""
  echo "Please create certificates in Xcode:"
  echo "  1. Xcode → Settings → Accounts"
  echo "  2. Select your Apple ID"
  echo "  3. Select your Team"
  echo "  4. Click 'Manage Certificates...'"
  echo "  5. Click '+' button"
  echo "  6. For outside App Store: Select 'Developer ID Application'"
  echo "  7. For App Store: Select 'Apple Distribution'"
  echo ""
  read -p "Have you created the certificates? (y/n): " certs_created
  
  if [[ "$certs_created" != "y" && "$certs_created" != "Y" ]]; then
    echo ""
    echo "Please create certificates first, then run this script again."
    exit 0
  fi
else
  echo "✅ Found $IDENTITIES signing certificate(s):"
  security find-identity -v -p codesigning 2>/dev/null | grep -E "(Developer ID|Apple Distribution|Mac Developer)" | head -3
fi

# Step 3: Find signing identity
echo ""
echo "Step 3: Finding your signing identity..."
echo ""

DEVELOPER_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
APPLE_DIST=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Distribution" | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [[ -n "$DEVELOPER_ID" ]]; then
  echo "✅ Developer ID Application found:"
  echo "   $DEVELOPER_ID"
  echo ""
  echo "This is for distribution OUTSIDE the App Store"
  echo ""
fi

if [[ -n "$APPLE_DIST" ]]; then
  echo "✅ Apple Distribution found:"
  echo "   $APPLE_DIST"
  echo ""
  echo "This is for App Store distribution"
  echo ""
fi

if [[ -z "$DEVELOPER_ID" && -z "$APPLE_DIST" ]]; then
  echo "❌ No valid signing identities found"
  echo "   Please create certificates in Xcode first"
  exit 1
fi

# Step 4: Choose distribution method
echo ""
echo "Step 4: Choose your distribution method"
echo ""
echo "1. Developer ID (outside App Store) - Recommended for WindowSnap"
echo "2. Apple Distribution (App Store)"
echo ""
read -p "Which do you want to use? (1 or 2): " dist_choice

if [[ "$dist_choice" == "1" ]]; then
  if [[ -z "$DEVELOPER_ID" ]]; then
    echo "❌ Developer ID certificate not found"
    echo "   Please create it in Xcode first"
    exit 1
  fi
  SIGNING_ID="$DEVELOPER_ID"
  DIST_TYPE="Developer ID"
elif [[ "$dist_choice" == "2" ]]; then
  if [[ -z "$APPLE_DIST" ]]; then
    echo "❌ Apple Distribution certificate not found"
    echo "   Please create it in Xcode first"
    exit 1
  fi
  SIGNING_ID="$APPLE_DIST"
  DIST_TYPE="Apple Distribution"
else
  echo "Invalid choice"
  exit 1
fi

# Step 5: Create environment setup file
echo ""
echo "Step 5: Creating signing configuration..."
echo ""

ENV_FILE="WindowSnap/.signing-env"
cat > "$ENV_FILE" <<EOF
# WindowSnap Code Signing Configuration
# Generated on $(date)
# 
# To use this configuration, run:
#   source WindowSnap/.signing-env
#   bash WindowSnap/scripts/build_bundle.sh

export CODESIGN_ID="$SIGNING_ID"
export DIST_TYPE="$DIST_TYPE"

# For notarization (optional, set up later):
# export NOTARY_PROFILE="windowsnap-notary"
EOF

echo "✅ Created signing configuration: $ENV_FILE"
echo ""
echo "Your signing identity:"
echo "  $SIGNING_ID"
echo ""

# Step 6: Instructions for Xcode project
echo "Step 6: Xcode Project Setup (Optional but Recommended)"
echo ""
echo "For full Xcode signing support, you have two options:"
echo ""
echo "Option A: Use command line signing (current setup)"
echo "  source WindowSnap/.signing-env"
echo "  bash WindowSnap/scripts/build_bundle.sh"
echo ""
echo "Option B: Create Xcode project for GUI signing"
echo "  1. File → New → Project"
echo "  2. macOS → App"
echo "  3. Configure with your team"
echo "  4. Add source files from WindowSnap/WindowSnap/"
echo "  5. Enable 'Automatically manage signing'"
echo ""

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. To build and sign from command line:"
echo "     source WindowSnap/.signing-env"
echo "     bash WindowSnap/scripts/build_bundle.sh"
echo ""
echo "  2. To sign and notarize (after setting up notary profile):"
echo "     source WindowSnap/.signing-env"
echo "     export NOTARY_PROFILE='your-profile-name'"
echo "     bash WindowSnap/scripts/sign-and-notarize.sh"
echo ""
echo "  3. To archive in Xcode:"
echo "     Create an Xcode project (see Option B above)"
echo "     Product → Archive"
echo "     Distribute App"



