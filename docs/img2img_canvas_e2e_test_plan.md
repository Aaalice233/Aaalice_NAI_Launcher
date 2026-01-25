# Img2Img Canvas Workflow - End-to-End Test Plan

## Overview

This document outlines the comprehensive end-to-end testing procedures for the img2img canvas workflow, following the fixes implemented in subtasks 2-1 through 5-1.

**Test Environment:**
- Flutter App: Desktop (Windows/macOS/Linux) or Web
- Target: 60fps performance during drawing operations
- Test Device: Modern desktop processor, 8GB+ RAM recommended

## Test Scope

This test plan validates:
1. **Brush Button Visibility** (Subtask 2-1 fix)
2. **Canvas Performance** (Subtasks 3-1, 3-2, 3-3 fixes)
3. **Img2Img Integration** (End-to-end workflow)
4. **Theme Compatibility** (Light and dark mode)
5. **Multi-Layer Performance** (Stress testing)

---

## Test Procedure

### Step 1: Open img2img Generation Screen

**Action:**
1. Launch the Flutter app
2. Navigate to the Generation screen
3. Locate the Img2Img panel

**Expected Results:**
- ✅ Img2Img panel is visible
- ✅ Two option cards are displayed: "Upload Image" (上传图片) and "Draw Sketch" (绘制草图)
- ✅ Both cards have proper icons (upload_file and brush)
- ✅ Cards have hover effects (border highlight and color change)
- ✅ No console errors or warnings

**Validation Notes:**
- Verify the panel is expandable by clicking the title bar
- Check that the collapsed state shows a preview when an image is loaded
- Ensure the panel title matches the localization (img2img_title)

---

### Step 2: Click 'Draw Sketch' to Open Canvas

**Action:**
1. Click the "Draw Sketch" (绘制草图) option card
2. Wait for the ImageEditorScreen to open

**Expected Results:**
- ✅ ImageEditorScreen opens as a full-screen modal
- ✅ Canvas is sized according to generation parameters (default: 512x512 or configured size)
- ✅ Canvas background is checkerboard pattern (transparency indicator)
- ✅ Toolbar is visible with brush tool selected by default
- ✅ Brush preset buttons are displayed at the bottom of the screen
- ✅ Layer panel is visible on the right side
- ✅ No lag or delay in opening the canvas

**Validation Notes:**
- Measure canvas open time (should be <500ms on typical hardware)
- Verify the canvas title matches "img2img_drawSketch" localization
- Check that EditorState is properly initialized
- Ensure default tool is "brush" (笔刷)

---

### Step 3: Select Different Brush Presets and Verify Visibility

**Action:**
1. Locate the brush preset buttons at the bottom of the screen
2. Click each brush preset button (8 total): 铅笔, 细笔, 标准笔刷, 软笔刷, 喷枪, 马克笔, 粗笔刷, 涂抹笔
3. Verify the selected state for each preset
4. Test in both light and dark themes

**Expected Results:**

#### For Non-Selected Buttons:
- ✅ Background: Transparent (no fill)
- ✅ Border: outlineVariant color from theme
- ✅ Icon/text: onSurfaceVariant color
- ✅ Clearly visible against canvas background
- ✅ Visual distinction from selected button

#### For Selected Button:
- ✅ Background: primaryContainer color from theme
- ✅ Icon/text: **onPrimaryContainer** color (Subtask 2-1 fix)
- ✅ Border: outlineVariant color (visible and distinct)
- ✅ Font weight: Bold (w600)
- ✅ **CRITICAL:** Sufficient contrast ratio (WCAG AA: 4.5:1 for text)

#### Light Theme Verification:
- ✅ Selected button background: Light primaryContainer (e.g., light blue/purple)
- ✅ Selected button icon/text: Dark onPrimaryContainer (e.g., dark blue/black)
- ✅ **Passes contrast check:** Dark text on light background
- ✅ Non-selected buttons have medium-gray icon/text (onSurfaceVariant)

#### Dark Theme Verification:
- ✅ Selected button background: Dark primaryContainer (e.g., dark blue/purple)
- ✅ Selected button icon/text: Light onPrimaryContainer (e.g., white/light gray)
- ✅ **Passes contrast check:** Light text on dark background
- ✅ Non-selected buttons have medium-light-gray icon/text (onSurfaceVariant)

