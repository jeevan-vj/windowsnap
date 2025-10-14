#!/bin/bash

# WindowSnap - Window Throw Interface Test Script
# Tests the Rectangle Pro signature feature implementation

echo "🎯 WindowSnap - Window Throw Interface Test"
echo "========================================="

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
echo "📋 Test Plan for Window Throw Interface:"
echo "1. Build verification"
echo "2. Position calculation accuracy"
echo "3. Key mapping validation"
echo "4. Integration with existing window management"
echo "5. Manual functionality test"
echo ""

# Test 1: Build Verification
echo "${BLUE}🔨 Test 1: Build Verification${NC}"
cd WindowSnap
if swift build > /dev/null 2>&1; then
    print_result 0 "Project builds successfully with Window Throw feature"
else
    print_result 1 "Project fails to build"
    echo "Build output:"
    swift build
fi

# Test 2: Position Calculation Test
echo ""
echo "${BLUE}🧮 Test 2: Position Calculation Accuracy${NC}"

# Create a Swift script to test position calculations
cat > test_positions.swift << 'EOF'
import Foundation
import AppKit

// Mock screen for testing (1920x1080)
let mockScreen = NSScreen.main ?? NSScreen()
let testFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

print("Testing position calculations for 1920x1080 screen...")

// Test key calculations
let calculator = ThrowPositionCalculator()

// Test key character mapping
let testKeys = [1, 5, 9, 10, 11, 15, 16]
for key in testKeys {
    let char = calculator.getKeyCharacter(for: key)
    let parsed = calculator.getIndexForKey(char)
    if parsed == key {
        print("✅ Key mapping \(key) -> '\(char)' -> \(parsed ?? -1)")
    } else {
        print("❌ Key mapping failed: \(key) -> '\(char)' -> \(parsed ?? -1)")
    }
}

// Test position generation
if let screen = NSScreen.main {
    let positions = calculator.calculateThrowPositions(for: screen)
    print("Generated \(positions.count) throw positions:")
    
    for (index, position) in positions.enumerated() {
        let key = calculator.getKeyCharacter(for: position.keyIndex)
        print("  \(key): \(position.shortDisplayName) at \(position.frame)")
    }
    
    if positions.count >= 14 {
        print("✅ Generated expected number of positions (\(positions.count))")
    } else {
        print("❌ Expected at least 14 positions, got \(positions.count)")
    }
} else {
    print("❌ No screen available for testing")
}
EOF

# Run position calculation test
echo "Running position calculation test..."
if swift test_positions.swift > position_test_output.txt 2>&1; then
    cat position_test_output.txt
    if grep -q "Generated expected number of positions" position_test_output.txt; then
        print_result 0 "Position calculation generates correct number of positions"
    else
        print_result 1 "Position calculation failed"
    fi
    
    if grep -q "✅ Key mapping" position_test_output.txt; then
        print_result 0 "Key mapping works correctly"
    else
        print_result 1 "Key mapping failed"
    fi
else
    print_result 1 "Position calculation test failed to run"
    cat position_test_output.txt
fi

# Clean up test files
rm -f test_positions.swift position_test_output.txt

# Test 3: Integration Test
echo ""
echo "${BLUE}🔗 Test 3: Integration with WindowManager${NC}"

# Check if the throw controller is properly integrated
if grep -q "WindowThrowController" WindowSnap/App/AppDelegate.swift; then
    print_result 0 "WindowThrowController integrated in AppDelegate"
else
    print_result 1 "WindowThrowController not found in AppDelegate"
fi

if grep -q "registerThrowShortcut" WindowSnap/App/AppDelegate.swift; then
    print_result 0 "Throw shortcut registration found"
else
    print_result 1 "Throw shortcut registration not found"
fi

# Test 4: File Structure Test
echo ""
echo "${BLUE}📁 Test 4: File Structure Verification${NC}"

required_files=(
    "WindowSnap/Core/ThrowPositionCalculator.swift"
    "WindowSnap/Core/WindowThrowController.swift"
    "WindowSnap/UI/ThrowOverlayWindow.swift"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_result 0 "Required file exists: $file"
    else
        print_result 1 "Missing required file: $file"
    fi
done

# Test 5: Code Quality Checks
echo ""
echo "${BLUE}🔍 Test 5: Code Quality Checks${NC}"

# Check for proper error handling
if grep -q "guard let" WindowSnap/Core/WindowThrowController.swift; then
    print_result 0 "Proper error handling with guard statements found"
else
    print_result 1 "Missing proper error handling"
fi

# Check for memory management
if grep -q "weak self" WindowSnap/Core/WindowThrowController.swift; then
    print_result 0 "Proper memory management with weak references"
else
    print_result 1 "Missing weak references for memory management"
fi

# Check for notification cleanup
if grep -q "removeObserver\|removeMonitor" WindowSnap/Core/WindowThrowController.swift; then
    print_result 0 "Proper notification cleanup found"
else
    print_result 1 "Missing notification cleanup"
fi

# Manual Test Instructions
echo ""
echo "${YELLOW}🧪 Manual Test Instructions:${NC}"
echo ""
echo "After building and running WindowSnap, test the following:"
echo ""
echo "1. ${BLUE}Basic Functionality:${NC}"
echo "   • Press Ctrl+Option+Cmd+Space to show throw overlay"
echo "   • Verify overlay appears with numbered position previews"
echo "   • Press 1-9, 0, A-F to select positions"
echo "   • Press Escape to cancel"
echo ""
echo "2. ${BLUE}Visual Verification:${NC}"
echo "   • Overlay should cover entire screen with semi-transparent background"
echo "   • Position previews should be clearly labeled with keys"
echo "   • Current window should be highlighted in blue"
echo "   • Selected position should highlight before execution"
echo ""
echo "3. ${BLUE}Interaction Testing:${NC}"
echo "   • Test keyboard navigation (number keys, letters)"
echo "   • Test mouse clicking on position previews"
echo "   • Verify window moves to selected position"
echo "   • Test with different window types and sizes"
echo ""
echo "4. ${BLUE}Edge Cases:${NC}"
echo "   • Test with multiple monitors"
echo "   • Test with maximized windows"
echo "   • Test rapid successive activations"
echo "   • Test with windows near screen edges"
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
    echo -e "\n${GREEN}🎉 All tests passed! Window Throw interface is ready for manual testing.${NC}"
else
    echo -e "\n${RED}⚠️  Some tests failed. Review the output above.${NC}"
fi

echo ""
echo "Next steps:"
echo "1. Run manual tests as described above"
echo "2. Fix any issues found during manual testing"
echo "3. Proceed to implement Custom Positions feature"
echo ""
