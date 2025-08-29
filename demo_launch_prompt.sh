#!/bin/bash

# Demo script for Launch at Login Prompt functionality
echo "🎭 WindowSnap Launch at Login Prompt Demo"
echo "========================================"
echo ""

# Navigate to project directory
cd /Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap

echo "📦 Building WindowSnap with prompt functionality..."
swift build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"
echo ""

echo "🎯 Launch at Login Prompt Features:"
echo ""
echo "📋 What's Been Implemented:"
echo "  ✅ First-run detection"
echo "  ✅ Smart prompt timing (1.5s delay after app launch)"
echo "  ✅ User-friendly dialog with 3 options:"
echo "      • Yes, Start Automatically"
echo "      • No, Don't Auto-Start"  
echo "      • Decide Later"
echo "  ✅ Proper error handling"
echo "  ✅ Integration with preferences system"
echo "  ✅ One-time prompt (won't show again)"
echo "  ✅ Direct link to preferences for later configuration"
echo ""

echo "🎨 User Experience Flow:"
echo "  1. User launches WindowSnap for the first time"
echo "  2. App loads completely (1.5 second delay)"
echo "  3. Friendly prompt appears asking about auto-start"
echo "  4. User chooses one of three options:"
echo "     • Enable: Sets up launch at login immediately"
echo "     • Disable: Respects user choice, shows confirmation"
echo "     • Later: Shows how to access preferences later"
echo "  5. Choice is remembered, prompt won't show again"
echo ""

echo "🧪 Testing Scenarios:"
echo ""
echo "Scenario 1: Simulate First Run"
echo "  - Delete app preferences to simulate first run"
echo "  - Launch app and see the prompt"
echo ""

echo "Scenario 2: Test Enable Auto-Start"
echo "  - Choose 'Yes, Start Automatically'"
echo "  - Verify launch at login is enabled"
echo ""

echo "Scenario 3: Test Decline Auto-Start"
echo "  - Choose 'No, Don't Auto-Start'"
echo "  - Verify setting remains disabled"
echo ""

echo "Scenario 4: Test Decide Later"
echo "  - Choose 'Decide Later'"
echo "  - See how to access preferences"
echo ""

echo "💡 To test the prompt functionality:"
echo ""
echo "1. Reset first-run state:"
echo "   defaults delete com.windowsnap.app"
echo ""
echo "2. Run the app:"
echo "   swift run"
echo ""
echo "3. The prompt should appear after ~1.5 seconds"
echo ""

echo "🔧 Manual Testing Commands:"
echo ""
echo "# Reset app preferences (simulates first run)"
echo "defaults delete com.windowsnap.app"
echo ""
echo "# Check current launch at login status"  
echo "defaults read com.windowsnap.app LaunchAtLogin 2>/dev/null || echo 'Not set'"
echo ""
echo "# Check if prompt has been shown"
echo "defaults read com.windowsnap.app HasShownLaunchAtLoginPrompt 2>/dev/null || echo 'Not set'"
echo ""

# Ask if user wants to reset and test
read -p "Do you want to reset preferences and test the prompt? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔄 Resetting app preferences to simulate first run..."
    defaults delete com.windowsnap.app 2>/dev/null || echo "No existing preferences found"
    
    echo ""
    echo "🚀 Starting WindowSnap - watch for the prompt!"
    echo "   (The prompt will appear ~1.5 seconds after startup)"
    echo ""
    echo "Press Ctrl+C to stop the app after testing"
    echo ""
    
    swift run
fi

echo ""
echo "✅ Launch at Login Prompt demo complete!"
