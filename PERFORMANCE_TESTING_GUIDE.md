# Performance Testing Guide - TagView with 100+ Tags

This guide provides comprehensive instructions for testing the performance of the enhanced TagView component with large datasets (100+ tags).

## Table of Contents

1. [Automated Performance Tests](#automated-performance-tests)
2. [Manual Testing with DevTools](#manual-testing-with-devtools)
3. [Performance Benchmarks](#performance-benchmarks)
4. [Troubleshooting Performance Issues](#troubleshooting-performance-issues)

---

## Automated Performance Tests

### Running the Test Suite

```bash
# Run all performance tests
flutter test test/widgets/prompt/tag_view_performance_test.dart

# Run with coverage
flutter test --coverage test/widgets/prompt/tag_view_performance_test.dart

# Run specific test
flutter test test/widgets/prompt/tag_view_performance_test.dart --name="Render 100 tags"
```

### Test Coverage

The automated test suite covers:

1. **Rendering Performance**
   - 100 tags render in <1 second
   - 200 tags render without memory errors
   - Frame rate during incremental tag addition

2. **Scroll Performance**
   - 150 tags scroll smoothly
   - Average frame time <32ms (~30fps minimum)

3. **Animation Performance**
   - Staggered entrance animations complete in expected time
   - Weight change animations are smooth
   - Hover interactions are responsive (<100ms)

4. **Drag and Drop**
   - Drag operations are responsive (<500ms)
   - Performance maintained with many tags

5. **RepaintBoundary Verification**
   - Confirms RepaintBoundary widgets are present
   - Isolates repaints for better performance

### Expected Results

```
✅ Rendered 100 tags in <1000ms
✅ Scrolled 150 tags with avg frame time: <32ms
✅ Entrance animations completed in ~5300ms (100 tags × 50ms stagger + 300ms)
✅ Successfully rendered 200 tags without memory errors
✅ Found 50+ RepaintBoundary widgets
✅ Average hover response time: <100ms
✅ Drag operation completed in <500ms
✅ Average weight change time: <350ms
✅ Average frame time: <32ms (~30+ fps)
```

---

## Manual Testing with DevTools

### Setup

1. **Start the App in Profile Mode**

```bash
flutter run --profile

# Or with specific device
flutter run -d windows --profile
flutter run -d emulator-5554 --profile
```

2. **Open Flutter DevTools**

```bash
# In a separate terminal
flutter pub global activate devtools
flutter pub global run devtools
```

3. **Connect DevTools to Your App**
   - Open DevTools URL (usually http://localhost:9100)
   - Connect to your running Flutter app

### Test Scenarios

#### Scenario 1: Add 100+ Tags

**Objective**: Verify rendering performance and memory usage

**Steps**:
1. Open the app in profile mode
2. Navigate to the tag view
3. Add 100+ tags (use test data or manual entry)
4. Monitor in DevTools:
   - **Performance Tab**: Watch frame times
   - **Memory Tab**: Monitor memory usage
   - **Timeline Tab**: Record timeline during addition

**Expected Results**:
- ✅ All frames complete in <16.67ms (60fps)
- ✅ Memory increase <5MB for 100 tags
- ✅ No jank during rendering
- ✅ Smooth entrance animations with stagger

**DevTools Metrics to Check**:
```
Performance:
  - Frame Rate: 60fps (16.67ms per frame)
  - Frames Dropped: <5%
  - GPU Usage: <70%

Memory:
  - Heap Total: <5MB increase
  - Heap Used: Stable after animations complete
  - No memory leaks (usage should stabilize)

Timeline:
  - Build time: <20ms per TagChip
  - Layout time: <5ms per frame
  - Paint time: <10ms per frame
```

#### Scenario 2: Scroll Through Many Tags

**Objective**: Verify smooth scrolling performance

**Steps**:
1. Add 150+ tags to the view
2. Start recording in DevTools Performance tab
3. Scroll up and down through the list
4. Stop recording and analyze

**Expected Results**:
- ✅ Smooth scrolling at 60fps
- ✅ No frame drops during scroll
- ✅ Consistent frame times <16.67ms
- ✅ RepaintBoundary prevents full repaints

**What to Look For**:
- Green frames in Flutter DevTools (good)
- No red frames (jank)
- Consistent frame times
- Minimal rebuilds (due to RepaintBoundary)

#### Scenario 3: Trigger Entrance Animations

**Objective**: Verify staggered animations run smoothly

**Steps**:
1. Clear all tags
2. Start DevTools recording
3. Add 50 tags at once
4. Watch animations complete
5. Analyze frame times

**Expected Results**:
- ✅ 50ms stagger delay between each tag
- ✅ Each tag animates over 300ms
- ✅ Total animation time: ~5.3s (50 + 50×49 + 300)
- ✅ No dropped frames during animations
- ✅ Smooth fade-in and slide-up

**Animation Timeline**:
```
Tag 0:    0ms - 300ms
Tag 1:   50ms - 350ms
Tag 2:  100ms - 400ms
...
Tag 49: 2450ms - 2750ms
```

#### Scenario 4: Interact with Many Tags (Hover, Drag, Select)

**Objective**: Verify interaction responsiveness

**Steps**:
1. Add 100+ tags
2. Test interactions while recording:
   - Hover over tags rapidly
   - Click to select tags
   - Drag and drop to reorder
   - Change tag weights
3. Monitor frame times and responsiveness

**Expected Results**:
- ✅ Hover animation <150ms
- ✅ Click ripple animation plays smoothly
- ✅ Drag feedback appears instantly
- ✅ Weight change animation <300ms
- ✅ No lag between user input and visual feedback

**Response Time Benchmarks**:
```
Hover:      <150ms (scale 1.0→1.05, shadow, brightness)
Click:      <200ms (ripple animation)
Drag:       <300ms (feedback appears)
Weight:     <300ms (number interpolation)
```

#### Scenario 5: Memory Usage Over Time

**Objective**: Verify no memory leaks

**Steps**:
1. Open Memory tab in DevTools
2. Add 100 tags
3. Wait for animations to complete
4. Remove all tags
5. Add 100 tags again
6. Repeat 5 times
7. Analyze memory graph

**Expected Results**:
- ✅ Memory returns to baseline after removing tags
- ✅ No steady memory increase (memory leak)
- ✅ Animation controllers properly disposed
- ✅ Stable heap usage over cycles

**Memory Profile**:
```
Initial:        X MB
+100 tags:      X + <5 MB
Remove all:     Back to X MB
+100 tags:      X + <5 MB (same as before)

If memory keeps increasing: Potential leak!
```

#### Scenario 6: RepaintBoundary Effectiveness

**Objective**: Verify RepaintBoundary isolates repaints

**Steps**:
1. Open Widget Inspector in DevTools
2. Add 50 tags
3. Enable "Render Repaint Rainbows" overlay
4. Trigger hover animation on one tag
5. Observe which widgets repaint

**Expected Results**:
- ✅ Only hovered tag repaints (shows color)
- ✅ Other tags don't repaint (stay gray)
- ✅ Parent widgets don't repaint unnecessarily
- ✅ Efficient paint isolation

**What You Should See**:
```
Hovering Tag #5:
  - Tag #5: Repaints (color in rainbow)
  - Tag #1-4, #6-50: No repaint (static)
  - TagView parent: No repaint

This confirms RepaintBoundary is working!
```

---

## Performance Benchmarks

### Target Metrics

| Metric | Target | Acceptable | Poor |
|--------|--------|------------|------|
| **Frame Rate** | 60fps (16.67ms) | 55-60fps | <55fps |
| **GPU Usage** | <50% | 50-70% | >70% |
| **Memory Increase** | <3MB | 3-5MB | >5MB |
| **Frame Drops** | <2% | 2-5% | >5% |
| **Build Time** | <15ms | 15-25ms | >25ms |
| **Interaction Response** | <50ms | 50-100ms | >100ms |

### Scalability Expectations

| Tag Count | Memory | Frame Rate | Interaction Time |
|-----------|--------|------------|------------------|
| 50 tags | +2.5MB | 60fps | <50ms |
| 100 tags | +5MB | 60fps | <100ms |
| 150 tags | +7.5MB | 58-60fps | <150ms |
| 200 tags | +10MB | 55-58fps | <200ms |

### Animation Performance

| Animation | Duration | Expected FPS | Notes |
|-----------|----------|--------------|-------|
| Entrance | 300ms per tag | 60fps | 50ms stagger |
| Hover | 150ms | 60fps | Scale + shadow + brightness |
| Click Ripple | 200ms | 60fps | Material ripple effect |
| Drag Feedback | 200ms | 60fps | Scale + dashed border |
| Weight Change | 300ms | 60fps | Number interpolation |
| Delete | 250ms | 60fps | Shrink + fade |
| Favorite | 200ms | 60fps | Heart jump |

---

## Troubleshooting Performance Issues

### Issue: Low Frame Rate (<60fps)

**Symptoms**:
- Red frames in DevTools Performance tab
- Janky animations
- Slow scrolling

**Possible Causes**:
1. **Expensive Build Methods**
   - Check for heavy computations in build()
   - Move calculations outside build method
   - Use const constructors

2. **Insufficient RepaintBoundary**
   - Add more RepaintBoundary widgets
   - Isolate animated components

3. **Too Many Simultaneous Animations**
   - Reduce number of concurrent animations
   - Increase stagger delay
   - Disable some animations on low-end devices

**Solutions**:
```dart
// Add RepaintBoundary
RepaintBoundary(
  child: ExpensiveAnimatedWidget(),
)

// Use const constructors
const Text('static text')

// Cache expensive calculations
@override
void initState() {
  super.initState();
  _cachedValue = expensiveCalculation();
}
```

### Issue: High Memory Usage

**Symptoms**:
- Memory keeps increasing
- Out of memory errors
- Slow garbage collection

**Possible Causes**:
1. **Memory Leaks**
   - Animation controllers not disposed
   - Controllers not properly cleaned up
   - Listeners not removed

2. **Large Widget Trees**
   - Too many widgets in memory
   - Inefficient widget composition

**Solutions**:
```dart
@override
void dispose() {
  _controller.dispose(); // Always dispose!
  super.dispose();
}

// Use AutomaticKeepAliveClientMixin selectively
// Don't keep all tags alive if not needed
```

### Issue: Slow Interactions

**Symptoms**:
- Delayed hover effects
- Slow drag feedback
- Unresponsive buttons

**Possible Causes**:
1. **Main Thread Blocking**
   - Heavy computations on UI thread
   - Synchronous file I/O
   - Network calls on main thread

2. **Expensive Animations**
   - Too many shadows
   - Complex gradients
   - Blur effects

**Solutions**:
```dart
// Move heavy work to isolate
await compute(heavyCalculation, data);

// Simplify effects on low-end devices
if (!isLowEndDevice) {
  // Expensive blur effects
}

// Use AnimatedBuilder instead of setState
AnimatedBuilder(
  animation: _controller,
  builder: (context, child) => Transform.scale(
    scale: _animation.value,
    child: child, // Cached static child
  ),
  child: ExpensiveStaticWidget(),
)
```

### Issue: RepaintBoundary Not Working

**Symptoms**:
- Whole screen repaints on animation
- Rainbow overlay shows full repaints

**Possible Causes**:
1. **RepaintBoundary in Wrong Place**
   - Not wrapping animated content
   - Too broad scope

2. **Widget Causing Full Repaint**
   - AnimatedContainer triggers parent repaint
   - GlobalKey causing rebuilds

**Solutions**:
```dart
// WRONG: RepaintBoundary too high
RepaintBoundary(
  child: Column(
    children: [
      AnimatedWidget(), // Still causes full repaint
      StaticWidget(),
    ],
  ),
)

// RIGHT: RepaintBoundary wraps animated widget
Column(
  children: [
    RepaintBoundary(
      child: AnimatedWidget(), // Only this repaints
    ),
    StaticWidget(),
  ],
)
```

---

## Performance Optimization Checklist

Before marking the task complete, verify:

- [ ] Automated tests pass (all 9 tests)
- [ ] Manual testing shows 60fps in profile mode
- [ ] Memory increase <5MB for 100 tags
- [ ] Frame drops <5% during all interactions
- [ ] RepaintBoundary isolates repaints correctly
- [ ] Entrance animations run smoothly
- [ ] Hover effects are responsive
- [ ] Drag and drop works with many tags
- [ ] No memory leaks over multiple cycles
- [ ] Performance acceptable on target devices

---

## Quick Test Command

```bash
# Run all performance tests
flutter test test/widgets/prompt/tag_view_performance_test.dart

# Run app in profile mode for manual testing
flutter run --profile

# Open DevTools
flutter pub global run devtools
```

---

## Summary

This testing approach combines:

1. **Automated Tests** - Quick regression testing
2. **Manual DevTools Testing** - Deep performance analysis
3. **Benchmarking** - Track performance over time
4. **Troubleshooting Guide** - Fix common issues

Follow this guide to ensure the TagView component performs well with 100+ tags while maintaining smooth animations and responsive interactions.
