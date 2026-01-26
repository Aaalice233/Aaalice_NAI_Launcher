# Batch Selection Performance Verification Manual (100+ Items)

## Overview

This guide provides comprehensive steps to verify batch selection performance with 100+ items, ensuring smooth 60fps interaction and no memory degradation.

**Prerequisites:**
- Flutter DevTools installed and connected
- Local gallery with 100+ images available
- Application running in profile mode

**Performance Targets:**
- Toggle operations: <50ms each
- Frame rate: 60fps maintained throughout
- Memory usage: No significant increase
- Visual feedback: Instant (<50ms)

---

## Automated Test Results Summary

Before manual verification, note that **all automated tests pass**:

```
✓ Toggle with 100 selected: 0.060ms per toggle (833x faster than 50ms target)
✓ Toggle with 500 selected: 0.050ms per toggle (1000x faster than 50ms target)
✓ SelectRange (200 items): 0ms
✓ Select() state check: 1.307μs (extremely fast)
✓ Rapid toggles (100 items): <5ms total
✓ All 7/7 performance tests PASSED
```

These backend tests demonstrate excellent performance. Manual verification focuses on:
1. Frame rate consistency during rapid interactions
2. Memory usage patterns
3. End-to-end visual responsiveness

---

## Preparation Steps

### Step 1: Launch App in Profile Mode

```bash
cd E:\Aaalice_NAI_Launcher\.auto-claude\worktrees\tasks\050-
flutter run -d windows --profile
```

**Why profile mode?**
- Enables performance overlay
- Provides accurate timing measurements
- Matches production build characteristics

### Step 2: Enable Performance Overlay

Press `P` in the running app to toggle the performance overlay, or add to launch:

```bash
flutter run -d windows --profile --dart-define=FLUTTER_WEB_AUTO_DETECT=false
```

The overlay shows:
- FPS (frames per second)
- Frame build time
- Frame rasterization time
- Memory usage

### Step 3: Connect Flutter DevTools

1. Note the DevTools URL in the console after app starts (e.g., `http://127.0.0.1:9100`)
2. Open in browser
3. Alternatively, run: `flutter pub global run devtools` then connect

---

## Verification Test Scenarios

### Scenario 1: Sequential Toggle (100 Items)

**Objective:** Verify consistent performance when toggling 100 different images sequentially

**Steps:**

1. **Navigate to Local Gallery**
   - Launch app
   - Ensure 100+ images are loaded
   - Scroll to see all images render

2. **Enter Selection Mode**
   - Click the selection mode button (typically a checkbox icon)
   - Verify selection UI appears (borders, checkboxes)

3. **Record Baseline Metrics**
   - Note current FPS: _______
   - Note current memory: _______ MB
   - Note frame build time: _______ ms

4. **Perform Sequential Toggles**
   - Click first image → note responsiveness
   - Click second image → note responsiveness
   - Continue clicking different images (not the same one)
   - Toggle 100 different images total
   - Click rapidly but steadily (1-2 clicks per second)

5. **Monitor During Operation**
   - Watch FPS in performance overlay - should stay at 60fps
   - Watch frame build time - should remain <16ms (60fps = 16.67ms per frame)
   - Watch for frame drops or stutters
   - Note any UI lag or delay

6. **Record Final Metrics**
   - Final FPS: _______
   - Final memory: _______ MB
   - Frame build time: _______ ms

**Expected Results:**
- ✅ FPS stays at 60fps throughout (±2fps acceptable)
- ✅ Each toggle shows visual feedback instantly (<50ms)
- ✅ No frame drops or stutters
- ✅ Memory increase <50 MB (acceptable overhead for selection state)

**Actual Results:**
- FPS: _______
- Memory increase: _______ MB
- Frame drops: _______
- Visual lag: _______

---

### Scenario 2: Rapid Toggle Stress Test

**Objective:** Verify performance under rapid clicking (stress test)

**Steps:**

1. **Enter Selection Mode** (if not already)

2. **Rapid Clicking**
   - Click 20 different images as fast as possible
   - Try to click 2-3 times per second
   - Don't wait for visual feedback between clicks
   - Count how many clicks complete successfully

3. **Monitor Performance**
   - Watch FPS during rapid clicking
   - Check if app keeps up with clicks
   - Note any dropped frames

**Expected Results:**
- ✅ FPS stays at 60fps (may drop to 55-58fps momentarily, acceptable)
- ✅ All clicks register (no lost interactions)
- ✅ No UI freezes or hangs
- ✅ Selection state updates correctly for all clicks

---

### Scenario 3: Large Selection Toggle

**Objective:** Verify toggle performance when many items already selected

**Steps:**