**Accessibility Verification (Optional - if screen reader available):**
- ✅ Each button announces: "[Preset Name], Double tap to select this brush preset, Button"
- ✅ Selected preset announces: "[Preset Name], Selected, Double tap to select this brush preset, Button"

**Validation Notes:**
- Test all 8 brush presets
- Switch themes using app settings or system theme
- Take screenshots of selected button in both themes for documentation
- Verify the fix from subtask 2-1 is working (onPrimaryContainer instead of primary)
- Check that the button contrast issue is resolved (no solid color blocks)

**Known Issue Fixed:**
- **Before:** Selected buttons appeared as solid color blocks with poor contrast
- **After:** Selected buttons use semantic theme colors (primaryContainer + onPrimaryContainer)

---

### Step 4: Draw Strokes and Verify Smooth Rendering

**Action:**
1. Select a brush preset (start with "标准笔刷" - Standard Brush)
2. Draw continuous strokes on the canvas
3. Test different brush sizes (5, 20, 50, 100 pixels)
4. Test different brush presets:
   - Hard brushes: 铅笔, 细笔, 标准笔刷, 粗笔刷
   - Soft brushes: 软笔刷, 喷枪, 马克笔
   - Special: 涂抹笔
5. Draw rapid strokes (fast mouse movements)
6. Draw slow strokes (deliberate movements)

**Expected Results:**

#### Rendering Quality:
- ✅ Strokes are smooth (no jagged edges or gaps)
- ✅ Strokes follow mouse/pointer trajectory accurately
- ✅ Brush opacity is applied correctly (semi-transparent strokes)
- ✅ Brush hardness affects edge softness (hard = sharp, soft = blurry)
- ✅ No artifacts or visual glitches

#### Performance (Subtask 3-1, 3-2, 3-3 fixes):
- ✅ **Frame rate:** ≥60fps during drawing (16.67ms per frame)
- ✅ **No lag:** Strokes appear immediately without delay
- ✅ **Responsiveness:** Canvas feels responsive to input
- ✅ **Cursor rendering:** Cursor follows pointer smoothly (optimized via cursorNotifier)
- ✅ **Spatial culling:** Only visible layers are rendered (zoomed-in views should be faster)

#### Soft Brush Performance (Known Limitation):
- ⚠️ **Soft brushes (hardness < 50%) may have slightly reduced fps** due to MaskFilter.blur (30-40fps expected)
- ⚠️ This is a known limitation documented in canvas_performance_profile.md (Priority 1.1 - CRITICAL)
- ℹ️ Hard brushes (hardness ≥ 50%) should maintain 60fps

**Validation Notes:**
- Use Flutter DevTools Performance overlay to measure fps (if available)
- Test on a clean canvas (single layer) for baseline performance
- Draw strokes covering the entire canvas
- Verify that contradictory CustomPainter flags have been removed (Subtask 3-1 fix)
- Check that CursorPainter uses dedicated cursorNotifier (Subtask 3-2 fix)
- Verify spatial culling is working by zooming in and drawing (Subtask 3-3 fix)

**Performance Benchmarks:**
| Operation | Target | Measurement Method |
|-----------|--------|-------------------|
| Drawing with hard brush | ≥60fps | Flutter DevTools Performance overlay |
| Drawing with soft brush | ≥30fps | Flutter DevTools Performance overlay |
| Stroke latency | <50ms | Subjective feel (should feel instant) |
| Cursor rendering | No lag | Visual inspection (should follow pointer smoothly) |

---

### Step 5: Test Pan/Zoom Operations and Verify Responsiveness

**Action:**
1. **Pan Operations:**
   - Middle mouse button + drag (or Space + drag)
   - Pan around the canvas
   - Pan rapidly back and forth
2. **Zoom Operations:**
   - Mouse wheel to zoom in/out
   - Zoom to 200%, 400%, 800%
   - Zoom back to 100%, 50%, 25%
3. **Combined Operations:**
   - Pan while zoomed in
   - Draw while zoomed in
   - Draw while panning

**Expected Results:**

#### Pan Operations:
- ✅ Canvas pans smoothly with mouse movement
- ✅ No stuttering or frame drops during pan
- ✅ Pan stops immediately when mouse button released
- ✅ Canvas bounds are respected (cannot pan infinitely)

