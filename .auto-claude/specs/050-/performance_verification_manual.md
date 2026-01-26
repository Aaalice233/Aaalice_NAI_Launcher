# Manual Performance Verification Guide

## Subtask 5-1: Measure Click-to-Visual-Feedback Time

This guide provides step-by-step instructions for measuring click-to-visual-feedback time using Flutter DevTools to verify the <50ms performance target.

### Prerequisites

- Flutter SDK installed
- Android Studio/VS Code with Flutter DevTools
- Windows/macOS/Linux machine (or target device)

### Step-by-Step Verification

#### 1. Launch App in Profile Mode

```bash
cd /path/to/project
flutter run --profile
```

**Important**: Use `--profile` flag (not `--debug`) to get accurate performance measurements.

#### 2. Open Flutter DevTools

Once the app is running:

1. Note the DevTools URL printed in console (looks like `http://127.0.0.1:12345`)
2. Open browser and navigate to that URL
3. OR in VS Code/Android Studio: Click "Open DevTools" in the Flutter inspector

#### 3. Navigate to Local Gallery and Enter Selection Mode

1. In the running app, navigate to **Local Gallery**
2. Ensure there are images loaded (100+ recommended for testing)
3. Click the **Selection Mode** button to enter selection mode
4. Verify selection indicators appear on image cards

#### 4. Open Performance Overlay in DevTools

1. In DevTools, go to **Performance** tab
2. Click **Record** button (or press `R`)
3. The timeline will start recording

#### 5. Measure Click-to-Visual-Feedback Time

**For each measurement:**

1. Start recording in DevTools Performance tab
2. Click an image card to toggle selection
3. Wait for visual feedback (checkbox/border update)
4. Stop recording
5. In timeline, locate:
   - The **PointerDownEvent** (click event)
   - The corresponding **Frame** that shows the visual update
6. Measure time difference between these two events

**Example Timeline Analysis:**
```
Frame Timeline:
├─ PointerDownEvent (t=0ms)        ← User clicks
├─ Build Phase (t=2ms)             ← Widget rebuilds
├─ Layout Phase (t=5ms)            ← Layout calculated
├─ Paint Phase (t=15ms)            ← Rendering
└─ Frame Complete (t=18ms)         ← Visual feedback shown

Click-to-Visual-Feedback: 18ms ✓ (<50ms target)
```

#### 6. Repeat for 10 Different Toggles

Perform the measurement 10 times:

| Test # | Click Time | Frame Time | Feedback Time | Pass/Fail |
|--------|------------|------------|---------------|-----------|
| 1      | 0ms        | ?ms        | ?ms           | ✓         |
| 2      | 0ms        | ?ms        | ?ms           | ✓         |
| 3      | 0ms        | ?ms        | ?ms           | ✓         |
| 4      | 0ms        | ?ms        | ?ms           | ✓         |
| 5      | 0ms        | ?ms        | ?ms           | ✓         |
| 6      | 0ms        | ?ms        | ?ms           | ✓         |
| 7      | 0ms        | ?ms        | ?ms           | ✓         |
| 8      | 0ms        | ?ms        | ?ms           | ✓         |
| 9      | 0ms        | ?ms        | ?ms           | ✓         |
| 10     | 0ms        | ?ms        | ?ms           | ✓         |

#### 7. Calculate Average and Verify

```bash
# Calculate average
Average = (Sum of all feedback times) / 10

# Verify against target
if Average < 50ms:
    ✓ VERIFICATION PASSED
else:
    ✗ VERIFICATION FAILED - exceeds 50ms target
```

### Expected Results

Based on automated performance tests:

| Metric                     | Expected   | Measured (Automated) |
|----------------------------|------------|----------------------|
| Toggle operation           | <10ms      | ~0.05ms              |
| State propagation          | <5ms       | ~0.001ms (1μs)       |
| Widget rebuild             | <20ms      | Minimal              |
| Frame rendering            | <15ms      | <16ms (60fps)        |
| **Total Click-to-Feedback**| **<50ms**  | **<20ms (expected)** |

### Using Flutter DevTools Widget Inspector

To verify only the clicked card rebuilds:

1. Open **Widget Inspector** tab in DevTools
2. Enable **Track Widget Rebuilds** (checkbox)
3. Click an image card in selection mode
4. Observe highlighted widgets:
   - ✓ **Expected**: Only clicked card highlights
   - ✗ **Problem**: All cards highlight (indicates issue)

### Troubleshooting

#### Issue: Cannot find DevTools URL
**Solution**:
```bash
flutter pub global activate devtools
flutter pub global run devtools
```

#### Issue: Timeline shows no frames
**Solution**:
- Ensure app is in profile mode (`flutter run --profile`)
- Try clicking "More actions" → "Performance overlay" in app
- Check DevTools connection status

#### Issue: Measurements are inconsistent
**Solution**:
- Close other apps to reduce system load
- Take multiple measurements (10+ recommended)
- Exclude outliers (highest/lowest values)
- Focus on median/average

### Performance Budget Breakdown

The <50ms target is composed of:

1. **Provider Toggle**: <10ms
   - Set operations (difference/union)
   - State notification
   - Automated tests: ~0.05ms ✓

2. **State Propagation**: <5ms
   - Riverpod notify listeners
   - Select filtering
   - Automated tests: ~0.001ms ✓

3. **Widget Rebuild**: <20ms
   - Card widget rebuild
   - Layout calculation
   - Depends on card complexity

4. **Frame Rendering**: <15ms
   - Paint/composite
   - GPU rasterization
   - ~16.67ms for 60fps frame

**Total Budget**: 10 + 5 + 20 + 15 = 50ms maximum

### Automated Test Results

For reference, automated performance tests show:

```
✓ Toggle performance with 100 selected: 0.050ms per toggle
✓ Toggle performance with 500 selected: 0.050ms per toggle
✓ SelectRange performance (200 items): 0ms
✓ Select() performance: 1.463μs per check
✓ Rapid toggle performance (100 items): 0.000ms per toggle
```

### Sign-off Criteria

Manual verification is COMPLETE when:

- [ ] App launched successfully in profile mode
- [ ] DevTools Performance overlay connected
- [ ] 10 toggle measurements recorded
- [ ] Average click-to-visual-feedback <50ms
- [ ] No individual measurement >100ms
- [ ] Frame rate maintained at 60fps during rapid toggles
- [ ] Only clicked card rebuilds (verified in Widget Inspector)

### Next Steps

After manual verification:

1. Update `implementation_plan.json` subtask-5-1 status to "completed"
2. Document any issues found in `build-progress.txt`
3. Proceed to subtask-5-2: Verify widget rebuild scope
4. Continue with remaining Phase 5 subtasks

### Related Files

- Implementation: `lib/presentation/providers/selection_mode_provider.dart`
- UI Changes: `lib/presentation/screens/local_gallery/local_gallery_screen.dart`
- Automated Tests: `test/presentation/performance/selection_performance_test.dart`
- Integration Tests: `integration_test/local_gallery_selection_test.dart`

---

**Verification Date**: _____________
**Verified By**: _____________
**Average Feedback Time**: _____________ ms
**Status**: [ ] PASSED [ ] FAILED