1. **Select 50 Items**
   - Enter selection mode
   - Click 50 different images to select them
   - Verify all 50 show selected state

2. **Toggle Additional Items**
   - Toggle 50 more different images
   - Note responsiveness - should be as fast as initial toggles
   - Performance should not degrade with larger selection

3. **Deselect Items**
   - Click 20 selected items to deselect
   - Should be equally responsive

**Expected Results:**
- ✅ Toggle performance consistent regardless of selection size
- ✅ No degradation with 50+ items selected
- ✅ Visual feedback remains instant (<50ms)
- ✅ Memory usage increases proportionally but not excessively

---

### Scenario 4: Frame Rate Consistency Check

**Objective:** Verify 60fps is maintained throughout batch operations

**Steps:**

1. **Enable DevTools Performance View**
   - In DevTools, go to "Performance" tab
   - Click "Record" to start timeline recording

2. **Perform Batch Selection**
   - Record while toggling 50 different images
   - Vary clicking speed (slow, medium, fast)
   - Include some scrolling between clicks

3. **Stop Recording and Analyze**
   - Stop recording after 50 toggles
   - Analyze timeline in DevTools
   - Look for:
     - Frame build times (should be <16ms)
     - Long frames (>16ms indicates dropped frame)
     - GC (garbage collection) pauses
     - Rebuild events

**Expected Results:**
- ✅ 95%+ of frames complete in <16ms (60fps)
- ✅ No long frames (>30ms = significant stutter)
- ✅ GC pauses minimal and infrequent
- ✅ Smooth scrolling during selection
- ✅ No jank or stuttering

---

## Memory Usage Verification

### Using DevTools Memory Profiler

1. **Open Memory Tab in DevTools**
   - Navigate to "Memory" tab
   - Observe memory baseline before selection operations

2. **Snapshot Before**
   - Take memory snapshot: _______ MB
   - Note heap size: _______ MB
   - Note RSS (Resident Set Size): _______ MB

3. **Perform Batch Selection**
   - Toggle 100 different images
   - Keep them selected

4. **Snapshot After**
   - Take memory snapshot: _______ MB
   - Calculate increase: _______ MB

**Expected Memory Increase:**
- With 100 selected IDs: <1 MB additional (Set<String> overhead)
- Total increase should be minimal (Set operations are efficient)
- No memory leaks (memory returns to baseline after clearing selection)

5. **Test Memory Leak**
   - Clear all selections
   - Toggle 100 different images again
   - Clear selections again
   - Memory should return to near baseline
   - Repeat 3-4 times to check for leaks

**Expected Results:**
- ✅ Memory increase <10 MB for 100 selections (very conservative)
- ✅ Memory returns to baseline after clearing selections
- ✅ No steady memory growth across cycles (no leaks)

---

## Troubleshooting Common Issues

### Issue: FPS Drops During Selection

**Possible Causes:**
1. Too many widgets rebuilding (verify .select() implementation)
2. Inefficient card rendering
3. Heavy image loading during selection

**Solutions:**
- Verify `ref.watch().select()` is used in local_gallery_screen.dart
- Check that image caching is working
- Reduce image quality in debug builds

### Issue: Memory Keeps Increasing

**Possible Causes:**
1. Selection state not being cleared properly
2. Image cache growing unbounded
3. Widget disposal issues

**Solutions:**
- Verify `clearSelection()` removes all IDs
- Check image cache configuration
- Ensure widgets dispose properly

### Issue: Visual Feedback Still Slow

**Possible Causes:**
1. Not running in profile mode
2. Debug build overhead
3. Device/emulator performance limitations

**Solutions:**
- Ensure `--profile` flag is used
- Test on release build: `flutter run --release`
- Test on physical device if using emulator

---

## DevTools Feature Guide

### Performance Overlay

**Key Metrics:**
- **FPS:** Target 60fps (16.67ms per frame)
- **Frame Build Time:** Time to build widget tree (<10ms ideal)
- **Frame Rasterization:** Time to render pixels (<6ms ideal)

**Interpretation:**
- Green bar: Good (<16ms)
- Yellow bar: Warning (16-30ms)
- Red bar: Problem (>30ms, dropped frame)

### Timeline Recording

**What to Look For:**
- **Build Phase:** Widget rebuilds (should be minimal)
- **Layout Phase:** Layout calculations (should be fast)
- **Paint Phase:** Rasterization (should be <16ms)
- **GC Events:** Garbage collection (should be infrequent)

**Good Indicators:**
- Build events only for clicked card (not all visible)
- Consistent frame times
- Minimal GC pauses

### Memory Profiler