#### Zoom Operations:
- ✅ Canvas zooms smoothly (no discrete jumps)
- ✅ Zoom is centered on mouse pointer position
- ✅ No pixelation or artifacts during zoom
- ✅ Zoom in/out maintains canvas clarity

#### Combined Operations:
- ✅ Drawing while zoomed in works correctly
- ✅ Drawing while panning does not cause lag
- ✅ Spatial culling improves performance at high zoom levels (Subtask 3-3 fix)

**Performance Notes:**
- At high zoom levels (e.g., 400% on a 4096x4096 canvas), only the visible area should be rendered
- This spatial culling optimization should provide 2-5x performance improvement
- Frame rate should remain ≥60fps during pan/zoom

**Validation Notes:**
- Test on a canvas with multiple layers (3-5 layers) to verify culling
- Verify that off-screen layers are not being rendered (performance check)
- Check that canvas transforms (pan, zoom, rotate, mirror) are optimized
- Ensure the viewport bounds calculation is accurate

---

### Step 6: Switch Between Light and Dark Themes and Verify Button Contrast

**Action:**
1. Start in light theme
2. Select a brush preset and note the selected button appearance
3. Switch to dark theme (via app settings or system theme)
4. Verify the selected button is still clearly visible
5. Switch back to light theme
6. Repeat for all 8 brush presets

**Expected Results:**

#### Light Theme:
- ✅ Selected button background: Light color (e.g., light blue/purple)
- ✅ Selected button icon/text: Dark color (high contrast)
- ✅ **Contrast ratio:** ≥4.5:1 (WCAG AA standard)
- ✅ Button is clearly identifiable as "selected"

#### Dark Theme:
- ✅ Selected button background: Dark color (e.g., dark blue/purple)
- ✅ Selected button icon/text: Light color (high contrast)
- ✅ **Contrast ratio:** ≥4.5:1 (WCAG AA standard)
- ✅ Button is clearly identifiable as "selected"

#### Theme Switching:
- ✅ Theme switch is instant (no lag)
- ✅ Selected button remains selected after theme switch
- ✅ No visual glitches during theme transition
- ✅ All canvas elements update to new theme colors

**Validation Notes:**
- This test verifies the fix from subtask 2-1 (brush button contrast)
- The fix uses semantic theme colors (primaryContainer + onPrimaryContainer)
- This ensures the buttons automatically adapt to any theme
- Test all Material 3 theme variants (if available in app)

**Known Issue Fixed:**
- **Before:** Selected button used `primary` text/icon color, which had poor contrast on `primaryContainer` background in dark themes
- **After:** Selected button uses `onPrimaryContainer` text/icon color, which is guaranteed to have sufficient contrast

---

### Step 7: Create 10+ Layers and Verify Performance Remains Smooth

**Action:**
1. Create a new layer (Layer Panel → Add Layer button)
2. Draw strokes on the layer
3. Repeat until you have 10+ layers
4. Test the following operations:
   - Toggle layer visibility on/off
   - Change layer opacity
   - Reorder layers (drag and drop)
   - Delete layers
   - Merge layers (if feature exists)
5. Draw strokes with 10+ layers present
6. Pan/zoom with 10+ layers present

**Expected Results:**

#### Layer Management:
- ✅ Can create 10+ layers without errors
- ✅ Each layer is listed in the layer panel
- ✅ Layer thumbnails are generated correctly
- ✅ Toggling visibility updates canvas immediately
- ✅ Changing opacity updates canvas in real-time
- ✅ Reordering layers updates canvas rendering order

#### Performance with 10+ Layers:
- ✅ **Frame rate:** ≥60fps during drawing (if all layers have content)
- ✅ **No lag:** Layer operations (toggle, opacity, reorder) are instant
- ✅ **Spatial culling:** Off-screen layers are not rendered (Subtask 3-3 fix)
- ✅ **Memory usage:** <500MB (per canvas_performance_profile.md benchmark)

#### Layer Rendering:
- ✅ Layers render in correct order (bottom to top)
- ✅ Transparent layers show layers beneath correctly
- ✅ Opacity is applied correctly for each layer
- ✅ Layer blends modes (if any) work as expected

**Stress Test (Optional):**
- Create 20+ layers
- Draw on each layer
- Verify performance remains acceptable (≥30fps)

