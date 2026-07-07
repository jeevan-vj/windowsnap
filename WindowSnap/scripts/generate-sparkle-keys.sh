#!/usr/bin/env bash
set -euo pipefail

# Generate EDSA keys for Sparkle update signing
# Keys will be saved to ~/.sparkle_dsa_priv.pem and ~/.sparkle_dsa_pub.pem
#
# Usage: ./generate-sparkle-keys.sh

echo "🔑 Generating Sparkle update signing keys..."

# Find Sparkle tools (they're in Caskroom, not in PATH)
SPARKLE_BIN=""
if command -v generate_keys &> /dev/null; then
  SPARKLE_BIN=""
  GENERATE_KEYS="generate_keys"
elif [[ -d "/usr/local/Caskroom/sparkle" ]]; then
  # Find the latest version
  SPARKLE_VERSION=$(ls -t /usr/local/Caskroom/sparkle 2>/dev/null | grep -v metadata | head -1)
  if [[ -n "$SPARKLE_VERSION" ]] && [[ -f "/usr/local/Caskroom/sparkle/$SPARKLE_VERSION/bin/generate_keys" ]]; then
    SPARKLE_BIN="/usr/local/Caskroom/sparkle/$SPARKLE_VERSION/bin"
    GENERATE_KEYS="$SPARKLE_BIN/generate_keys"
  fi
elif [[ -d "/opt/homebrew/Caskroom/sparkle" ]]; then
  # Apple Silicon Mac
  SPARKLE_VERSION=$(ls -t /opt/homebrew/Caskroom/sparkle 2>/dev/null | grep -v metadata | head -1)
  if [[ -n "$SPARKLE_VERSION" ]] && [[ -f "/opt/homebrew/Caskroom/sparkle/$SPARKLE_VERSION/bin/generate_keys" ]]; then
    SPARKLE_BIN="/opt/homebrew/Caskroom/sparkle/$SPARKLE_VERSION/bin"
    GENERATE_KEYS="$SPARKLE_BIN/generate_keys"
  fi
fi

if [[ -z "$GENERATE_KEYS" ]] || [[ ! -f "$GENERATE_KEYS" ]]; then
  echo "❌ generate_keys not found"
  echo "   Install Sparkle tools: brew install sparkle"
  exit 1
fi

KEY_DIR="$HOME"
PRIVATE_KEY="$KEY_DIR/.sparkle_dsa_priv.pem"
PUBLIC_KEY="$KEY_DIR/.sparkle_dsa_pub.pem"

if [[ -f "$PRIVATE_KEY" ]]; then
  echo "⚠️  Keys already exist at $PRIVATE_KEY"
  read -p "Overwrite? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Skipping key generation."
    exit 0
  fi
fi

echo "Generating keys..."
"$GENERATE_KEYS" "$PRIVATE_KEY"

# Extract public key (try both DSA and EC formats)
if openssl dsa -in "$PRIVATE_KEY" -pubout -out "$PUBLIC_KEY" 2>/dev/null; then
  echo "✅ DSA keys generated"
elif openssl ec -in "$PRIVATE_KEY" -pubout -out "$PUBLIC_KEY" 2>/dev/null; then
  echo "✅ EC keys generated"
else
  echo "⚠️  Could not extract public key automatically"
  echo "   Please extract manually and add to Info.plist"
  exit 1
fi

echo ""
echo "✅ Keys generated successfully!"
echo ""
echo "📁 Private key: $PRIVATE_KEY (KEEP SECRET - DO NOT COMMIT!)"
echo "📁 Public key:  $PUBLIC_KEY"
echo ""
echo "📋 Add the public key to Info.plist as SUPublicEDSAKey:"
echo ""
PUBLIC_KEY_CONTENT=$(cat "$PUBLIC_KEY" | grep -v "BEGIN\|END" | tr -d '\n' | tr -d ' ')
echo "$PUBLIC_KEY_CONTENT"
echo ""
echo "💡 Set environment variable for appcast generation:"
echo "   export SPARKLE_PRIVATE_KEY=\"$PRIVATE_KEY\""
echo ""

