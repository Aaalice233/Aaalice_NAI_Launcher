#!/bin/bash

# Performance Testing Script for TagView
# Tests performance with 100+ tags

set -e

echo "================================"
echo "TagView Performance Testing"
echo "================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASS=0
FAIL=0

# Function to print colored output
print_pass() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASS++))
}

print_fail() {
    echo -e "${RED}✗ $1${NC}"
    ((FAIL++))
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if we're in the correct directory
if [ ! -f "pubspec.yaml" ]; then
    print_fail "pubspec.yaml not found. Please run from project root."
    exit 1
fi

print_info "Running from project root: $(pwd)"
echo ""

# ============================================
# Step 1: Code Analysis
# ============================================
echo "Step 1: Code Analysis"
echo "---------------------"

print_info "Running flutter analyze..."
if flutter analyze --no-pub > /dev/null 2>&1; then
    print_pass "Code analysis passed"
else
    print_fail "Code analysis failed"
    echo "Run 'flutter analyze' to see issues"
fi

echo ""

# ============================================
# Step 2: Automated Performance Tests
# ============================================
echo "Step 2: Automated Performance Tests"
echo "------------------------------------"

print_info "Running performance test suite..."

if flutter test test/widgets/prompt/tag_view_performance_test.dart; then
    print_pass "All automated performance tests passed"
else
    print_fail "Some performance tests failed"
fi

echo ""

# ============================================
# Step 3: Check Test Coverage
# ============================================
echo "Step 3: Test Coverage"
echo "--------------------"

print_info "Running tests with coverage..."

flutter test --coverage test/widgets/prompt/tag_view_performance_test.dart > /dev/null 2>&1

if [ -f "coverage/lcov.info" ]; then
    print_pass "Coverage report generated: coverage/lcov.info"

    # Extract coverage percentage for performance test file
    COVERAGE=$(grep "tag_view_performance_test.dart" coverage/lcov.info | head -1 | sed 's/.*://;s/%.*//' || echo "N/A")
    print_info "Performance test file coverage: ${COVERAGE}%"
else
    print_fail "Coverage report not generated"
fi

echo ""

# ============================================
# Step 4: Verify Performance Test File Exists
# ============================================
echo "Step 4: Verify Test Files"
echo "------------------------"

if [ -f "test/widgets/prompt/tag_view_performance_test.dart" ]; then
    print_pass "Performance test file exists"

    # Count number of tests
    TEST_COUNT=$(grep -c "testWidgets(" test/widgets/prompt/tag_view_performance_test.dart || echo "0")
    print_info "Found ${TEST_COUNT} test scenarios"
else
    print_fail "Performance test file not found"
fi

if [ -f "PERFORMANCE_TESTING_GUIDE.md" ]; then
    print_pass "Performance testing guide exists"
else
    print_fail "Performance testing guide not found"
fi

echo ""

# ============================================
# Step 5: Profile Mode Build Check
# ============================================
echo "Step 5: Profile Mode Check"
echo "-------------------------"

print_info "Checking if app can build in profile mode..."

if flutter build apk --profile > /dev/null 2>&1; then
    print_pass "Profile build successful"
else
    print_fail "Profile build failed"
fi

echo ""

# ============================================
# Step 6: Memory and Performance Estimates
# ============================================
echo "Step 6: Performance Estimates"
echo "----------------------------"

print_info "Estimated performance metrics:"
echo "  • 100 tags render time: <1000ms"
echo "  • Memory increase: <5MB for 100 tags"
echo "  • Target frame rate: 60fps (16.67ms per frame)"
echo "  • Acceptable frame drops: <5%"
echo "  • GPU usage target: <70%"
echo ""

# ============================================
# Step 7: RepaintBoundary Verification
# ============================================
echo "Step 7: RepaintBoundary Check"
echo "---------------------------"

print_info "Checking RepaintBoundary usage..."

# Count RepaintBoundary widgets in tag_chip.dart
if [ -f "lib/presentation/widgets/prompt/components/tag_chip/tag_chip.dart" ]; then
    REPAINT_COUNT=$(grep -c "RepaintBoundary" lib/presentation/widgets/prompt/components/tag_chip/tag_chip.dart || echo "0")
    if [ "$REPAINT_COUNT" -ge 4 ]; then
        print_pass "Found ${REPAINT_COUNT} RepaintBoundary instances in tag_chip.dart"
    else
        print_fail "Insufficient RepaintBoundary usage: ${REPAINT_COUNT} (expected >=4)"
    fi
else
    print_fail "tag_chip.dart file not found"
fi

echo ""

# ============================================
# Step 8: Summary
# ============================================
echo "================================"
echo "Test Summary"
echo "================================"
echo ""
echo -e "${GREEN}Passed: ${PASS}${NC}"
echo -e "${RED}Failed: ${FAIL}${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All automated checks passed!${NC}"
    echo ""
    echo "Next Steps:"
    echo "1. Run manual performance tests with DevTools"
    echo "   flutter run --profile"
    echo ""
    echo "2. Open Flutter DevTools"
    echo "   flutter pub global run devtools"
    echo ""
    echo "3. Follow PERFORMANCE_TESTING_GUIDE.md for detailed testing"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review and fix.${NC}"
    echo ""
    exit 1
fi