**Validation Notes:**
- This test verifies the layer system scalability
- Spatial culling should provide 2-5x improvement when zoomed in
- If performance degrades significantly, investigate:
  - Are all layers being rendered even when off-screen? (spatial culling bug)
  - Is layer caching working correctly? (layer_painter.dart optimizations)
  - Are there unnecessary repaints? (check renderNotifier usage)

**Performance Benchmarks:**
| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Drawing with 10 layers | ≥60fps | Flutter DevTools Performance overlay |
| Layer toggle latency | <50ms | Stopwatch (should feel instant) |
| Memory with 10 layers | <500MB | Flutter DevTools Memory tab |
| Zoom with 10 layers (spatial culling) | 2-5x faster | Comparative test (before/after not applicable) |

---

## Additional Verification Tests

### Test A: Accessibility Labels (Subtask 2-2)

**Action:**
1. Enable screen reader (TalkBack on Android, VoiceOver on iOS, Narrator on Windows)
2. Navigate to brush preset buttons
3. Listen to the announcements

**Expected Results:**
- ✅ Each button announces: "[Preset Name], Double tap to select this brush preset, Button"
- ✅ Selected preset announces: "[Preset Name], Selected, Double tap to select this brush preset, Button"
- ✅ All buttons are reachable via screen reader gestures
- ✅ No unlabeled buttons or icons

**Note:** This test requires accessibility tools to be enabled on your system.

---

### Test B: Undo/Redo with Brush Presets

**Action:**
1. Select a brush preset (e.g., "软笔刷")
2. Draw strokes
3. Undo (Ctrl+Z or toolbar button)
4. Redo (Ctrl+Y or toolbar button)
5. Select a different preset (e.g., "标准笔刷")
6. Draw more strokes
7. Undo/Redo again

**Expected Results:**
- ✅ Undo removes strokes correctly
- ✅ Redo restores strokes correctly
- ✅ Brush preset changes are preserved during undo/redo
- ✅ No visual glitches during undo/redo

---

### Test C: Save and Export

**Action:**
1. Draw strokes on canvas
2. Click "Save" or "Export" button
3. Verify the image is exported correctly
4. Return to img2img panel
5. Verify the exported image appears as source image

**Expected Results:**
- ✅ Exported image contains all drawn strokes
- ✅ Exported image has correct dimensions
- ✅ Image quality is preserved
- ✅ Img2Img panel shows the exported image as source image

---

## Regression Prevention Tests

These tests verify that previously fixed issues do not reoccur.

### Regression Test 1: Brush Button Visibility (Subtask 2-1)

**Test:** Select any brush preset and verify the selected button is clearly visible.

**Expected:** Selected button has sufficient contrast (≥4.5:1) in both light and dark themes.

**Failure Condition:** Selected button appears as solid color block with poor contrast (indicates subtask 2-1 fix was broken).

---

### Regression Test 2: CustomPainter Flags (Subtask 3-1)

**Test:** Draw strokes and verify canvas performance is smooth (≥60fps).

**Expected:** No contradictory `isComplex: true` and `willChange: true` flags in LayerPainter CustomPaint widget.

**Verification:** Run `grep -n 'isComplex.*willChange' lib/presentation/widgets/image_editor/canvas/editor_canvas.dart` and expect no matches.

**Failure Condition:** Canvas lags during drawing (indicates subtask 3-1 fix was broken or reverted).

---

### Regression Test 3: CursorPainter Optimization (Subtask 3-2)

**Test:** Move cursor rapidly around canvas and verify cursor rendering is smooth.

**Expected:** Cursor follows pointer immediately without lag.

**Failure Condition:** Cursor lags behind pointer or causes frame drops (indicates subtask 3-2 optimization is not working).

---

### Regression Test 4: Spatial Culling (Subtask 3-3)

**Test:** Create 5 layers with content in different corners of a large canvas (4096x4096). Zoom in to one corner and verify performance.

**Expected:** Frame rate is 2-5x better when zoomed in compared to viewing full canvas.

**Failure Condition:** Frame rate does not improve when zoomed in (indicates spatial culling is not working).

---

## Test Results Documentation

### Test Environment
- **Date:** [Fill in test date]
- **Tester:** [Fill in tester name]
- **Platform:** [Windows/macOS/Linux/Web]
- **Device Specs:** [CPU, RAM, GPU]
- **Flutter Version:** [Run `flutter --version`]

### Test Execution Summary

