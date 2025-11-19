#!/usr/bin/env bash
# Quick script to check if bundle ID is registered and show signing status

BUNDLE_ID="com.windowsnap.app"

echo "🔍 Checking Bundle ID Registration"
echo "=================================="
echo "Bundle ID: $BUNDLE_ID"
echo ""

# Check if signed in to Apple Developer
echo "1. Checking Apple Developer account..."
if xcrun altool --list-providers 2>/dev/null | grep -q "Provider"; then
  echo "   ✅ Apple Developer account configured"
else
  echo "   ⚠️  Apple Developer account not configured"
  echo "      Run: xcrun altool --store-type mac_app_store --apiKey YOUR_KEY --apiIssuer YOUR_ISSUER"
fi
echo ""

# Check code signing identities
echo "2. Checking code signing identities..."
IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null | grep -E "(Developer ID|Apple Distribution|Mac Developer)" | wc -l | tr -d ' ')
if [[ "$IDENTITIES" -gt 0 ]]; then
  echo "   ✅ Found $IDENTITIES signing identity/identities"
  security find-identity -v -p codesigning 2>/dev/null | grep -E "(Developer ID|Apple Distribution|Mac Developer)" | head -3
else
  echo "   ❌ No signing identities found"
  echo "      Add them in Xcode: Settings → Accounts → Manage Certificates"
fi
echo ""

# Check if we can verify bundle ID via Xcode
echo "3. To verify bundle ID registration:"
echo "   - Visit: https://developer.apple.com/account/resources/identifiers/list"
echo "   - Search for: $BUNDLE_ID"
echo "   - Or check in Xcode when you archive (it will show if registered)"
echo ""

# Check current app bundle if it exists
if [[ -d "dist/WindowSnap.app" ]]; then
  echo "4. Checking existing app bundle..."
  if codesign -dv "dist/WindowSnap.app" 2>&1 | grep -q "Authority"; then
    echo "   ✅ App is signed"
    codesign -dv "dist/WindowSnap.app" 2>&1 | grep -E "(Authority|Identifier)" | head -5
  else
    echo "   ⚠️  App is not signed"
  fi
fi

echo ""
echo "📝 Next Steps:"
echo "   1. Register bundle ID at: https://developer.apple.com/account/resources/identifiers/list"
echo "   2. Or let Xcode register it automatically when you enable signing"
echo "   3. Create certificates in Xcode: Settings → Accounts → Manage Certificates"
echo "   4. Re-archive in Xcode with proper signing"



