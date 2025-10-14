#!/bin/bash

# WindowSnap Clipboard History Feature Test
# Test script for the new clipboard history functionality

echo "🧪 TESTING CLIPBOARD HISTORY FEATURE"
echo "======================================"
echo ""

echo "📋 What this test does:"
echo "1. Copies different types of content to the clipboard"
echo "2. Launches WindowSnap to start monitoring"
echo "3. Provides instructions to test the clipboard history window"
echo ""

echo "⚡ Setting up test content..."

# Copy various types of content
echo "Hello World! This is a test string for clipboard history." | pbcopy
sleep 1

echo "https://www.apple.com" | pbcopy
sleep 1

echo "Multi-line text content
Line 2 of the clipboard test
Line 3 with special characters: @#$%^&*()" | pbcopy
sleep 1

echo "Short text" | pbcopy
sleep 1

echo "Another URL: https://github.com" | pbcopy
sleep 1

echo "Final test content with emojis 🚀📋✨" | pbcopy

echo ""
echo "✅ Test content has been copied to clipboard"
echo ""

echo "🚀 Starting WindowSnap..."
echo "   The app will begin monitoring clipboard changes"
echo ""

# Change to the WindowSnap directory and run
cd /Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap

# Build and run the app
swift run WindowSnap &
WINDOWSNAP_PID=$!

echo "   WindowSnap PID: $WINDOWSNAP_PID"
echo ""

echo "🧪 MANUAL TEST INSTRUCTIONS:"
echo "============================"
echo ""
echo "1. Wait for WindowSnap to fully load (look for status bar icon)"
echo "2. Try the clipboard history shortcuts:"
echo "   • Press ⌘⇧V to open clipboard history window"
echo "   • Use arrow keys to navigate through history"
echo "   • Press Enter to copy selected item"
echo "   • Press Escape to close the window"
echo ""
echo "3. Test from the status bar menu:"
echo "   • Click the WindowSnap icon in the menu bar"
echo "   • Select 'Clipboard History (⌘⇧V)'"
echo ""
echo "4. Test with new clipboard content:"
echo "   • Copy some new text: echo 'New test content' | pbcopy"
echo "   • Open clipboard history to see it was added"
echo ""
echo "5. Test search functionality:"
echo "   • Open clipboard history"
echo "   • Type in the search field to filter results"
echo ""

echo "Expected results:"
echo "• History window shows previous clipboard items"
echo "• Items display with type icons and timestamps"
echo "• Search filters items correctly"
echo "• Selecting and pressing Enter copies item back to clipboard"
echo "• Window closes after selection"
echo ""

echo "🔧 To stop WindowSnap: kill $WINDOWSNAP_PID"
echo ""

echo "Press any key to continue watching logs, or Ctrl+C to exit..."
read -n 1

echo ""
echo "📊 Watching WindowSnap logs:"
echo "============================"

# Wait for the app to run and show logs
wait $WINDOWSNAP_PID
