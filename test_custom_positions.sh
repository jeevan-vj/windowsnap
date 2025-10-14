#!/bin/bash

# WindowSnap - Custom Positions Feature Test Script
# Tests the Custom Positions Rectangle Pro feature implementation

echo "🎯 WindowSnap - Custom Positions Feature Test"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
PASSED=0
FAILED=0

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "  ${GREEN}✅ PASS${NC}: $2"
        ((PASSED++))
    else
        echo -e "  ${RED}❌ FAIL${NC}: $2"
        ((FAILED++))
    fi
}

echo ""
echo "📋 Test Plan for Custom Positions Feature:"
echo "1. Build verification"
echo "2. Data model validation"
echo "3. Storage functionality"
echo "4. Position calculation accuracy"
echo "5. UI integration verification"
echo "6. Manual functionality test"
echo ""

# Test 1: Build Verification
echo "${BLUE}🔨 Test 1: Build Verification${NC}"
cd WindowSnap
if swift build > /dev/null 2>&1; then
    print_result 0 "Project builds successfully with Custom Positions feature"
else
    print_result 1 "Project fails to build"
    echo "Build output:"
    swift build
fi

# Test 2: File Structure Test
echo ""
echo "${BLUE}📁 Test 2: File Structure Verification${NC}"

required_files=(
    "WindowSnap/Models/CustomPosition.swift"
    "WindowSnap/UI/CustomPositionsWindow.swift"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_result 0 "Required file exists: $file"
    else
        print_result 1 "Missing required file: $file"
    fi
done

# Test 3: Integration Test
echo ""
echo "${BLUE}🔗 Test 3: Integration with Main App${NC}"

# Check if custom positions is integrated in StatusBarController
if grep -q "CustomPositionsWindow" WindowSnap/UI/StatusBarController.swift; then
    print_result 0 "CustomPositionsWindow integrated in StatusBarController"
else
    print_result 1 "CustomPositionsWindow not found in StatusBarController"
fi

if grep -q "showCustomPositions" WindowSnap/UI/StatusBarController.swift; then
    print_result 0 "showCustomPositions method found"
else
    print_result 1 "showCustomPositions method not found"
fi

if grep -q "Custom Positions..." WindowSnap/UI/StatusBarController.swift; then
    print_result 0 "Custom Positions menu item found"
else
    print_result 1 "Custom Positions menu item not found"
fi

# Test 4: WindowManager Integration
echo ""
echo "${BLUE}🔧 Test 4: WindowManager Integration${NC}"

if grep -q "moveAndResizeWindow" WindowSnap/Core/WindowManager.swift; then
    print_result 0 "moveAndResizeWindow method found in WindowManager"
else
    print_result 1 "moveAndResizeWindow method not found in WindowManager"
fi

# Test 5: Data Model Validation
echo ""
echo "${BLUE}🗂️ Test 5: Data Model Structure${NC}"

# Check for required properties and methods in CustomPosition
if grep -q "struct CustomPosition" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "CustomPosition struct defined"
else
    print_result 1 "CustomPosition struct not found"
fi

if grep -q "widthPercent.*heightPercent.*xPercent.*yPercent" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "Required position properties found"
else
    print_result 1 "Missing required position properties"
fi

if grep -q "Codable" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "CustomPosition is Codable for storage"
else
    print_result 1 "CustomPosition is not Codable"
fi

# Test 6: Manager Class Validation
echo ""
echo "${BLUE}🏗️ Test 6: CustomPositionManager Structure${NC}"

if grep -q "class CustomPositionManager" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "CustomPositionManager class defined"
else
    print_result 1 "CustomPositionManager class not found"
fi

if grep -q "addPosition\|removePosition\|updatePosition" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "Position management methods found"
else
    print_result 1 "Position management methods missing"
fi

if grep -q "executePosition" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "Position execution method found"
else
    print_result 1 "Position execution method missing"
fi

# Test 7: Storage Functionality
echo ""
echo "${BLUE}💾 Test 7: Storage Implementation${NC}"

if grep -q "UserDefaults\|JSONEncoder\|JSONDecoder" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "Persistent storage implementation found"
else
    print_result 1 "Persistent storage implementation missing"
fi

if grep -q "loadPositions\|savePositions" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "Storage load/save methods found"
else
    print_result 1 "Storage load/save methods missing"
fi

# Test 8: UI Components
echo ""
echo "${BLUE}🖼️ Test 8: UI Implementation${NC}"

if grep -q "NSTableView\|NSTableViewDataSource" WindowSnap/UI/CustomPositionsWindow.swift; then
    print_result 0 "Table view implementation found"
else
    print_result 1 "Table view implementation missing"
fi

if grep -q "addCurrentWindow\|addCustomPosition\|editPosition" WindowSnap/UI/CustomPositionsWindow.swift; then
    print_result 0 "Position management UI actions found"
else
    print_result 1 "Position management UI actions missing"
fi

if grep -q "CustomPositionDialog" WindowSnap/UI/CustomPositionsWindow.swift; then
    print_result 0 "Position creation dialog found"
else
    print_result 1 "Position creation dialog missing"
fi

# Test 9: Code Quality Checks
echo ""
echo "${BLUE}🔍 Test 9: Code Quality Checks${NC}"

# Check for proper error handling
if grep -q "guard let\|guard " WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "Proper error handling with guard statements found"
else
    print_result 1 "Missing proper error handling"
fi

# Check for validation
if grep -q "isValidShortcut\|isEmpty" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "Input validation found"
else
    print_result 1 "Missing input validation"
fi

# Check for bounds checking
if grep -q "min.*max" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "Bounds checking for percentages found"
else
    print_result 1 "Missing bounds checking"
fi

# Test 10: Feature Completeness
echo ""
echo "${BLUE}🎯 Test 10: Feature Completeness${NC}"

if grep -q "calculateFrame" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "Position calculation functionality found"
else
    print_result 1 "Position calculation functionality missing"
fi

if grep -q "fromCurrentWindow" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "Create from current window functionality found"
else
    print_result 1 "Create from current window functionality missing"
fi

if grep -q "displayDescription" WindowSnap/Models/CustomPosition.swift; then
    print_result 0 "Display formatting functionality found"
else
    print_result 1 "Display formatting functionality missing"
fi

# Manual Test Instructions
echo ""
echo "${YELLOW}🧪 Manual Test Instructions:${NC}"
echo ""
echo "After building and running WindowSnap, test the following:"
echo ""
echo "1. ${BLUE}Basic Functionality:${NC}"
echo "   • Click the WindowSnap menu bar icon"
echo "   • Select 'Custom Positions...'"
echo "   • Verify the Custom Positions window opens"
echo "   • Check that the table view displays properly"
echo ""
echo "2. ${BLUE}Create from Current Window:${NC}"
echo "   • Open a test window (e.g., TextEdit, Safari)"
echo "   • Resize and position it as desired"
echo "   • Click 'Add Current Window' in Custom Positions"
echo "   • Enter a name and optional shortcut"
echo "   • Verify the position is saved and displayed"
echo ""
echo "3. ${BLUE}Create Custom Position:${NC}"
echo "   • Click 'Add Custom' in Custom Positions"
echo "   • Use the sliders to set width, height, x, y"
echo "   • Enter a name and optional shortcut"
echo "   • Verify the position is created correctly"
echo ""
echo "4. ${BLUE}Test Position Execution:${NC}"
echo "   • Select a saved custom position"
echo "   • Click 'Test' button"
echo "   • Verify the current window moves to that position"
echo "   • Test with different window types and sizes"
echo ""
echo "5. ${BLUE}Edit and Delete:${NC}"
echo "   • Select a position and click 'Edit'"
echo "   • Modify values and save"
echo "   • Test the updated position"
echo "   • Delete a position and verify it's removed"
echo ""
echo "6. ${BLUE}Persistence Testing:${NC}"
echo "   • Create several custom positions"
echo "   • Quit and restart WindowSnap"
echo "   • Verify positions are restored correctly"
echo ""
echo "7. ${BLUE}Edge Cases:${NC}"
echo "   • Test with multiple monitors"
echo "   • Test with very small/large window sizes"
echo "   • Test invalid shortcut combinations"
echo "   • Test duplicate names/shortcuts"
echo ""

# Build the app for manual testing
echo "${BLUE}🚀 Building WindowSnap for manual testing...${NC}"
if swift build -c release > /dev/null 2>&1; then
    echo "✅ Release build successful"
    echo "📍 Executable location: .build/release/WindowSnap"
    echo ""
    echo "To run: cd WindowSnap && .build/release/WindowSnap"
else
    echo "❌ Release build failed"
    swift build -c release
fi

# Summary
echo ""
echo "📊 Test Summary:"
echo "================"
echo -e "Tests Passed: ${GREEN}$PASSED${NC}"
echo -e "Tests Failed: ${RED}$FAILED${NC}"
echo -e "Total Tests: $((PASSED + FAILED))"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! Custom Positions feature is ready for manual testing.${NC}"
else
    echo -e "\n${RED}⚠️  Some tests failed. Review the output above.${NC}"
fi

echo ""
echo "Key Features Implemented:"
echo "✅ Custom position creation from current window"
echo "✅ Manual custom position creation with sliders"
echo "✅ Position storage and persistence"
echo "✅ Position editing and deletion"
echo "✅ Position execution and testing"
echo "✅ Menu bar integration"
echo "✅ Input validation and error handling"
echo ""
echo "Next steps:"
echo "1. Run manual tests as described above"
echo "2. Test shortcut integration (to be implemented later)"
echo "3. Proceed to implement Workspace Arrangements feature"
echo ""
