#!/usr/bin/env bash
set -euo pipefail

# Icon generator script for WindowSnap
# Converts SVG to required PNG sizes or creates a simple icon

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS_DIR="$ROOT_DIR/WindowSnap/App/Assets.xcassets"
ICON_SET_DIR="$ASSETS_DIR/AppIcon.appiconset"
SVG_FILE="$ASSETS_DIR/IconConcept.svg"

echo "🎨 Generating app icons..."

# Icon sizes needed for macOS
declare -a ICON_FILES=(
    "icon_16x16.png:16"
    "icon_16x16@2x.png:32"
    "icon_32x32.png:32"
    "icon_32x32@2x.png:64"
    "icon_128x128.png:128"
    "icon_128x128@2x.png:256"
    "icon_256x256.png:256"
    "icon_256x256@2x.png:512"
    "icon_512x512.png:512"
    "icon_512x512@2x.png:1024"
)

# Function to create a simple colored icon using sips
create_simple_icon() {
    local size=$1
    local output_file=$2
    
    # Create a temporary simple icon using built-in tools
    # This creates a blue square with rounded corners as a placeholder
    cat > "/tmp/icon_${size}.svg" <<EOF
<svg width="${size}" height="${size}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#007AFF;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#5856D6;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="${size}" height="${size}" rx="$((size/8))" ry="$((size/8))" fill="url(#grad)"/>
  <text x="50%" y="50%" font-family="SF Pro Display, Helvetica, Arial" font-size="$((size/3))" font-weight="bold" fill="white" text-anchor="middle" dominant-baseline="central">WS</text>
</svg>
EOF
    
    # Convert SVG to PNG if rsvg-convert is available
    if command -v rsvg-convert >/dev/null 2>&1; then
        rsvg-convert -w "$size" -h "$size" "/tmp/icon_${size}.svg" -o "$output_file"
    elif command -v qlmanage >/dev/null 2>&1; then
        # Try using qlmanage (built into macOS)
        qlmanage -t -s "$size" -o "/tmp/" "/tmp/icon_${size}.svg" >/dev/null 2>&1 || true
        if [[ -f "/tmp/icon_${size}.svg.png" ]]; then
            mv "/tmp/icon_${size}.svg.png" "$output_file"
        else
            echo "⚠️  Could not generate $output_file - using placeholder"
            # Create a minimal 1x1 PNG as last resort
            echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > "$output_file"
        fi
    else
        echo "⚠️  No SVG converter found - creating minimal PNG for $output_file"
        # Create a minimal 1x1 PNG as fallback
        echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==" | base64 -d > "$output_file"
    fi
    
    rm -f "/tmp/icon_${size}.svg"
}

# Check if SVG exists and try to use it
if [[ -f "$SVG_FILE" ]] && command -v rsvg-convert >/dev/null 2>&1; then
    echo "📁 Found SVG file, converting to PNG icons..."
    for icon_entry in "${ICON_FILES[@]}"; do
        filename="${icon_entry%%:*}"
        size="${icon_entry##*:}"
        output_file="$ICON_SET_DIR/$filename"
        echo "   Creating $filename (${size}x${size})"
        rsvg-convert -w "$size" -h "$size" "$SVG_FILE" -o "$output_file"
    done
else
    echo "📦 Creating placeholder icons..."
    if [[ ! -f "$SVG_FILE" ]]; then
        echo "   (SVG file not found at $SVG_FILE)"
    else
        echo "   (rsvg-convert not available - install with 'brew install librsvg')"
    fi
    
    for icon_entry in "${ICON_FILES[@]}"; do
        filename="${icon_entry%%:*}"
        size="${icon_entry##*:}"
        output_file="$ICON_SET_DIR/$filename"
        echo "   Creating $filename (${size}x${size})"
        create_simple_icon "$size" "$output_file"
    done
fi

echo "✅ Icon generation complete!"
echo "   Icons created in: $ICON_SET_DIR"
echo ""
echo "💡 To use a custom icon:"
echo "   1. Place your icon SVG file at: $SVG_FILE"
echo "   2. Install rsvg-convert: brew install librsvg"
echo "   3. Run this script again"
