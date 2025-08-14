#!/bin/bash

echo "🧪 WindowSnap Sleep/Wake Test Script"
echo "===================================="
echo ""

echo "This script will test WindowSnap's sleep/wake recovery functionality."
echo ""
echo "Test Steps:"
echo "1. First, test that WindowSnap shortcuts work (try Cmd+Shift+Left)"
echo "2. Put your Mac to sleep manually:"
echo "   - Close laptop lid, OR"
echo "   - Apple menu > Sleep, OR" 
echo "   - Press power button briefly and select Sleep"
echo "3. Wait at least 30 seconds"
echo "4. Wake your Mac up"
echo "5. Wait 2-3 seconds for reinitialization"
echo "6. Test shortcuts again - they should work!"
echo ""

echo "To see detailed logs, open Console.app and search for 'WindowSnap'"
echo ""

echo "🔍 Current WindowSnap status:"
if pgrep -x "WindowSnap" > /dev/null; then
    echo "✅ WindowSnap is running (PID: $(pgrep -x 'WindowSnap'))"
else
    echo "❌ WindowSnap is not running"
    echo "   Launch it from Applications folder or run:"
    echo "   open /Applications/WindowSnap.app"
    exit 1
fi

echo ""
echo "🧠 Testing basic functionality:"
echo "   Try these shortcuts to verify WindowSnap is working:"
echo "   • Cmd+Shift+Left  - Snap window to left half"
echo "   • Cmd+Shift+Right - Snap window to right half"
echo "   • Cmd+Shift+Up    - Maximize window"
echo ""

read -p "Press Enter after testing shortcuts..."

echo ""
echo "📝 What to look for after sleep/wake:"
echo "   • Shortcuts should work immediately after wake"
echo "   • No need to restart WindowSnap manually"
echo "   • Health check runs every 30 seconds automatically"
echo ""

echo "🔧 If shortcuts don't work after wake:"
echo "   1. Wait 5 seconds and try again (may need extra time)"
echo "   2. Check Console.app for WindowSnap messages"
echo "   3. Verify accessibility permissions in System Preferences"
echo ""

echo "✅ Test script complete!"
echo "   WindowSnap should now automatically recover from sleep/wake cycles."
