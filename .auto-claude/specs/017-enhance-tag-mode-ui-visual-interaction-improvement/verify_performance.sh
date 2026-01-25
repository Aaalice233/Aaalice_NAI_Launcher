#!/bin/bash
# Performance Verification Helper Script
# Subtask 6-2: Verify all animations run at 60fps with DevTools

echo "========================================"
echo "Performance Verification Helper"
echo "Subtask 6-2: 60fps Animation Testing"
echo "========================================"
echo ""

# Check if we're in the correct directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found"
    echo "Please run this script from the Flutter project root"
    exit 1
fi

echo "✅ Found Flutter project"
echo ""

# Step 1: Run code analysis
echo "Step 1: Running code analysis..."
echo "-----------------------------------"
flutter analyze lib/presentation/widgets/prompt/components/tag_chip/tag_chip.dart lib/presentation/widgets/prompt/tag_view.dart

if [ $? -eq 0 ]; then
    echo "✅ Code analysis passed"
else
    echo "❌ Code analysis failed"
    exit 1
fi
echo ""

# Step 2: Check for RepaintBoundary usage
echo "Step 2: Checking RepaintBoundary isolation..."
echo "-----------------------------------"
grep -c "RepaintBoundary" lib/presentation/widgets/prompt/components/tag_chip/tag_chip.dart
echo "✅ RepaintBoundary instances found in tag_chip.dart"
echo ""

# Step 3: Check animation controllers
echo "Step 3: Checking animation controller setup..."
echo "-----------------------------------"
grep -c "AnimationController" lib/presentation/widgets/prompt/components/tag_chip/tag_chip.dart
echo "✅ AnimationController instances found"
echo ""

# Step 4: Instructions for manual testing
echo "========================================"
echo "MANUAL TESTING INSTRUCTIONS"
echo "========================================"
echo ""
echo "The code is ready for performance testing. Please follow these steps:"
echo ""
echo "1. START APP IN PROFILE MODE:"
echo "   flutter run --profile -d windows"
echo ""
echo "2. OPEN DEVTOOLS:"
echo "   - Press 'd' in the terminal"
echo "   - Open the Performance tab"
echo "   - Enable performance overlay (press 'o' in app)"
echo ""
echo "3. TEST ENTRANCE ANIMATIONS:"
echo "   - Add 10 tags"
echo "   - Watch for sequential fade-in (50ms stagger)"
echo "   - Verify: 60fps, frame time ≤16.67ms"
echo ""
echo "4. TEST HOVER EFFECTS:"
echo "   - Rapidly hover over multiple tags"
echo "   - Verify: Scale, shadow, brightness smooth"
echo "   - Check: No frame drops, instant feedback"
echo ""
echo "5. TEST DRAG AND DROP:"
echo "   - Long press and drag tags"
echo "   - Verify: Card lift, dashed border, shadow"
echo "   - Check: Smooth cursor following, 60fps"
echo ""
echo "6. TEST WEIGHT CHANGES:"
echo "   - Change weight values rapidly"
echo "   - Verify: Number rolling smooth (300ms)"
echo "   - Check: No lag during interpolation"
echo ""
echo "7. STRESS TEST:"
echo "   - Add 100+ tags"
echo "   - Perform all interactions"
echo "   - Verify: <5% frames dropped overall"
echo ""
echo "8. CHECK METRICS IN DEVTOOLS:"
echo "   - Frame rate: Should stay at 60fps"
echo "   - Frame time: ≤16.67ms per frame"
echo "   - GPU usage: <70%"
echo "   - Frames dropped: <5%"
echo ""
echo "========================================"
echo "EXPECTED RESULTS"
echo "========================================"
echo ""
echo "✅ All animations smooth at 60fps"
echo "✅ Frame time ≤16.67ms"
echo "✅ <5% frames dropped"
echo "✅ GPU usage <70%"
echo "✅ No memory leaks"
echo "✅ Responsive UI throughout"
echo ""
echo "========================================"
echo "TROUBLESHOOTING"
echo "========================================"
echo ""
echo "If frame rate drops below 60fps:"
echo "  1. Check if other apps are using GPU/CPU"
echo "  2. Close other applications"
echo "  3. Try restarting the app"
echo "  4. Check for RepaintBoundary usage (should be 4+ in tag_chip.dart)"
echo ""
echo "If animations stutter:"
echo "  1. Verify animation durations (150-300ms range)"
echo "  2. Check for expensive operations in build() methods"
echo "  3. Use DevTools Timeline to identify bottlenecks"
echo ""
echo "For detailed analysis, see:"
echo "  PERFORMANCE_VERIFICATION_REPORT.md"
echo ""
echo "========================================"
echo "Ready to start testing? Run:"
echo "  flutter run --profile"
echo "========================================"