| Test Step | Status | Notes |
|-----------|--------|-------|
| 1. Open img2img generation screen | ☐ Pass / ☐ Fail | |
| 2. Click 'Draw Sketch' to open canvas | ☐ Pass / ☐ Fail | |
| 3. Select brush presets and verify visibility | ☐ Pass / ☐ Fail | |
| 4. Draw strokes and verify smooth rendering | ☐ Pass / ☐ Fail | |
| 5. Test pan/zoom operations | ☐ Pass / ☐ Fail | |
| 6. Switch themes and verify button contrast | ☐ Pass / ☐ Fail | |
| 7. Create 10+ layers and verify performance | ☐ Pass / ☐ Fail | |
| Regression Test 1: Button visibility | ☐ Pass / ☐ Fail | |
| Regression Test 2: CustomPainter flags | ☐ Pass / ☐ Fail | |
| Regression Test 3: CursorPainter optimization | ☐ Pass / ☐ Fail | |
| Regression Test 4: Spatial culling | ☐ Pass / ☐ Fail | |

### Performance Metrics

| Metric | Measured | Target | Status |
|--------|----------|--------|--------|
| Drawing frame rate (hard brush) | ___ fps | ≥60fps | ☐ Pass / ☐ Fail |
| Drawing frame rate (soft brush) | ___ fps | ≥30fps | ☐ Pass / ☐ Fail |
| Canvas open time | ___ ms | <500ms | ☐ Pass / ☐ Fail |
| Memory with 10 layers | ___ MB | <500MB | ☐ Pass / ☐ Fail |
| Brush selection response | ___ ms | <50ms | ☐ Pass / ☐ Fail |

### Issues Found

**Issue 1:** [Description]
- **Severity:** [Critical/High/Medium/Low]
- **Steps to Reproduce:** [Steps]
- **Expected Behavior:** [What should happen]
- **Actual Behavior:** [What actually happened]
- **Screenshots:** [Attach if applicable]

**Issue 2:** [Description]
- ...

### Overall Assessment

- **All Tests Passed:** ☐ Yes / ☐ No
- **Ready for QA Sign-off:** ☐ Yes / ☐ No
- **Blocker Issues:** [List any critical issues that prevent sign-off]
- **Recommendations:** [Any suggestions for further improvements]

---

## References

- **Spec:** `./.auto-claude/specs/016-bug/spec.md`
- **Implementation Plan:** `./.auto-claude/specs/016-bug/implementation_plan.json`
- **Architecture Audit:** `docs/canvas_architecture_audit.md`
- **Performance Profile:** `docs/canvas_performance_profile.md`
- **Improvement Recommendations:** `docs/canvas_improvement_recommendations.md`
- **Subtask 2-1:** Brush button contrast fix
- **Subtask 2-2:** Accessibility labels
- **Subtask 3-1:** Remove contradictory CustomPainter flags
- **Subtask 3-2:** Optimize CursorPainter repaint behavior
- **Subtask 3-3:** Implement spatial culling
- **Subtask 4-1:** Unit tests (brush_tool_test.dart, editor_canvas_test.dart)
- **Subtask 4-2:** Integration tests (canvas_brush_selection_test.dart)
- **Subtask 4-3:** Run all existing tests (98/98 tests pass)
- **Subtask 5-1:** Add missing translations (app_en.arb, app_zh.arb)

---

## Conclusion

This comprehensive test plan ensures that all fixes implemented in Phases 1-5 are working correctly and that the img2img canvas workflow meets the performance and usability requirements defined in the spec.

**Key Success Criteria:**
1. ✅ Brush preset buttons are clearly visible when selected (light and dark themes)
2. ✅ Canvas rendering is smooth (≥60fps for hard brushes, ≥30fps for soft brushes)
3. ✅ Pan/zoom operations are responsive
4. ✅ Multi-layer performance is acceptable (10+ layers)
5. ✅ No regressions from previous fixes

**Test Execution Time Estimate:** 45-60 minutes

**Next Steps After Testing:**
1. Document all test results in the "Test Results Documentation" section above
2. Attach screenshots of key test cases (especially brush button visibility in both themes)
3. Report any issues found with detailed reproduction steps
4. If all tests pass, mark subtask-5-2 as "completed" in implementation_plan.json
5. Proceed to subtask-5-3: Finalize architecture audit documentation