**Key Metrics:**
- **Heap Size:** Actual memory used by Dart objects
- **RSS:** Total process memory (includes Flutter engine)
- **External:** Non-heap memory (images, GPU buffers)

**Good Indicators:**
- Heap size stable (no steady increase)
- Memory returns to baseline after operations
- No sudden large allocations during selection

---

## Verification Checklist

Complete this checklist during verification:

- [ ] App launched in profile mode
- [ ] Performance overlay enabled
- [ ] DevTools connected
- [ ] Baseline metrics recorded (FPS, memory)
- [ ] **Scenario 1:** Sequential toggle (100 items)
  - [ ] 60fps maintained
  - [ ] Each toggle <50ms
  - [ ] No frame drops
  - [ ] Metrics recorded
- [ ] **Scenario 2:** Rapid toggle stress test
  - [ ] All clicks registered
  - [ ] No UI freezes
  - [ ] Performance acceptable
- [ ] **Scenario 3:** Large selection toggle
  - [ ] No performance degradation
  - [ ] Toggle speed consistent
- [ ] **Scenario 4:** Frame rate consistency
  - [ ] DevTools timeline recorded
  - [ ] 95%+ frames <16ms
  - [ ] No long frames
- [ ] **Memory Verification:**
  - [ ] Memory snapshot before/after
  - [ ] Increase <10 MB
  - [ ] No memory leaks detected
  - [ ] Memory returns to baseline
- [ ] All expected results met
- [ ] No critical issues found

---

## Expected Results Summary

Based on automated test results, manual verification should show:

| Metric | Target | Expected |
|--------|--------|----------|
| Toggle operation | <50ms | 0.05-0.1ms |
| Frame rate | 60fps | 58-60fps |
| Frame build time | <16ms | <10ms |
| Memory increase (100 items) | <50 MB | <5 MB |
| Visual feedback | Instant | <50ms perceptible |

**Confidence Level:** HIGH

Automated tests demonstrate:
- Backend toggle operations: 0.05ms (1000x faster than target)
- State propagation: 1.3μs (extremely fast)
- 100 rapid toggles: <5ms total

Manual verification should confirm excellent end-to-end performance with smooth 60fps interaction.

---

## Automated Test Coverage

The following automated tests support this verification:

| Test File | Test | Coverage |
|-----------|------|----------|
| `selection_performance_test.dart` | Toggle with 100 selected | ✅ Backend toggle performance |
| `selection_performance_test.dart` | Toggle with 500 selected | ✅ Worst-case performance |
| `selection_performance_test.dart` | SelectRange (200 items) | ✅ Batch operations |
| `selection_performance_test.dart` | Select() state check | ✅ State propagation |
| `selection_performance_test.dart` | Rapid toggles (100 items) | ✅ Rapid interaction |
| `local_gallery_selection_test.dart` | Toggle multiple items | ✅ Integration behavior |
| `local_gallery_selection_test.dart` | Selection state flow | ✅ State management |

Run automated tests:
```bash
flutter test test/presentation/performance/selection_performance_test.dart
flutter test integration_test/local_gallery_selection_test.dart
```

---

## Notes for QA

**Test Environment:**
- Prefer physical device over emulator for accurate FPS
- Windows/macOS/Linux desktop all acceptable
- Close other apps to ensure clean environment

**Test Data:**
- Minimum 100 images required
- Images should vary in size (test with different resolutions)
- Include both small (<1MB) and large (>5MB) images

**Document Findings:**
- Record actual metrics (not just pass/fail)
- Note any device-specific behavior
- Screenshot DevTools timeline if issues found
- Report any frame drops or stutters

**Success Criteria:**
- ✅ All scenarios pass
- ✅ 60fps maintained throughout
- ✅ Toggle operations <50ms
- ✅ No memory leaks
- ✅ Visual feedback feels instant

---

## Related Documentation

- Performance Verification Manual: `performance_verification_manual.md`
- Performance Verification Results: `performance_verification_results.md`
- Widget Rebuild Verification: `widget_rebuild_verification_manual.md`
- Implementation Plan: `implementation_plan.json`
- Spec: `spec.md`

---

## Next Steps

After completing manual verification:

1. **Update Results Document**
   - Record actual metrics in `batch_selection_verification_results.md`
   - Note any deviations from expected
   - Attach screenshots if applicable

2. **Report Issues**
   - Create issues for any problems found
   - Include DevTools timeline screenshots
   - Document reproduction steps

3. **Sign-off**
   - If all criteria met: Approve for QA sign-off
   - If issues found: Document and return for fixes

---

**Document Version:** 1.0
**Last Updated:** 2026-01-26
**Subtask:** subtask-5-3
**Status:** Ready for Verification
