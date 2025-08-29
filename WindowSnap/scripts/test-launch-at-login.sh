#!/bin/bash

# Quick build and run script for testing WindowSnap with launch at login
echo "🚀 Building and running WindowSnap for launch at login testing..."

cd /Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap

# Build the project
echo "📦 Building..."
swift build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"
echo ""
echo "🎯 To test the launch at login feature:"
echo "  1. Run: swift run"
echo "  2. Click the menu bar icon"
echo "  3. Open Preferences"
echo "  4. Toggle 'Launch WindowSnap at login'"
echo "  5. Test by logging out/in or restarting"
echo ""
echo "🔍 Manual verification:"
echo "  - Check System Preferences > General > Login Items"
echo "  - Look for 'WindowSnap' in the list"
echo ""

# Ask if user wants to run the app
read -p "Do you want to run WindowSnap now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Starting WindowSnap..."
    swift run
fi
