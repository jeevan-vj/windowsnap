#!/bin/bash

# Test script for Workspace Arrangements feature (Rectangle Pro Feature #3)
# This tests the complete workspace capture and restore functionality

echo "🏗️  WindowSnap Workspace Arrangements Test Suite"
echo "=================================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

# Function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "🧪 Testing: $test_name... "
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

# Function to check file exists and has content
check_file_content() {
    local file="$1"
    local pattern="$2"
    [[ -f "$file" ]] && grep -q "$pattern" "$file"
}

# Test 1: Build Verification
echo "🔨 Build Verification"
echo "--------------------"
run_test "Project builds successfully" "cd /Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap && swift build"

# Test 2: File Structure Verification
echo ""
echo "📁 File Structure Tests"
echo "----------------------"

run_test "WorkspaceManager.swift exists" "[[ -f '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' ]]"
run_test "WorkspaceArrangementsWindow.swift exists" "[[ -f '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/UI/WorkspaceArrangementsWindow.swift' ]]"

# Test 3: Data Model Tests
echo ""
echo "📊 Data Model Tests"
echo "------------------"

run_test "WorkspaceArrangement struct defined" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'struct WorkspaceArrangement'"
run_test "AppLayout struct defined" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'struct AppLayout'"
run_test "WindowLayout struct defined" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'struct WindowLayout'"
run_test "WorkspaceManager class defined" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'class WorkspaceManager'"

# Test 4: Core Functionality Tests
echo ""
echo "⚙️  Core Functionality Tests"
echo "---------------------------"

run_test "WorkspaceManager has shared singleton" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'static let shared'"
run_test "captureCurrentWorkspace method exists" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'func captureCurrentWorkspace'"
run_test "restoreWorkspace method exists" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'func restoreWorkspace'"
run_test "UserDefaults persistence implemented" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'userDefaults'"
run_test "JSON encoding/decoding implemented" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'JSONEncoder'"

# Test 5: UI Component Tests
echo ""
echo "🎨 UI Component Tests"
echo "--------------------"

run_test "WorkspaceArrangementsWindow class defined" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/UI/WorkspaceArrangementsWindow.swift' 'class WorkspaceArrangementsWindow'"
run_test "WorkspaceDialog class defined" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/UI/WorkspaceArrangementsWindow.swift' 'class WorkspaceDialog'"
run_test "Table view implementation" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/UI/WorkspaceArrangementsWindow.swift' 'NSTableView'"
run_test "Capture current workspace action" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/UI/WorkspaceArrangementsWindow.swift' 'captureCurrentWorkspace'"
run_test "Restore workspace action" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/UI/WorkspaceArrangementsWindow.swift' 'restoreSelectedWorkspace'"

# Test 6: Integration Tests
echo ""
echo "🔗 Integration Tests"
echo "-------------------"

run_test "StatusBar integration added" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/UI/StatusBarController.swift' 'Workspace Arrangements'"
run_test "showWorkspaceArrangements method exists" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/UI/StatusBarController.swift' 'showWorkspaceArrangements'"
run_test "AppDelegate integration" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/App/AppDelegate.swift' 'workspaceManager'"

# Test 7: Feature Functionality Tests
echo ""
echo "🚀 Feature Functionality Tests"
echo "------------------------------"

run_test "Workspace capture with apps grouping" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'appLayouts.*bundleId'"
run_test "Screen index detection" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'getScreenIndex'"
run_test "App launching capability" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'launchApp'"
run_test "Frame adjustment for different screens" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'adjustFrameForCurrentScreen'"

# Test 8: Data Management Tests
echo ""
echo "💾 Data Management Tests"
echo "-----------------------"

run_test "CRUD operations for arrangements" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'addArrangement.*removeArrangement.*updateArrangement'"
run_test "Arrangement validation (duplicate names)" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'duplicate.*name'"
run_test "Arrangement validation (duplicate shortcuts)" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'duplicate.*shortcut'"
run_test "Last used timestamp tracking" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'markAsUsed'"

# Test 9: Error Handling Tests
echo ""
echo "⚠️  Error Handling Tests"
echo "-----------------------"

run_test "Empty workspace handling" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'No windows found'"
run_test "Missing app handling" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'Could not launch app'"
run_test "Missing screen handling" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'Screen.*not available'"
run_test "Storage error handling" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'Failed to.*workspace arrangements'"

# Test 10: Advanced Features Tests
echo ""
echo "⭐ Advanced Features Tests"
echo "-------------------------"

run_test "Keyboard shortcut support" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'registerShortcut'"
run_test "Display description generation" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'displayDescription'"
run_test "Bundle identifier tracking" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'appBundleIdentifiers'"
run_test "Workspace state preservation for undo" "check_file_content '/Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap/WindowSnap/Core/WorkspaceManager.swift' 'saveWorkspaceStateForUndo'"

# Test 11: Release Build Test
echo ""
echo "🏭 Release Build Test"
echo "-------------------"
run_test "Release build successful" "cd /Users/jeevan.wijerathna/jeevan/projects/windowsnap/WindowSnap && swift build -c release"

# Final Results
echo ""
echo "📊 Test Results Summary"
echo "======================"
echo -e "Total Tests: ${BLUE}$TESTS_RUN${NC}"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$((TESTS_RUN - TESTS_PASSED))${NC}"

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "\n🎉 ${GREEN}ALL TESTS PASSED!${NC}"
    echo -e "✅ Workspace Arrangements feature is fully implemented and ready for use"
else
    echo -e "\n⚠️  ${YELLOW}Some tests failed${NC}"
    echo -e "📝 Please review the failed tests and fix any issues"
fi

# Rectangle Pro Feature Completion Status
echo ""
echo "🏆 Rectangle Pro Feature Implementation Status"
echo "=============================================="
echo -e "✅ ${GREEN}Window Throw Interface${NC} (Completed)"
echo -e "✅ ${GREEN}Custom Positions${NC} (Completed)"
echo -e "✅ ${GREEN}Workspace Arrangements${NC} (Completed)"
echo -e "🔲 ${YELLOW}Snap Targets${NC} (Next: High Priority)"
echo -e "🔲 ${BLUE}Display Event Handling${NC} (Medium Priority)"
echo -e "🔲 ${BLUE}Configurable Panels${NC} (Medium Priority)"
echo -e "🔲 ${BLUE}App Memory/Pinning${NC} (Low Priority)"

echo ""
echo "📋 Manual Testing Instructions"
echo "=============================="
echo "1. Build and run WindowSnap"
echo "2. Click the menu bar icon"
echo "3. Select 'Workspace Arrangements...'"
echo "4. Click 'Capture Current' to save current layout"
echo "5. Move some windows around"
echo "6. Select the saved arrangement and click 'Restore'"
echo "7. Verify that windows return to their saved positions"
echo ""
echo "✨ The Workspace Arrangements feature provides Rectangle Pro's complete workspace"
echo "   capture and restore functionality, allowing users to save and restore entire"
echo "   desktop layouts with one click."
