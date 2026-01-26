# Manual Verification Checklist

## Overview

This document provides step-by-step manual verification guides for the 16 improvement suggestions for the NovelAI Universal Launcher. Each verification includes detailed instructions, expected outcomes, and tools required.

**Document Version:** 1.0
**Last Updated:** 2026-01-26
**Total Improvements:** 14

**Note:** The specification mentions "16 improvement suggestions" but only defines 14 unique improvement IDs (IMPR-001 through IMPR-008, IMPR-011, IMPR-012, IMPR-013 through IMPR-016). This document covers all 14 defined improvements.

---

## Table of Contents

1. [UI Layout Tests (IMPR-001~004)](#ui-layout-tests)
2. [Feature Flags (IMPR-005, 013~016)](#feature-flags)
3. [Workflow Tests (IMPR-006~008, 012)](#workflow-tests)
4. [Performance Tests (IMPR-011)](#performance-tests)

---

## UI Layout Tests

### IMPR-001: Main Layout Structure Verification

**Description:** Verify the main application layout matches design specifications

**Tools Required:**
- Flutter DevTools
- NovelAI Launcher (running on Windows desktop)
- Reference screenshots: `test/screenshots/reference/main_layout.png`

**Verification Steps:**

1. **Launch Application**
   ```bash
   flutter run -d windows
   ```
   Wait for the application to fully load

2. **Connect Flutter DevTools**
   - In the terminal where Flutter is running, press `v` to open DevTools
   - Alternatively, open DevTools manually: `flutter pub global run devtools`
   - Connect to your running Flutter application

3. **Navigate to Widget Tree Inspector**
   - In DevTools, go to the **Inspector** tab
   - Expand the widget tree to locate the main layout components

4. **Capture Screenshot**
   - In DevTools, click the **Screenshot** button (camera icon)
   - Save the screenshot as: `test/screenshots/actual/impr-001-main-layout.png`
   - Compare with reference: `test/screenshots/reference/main_layout.png`

5. **Measure Layout Dimensions**
   - In DevTools **Layout Explorer** sub-tab
   - Click on the main container widget
   - Record the following dimensions:
     - Window width: _______ px
     - Window height: _______ px
     - Sidebar width (if visible): _______ px
     - Content area width: _______ px

6. **Verify Against Spec**
   - Layout tolerance: ±5px from reference
   - All major UI components visible and properly positioned
   - No overlapping widgets or layout breaks

**Expected Outcome:**
- [ ] Layout dimensions match design spec within ±5px tolerance
- [ ] All UI components render without overlap
- [ ] Screenshot matches reference image
- [ ] No layout warnings in DevTools

**Pass/Fail Criteria:**
- **PASS:** All dimensions within tolerance, no layout issues
- **FAIL:** Any dimension exceeds tolerance or layout problems detected

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

### IMPR-002: Prompt Editor Layout Verification

**Description:** Verify the prompt editor section layout and spacing

**Tools Required:**
- Flutter DevTools
- Reference screenshots: `test/screenshots/reference/prompt_editor.png`

**Verification Steps:**

1. **Navigate to Prompt Editor**
   - Launch application: `flutter run -d windows`
   - Click on the generation/main prompt editor section
   - Ensure prompt editor is fully visible

2. **Connect DevTools and Inspect**
   - Open DevTools and navigate to **Inspector** tab
   - In the widget tree, locate `PromptEditor` or similar widget

3. **Measure Component Dimensions**
   Using DevTools **Layout Explorer**, measure:
   - Prompt box height: _______ px
   - Spacing between prompt boxes: _______ px
   - Tag suggestion panel width (if visible): _______ px
   - Character bar width (if visible): _______ px
   - Padding from edges: _______ px (top), _______ px (left), _______ px (right), _______ px (bottom)

4. **Capture Screenshot**
   - Use DevTools Screenshot feature
   - Save as: `test/screenshots/actual/impr-002-prompt-editor.png`
   - Compare with reference screenshot

5. **Check Responsive Behavior**
   - Resize window to minimum supported width (typically 800px)
   - Verify prompt editor adapts without horizontal scroll
   - Check that all controls remain accessible
   - Resize to maximum supported width
   - Verify layout expands appropriately

**Expected Outcome:**
- [ ] Component dimensions match design spec
- [ ] Proper spacing between UI elements
- [ ] Layout is responsive across window sizes
- [ ] No overflow or clipped content

**Pass/Fail Criteria:**
- **PASS:** All dimensions correct, responsive behavior working
- **FAIL:** Dimension mismatches or responsive issues

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

### IMPR-003: Gallery Grid Layout Verification

**Description:** Verify gallery grid layout and image thumbnail rendering

**Tools Required:**
- Flutter DevTools
- Test images in gallery (minimum 20 images)
- Reference screenshots: `test/screenshots/reference/gallery_grid.png`

**Verification Steps:**

1. **Navigate to Gallery**
   - Launch application
   - Navigate to gallery/history view
   - Ensure at least 20 images are loaded

2. **Inspect Grid Layout**
   - Open DevTools **Inspector** tab
   - Locate the gallery grid widget (likely `GridView` or similar)
   - Check grid configuration:
     - Number of columns: _______
     - Cross-axis spacing: _______ px
     - Main-axis spacing: _______ px
     - Thumbnail aspect ratio: _______

3. **Measure Thumbnail Sizes**
   - Click on a thumbnail widget in DevTools
   - Record dimensions:
     - Thumbnail width: _______ px
     - Thumbnail height: _______ px
     - Thumbnail border radius: _______ px
     - Thumbnail margin: _______ px

4. **Verify Alignment**
   - Check that all thumbnails are aligned in a proper grid
   - No orphaned items or broken rows
   - Thumbnails maintain consistent aspect ratio

5. **Capture Screenshots**
   - Take screenshot at different scroll positions:
     - Top of gallery: `test/screenshots/actual/impr-003-gallery-top.png`
     - Middle of gallery: `test/screenshots/actual/impr-003-gallery-middle.png`
     - Bottom of gallery: `test/screenshots/actual/impr-003-gallery-bottom.png`

6. **Test Different Window Sizes**
   - Resize window to small, medium, and large
   - Verify grid adjusts column count appropriately
   - Check thumbnail scaling maintains aspect ratio

**Expected Outcome:**
- [ ] Grid layout matches design spec
- [ ] Thumbnail sizes are consistent
- [ ] Proper spacing and alignment
- [ ] Responsive to window resizing
- [ ] No layout breaks at any size

**Pass/Fail Criteria:**
- **PASS:** Grid layout correct, thumbnails properly sized and aligned
- **FAIL:** Layout issues, inconsistent thumbnail sizes, or alignment problems

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

### IMPR-004: Settings Panel Layout Verification

**Description:** Verify settings panel layout and control organization

**Tools Required:**
- Flutter DevTools
- Reference screenshots: `test/screenshots/reference/settings_panel.png`

**Verification Steps:**

1. **Open Settings Panel**
   - Launch application
   - Navigate to Settings/Configuration
   - Ensure settings panel is fully visible

2. **Inspect Panel Structure**
   - Open DevTools **Inspector** tab
   - Locate settings panel widget
   - Verify panel structure:
     - Panel width: _______ px
     - Panel height: _______ px (or scrollable)
     - Section headers present and styled correctly
     - Grouping of related settings

3. **Verify Control Layout**
   For each settings category, verify:
   - **Generation Settings:**
     - Sampler dropdown visible and positioned correctly
     - Steps slider accessible
     - Guidance scale slider accessible
   - **Image Settings:**
     - Width/height inputs aligned
     - Scale slider present
   - **Advanced Settings:**
     - Negative prompt box visible
     - Seed input visible
     - Additional options properly grouped

4. **Measure Control Spacing**
   - Vertical spacing between setting groups: _______ px
   - Horizontal spacing between label and control: _______ px
   - Indentation for nested settings: _______ px

5. **Test Scroll Behavior**
   - If settings panel is scrollable:
     - Scroll to bottom
     - Verify all settings accessible
     - No cut-off content
     - Smooth scrolling behavior

6. **Capture Screenshot**
   - Take full panel screenshot: `test/screenshots/actual/impr-004-settings-full.png`
   - Take screenshots of each section for detailed comparison

**Expected Outcome:**
- [ ] Settings panel layout matches design
- [ ] All controls properly aligned and accessible
- [ ] Consistent spacing throughout
- [ ] Scroll behavior works correctly
- [ ] No overlapping or cut-off elements

**Pass/Fail Criteria:**
- **PASS:** Layout correct, all controls accessible and properly spaced
- **FAIL:** Alignment issues, overlapping controls, or cut-off content

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

## Feature Flags

### IMPR-005: Vibe Encoding Feature Flag

**Description:** Verify vibe encoding feature can be toggled on/off

**Tools Required:**
- NovelAI Launcher
- Hive storage viewer or app settings
- Test fixture: `test/fixtures/images/test_vibe_image.png`

**Verification Steps:**

1. **Locate Feature Flag**
   - Launch application: `flutter run -d windows`
   - Navigate to Settings → Advanced → Feature Flags
   - Look for "Enable Vibe Encoding" or similar flag
   - Alternatively, open Hive storage using Hive inspector tool

2. **Verify Flag Default State**
   - Check if vibe encoding is enabled by default
   - Current state: [ ] ENABLED [ ] DISABLED

3. **Test Flag Toggle**
   - **Toggle OFF (if currently ON):**
     - Uncheck the vibe encoding flag
     - Restart application if required
     - Navigate to prompt editor
     - Upload test image: `test/fixtures/images/test_vibe_image.png`
     - Verify vibe encoding controls are hidden or disabled
     - Verify uploaded image does NOT consume points (check point display)

   - **Toggle ON (if currently OFF):**
     - Enable the vibe encoding flag
     - Restart application if required
     - Navigate to prompt editor
     - Upload test image: `test/fixtures/images/test_vibe_image.png`
     - Verify vibe encoding controls are visible and functional
     - Verify uploaded image shows "vibe" indicator
     - Verify uploaded image does NOT consume points

4. **Verify State Persistence**
   - Set flag to desired state (ON or OFF)
   - Fully close application
   - Relaunch application
   - Verify flag state persists across restarts

5. **Test UI Response**
   - Verify UI updates immediately when flag toggled
   - No app restart required for UI changes (preferred)
   - No visual glitches or layout shifts

**Expected Outcome:**
- [ ] Feature flag accessible in settings
- [ ] Toggle changes feature availability
- [ ] State persists across app restarts
- [ ] UI responds appropriately to flag state
- [ ] Vibe encoding works when enabled, hidden when disabled

**Pass/Fail Criteria:**
- **PASS:** Flag toggles correctly, UI updates, state persists
- **FAIL:** Flag doesn't work, state doesn't persist, or UI issues

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

### IMPR-013: Multi-Prompt Box Feature Flag

**Description:** Verify multi-prompt box feature can be toggled

**Tools Required:**
- NovelAI Launcher
- Hive storage viewer or app settings

**Verification Steps:**

1. **Locate Feature Flag**
   - Launch application
   - Navigate to Settings → Advanced → Feature Flags
   - Find "Enable Multi-Prompt Boxes" or similar flag
   - Current state: [ ] ENABLED [ ] DISABLED

2. **Test Flag DISABLED State**
   - Ensure multi-prompt flag is OFF
   - Restart app if required
   - Navigate to prompt editor
   - Verify only ONE prompt box is visible
   - Verify no "Add Prompt Box" button or controls
   - Verify prompt editor UI is simplified (single box mode)

3. **Test Flag ENABLED State**
   - Enable multi-prompt flag
   - Restart app if required
   - Navigate to prompt editor
   - Verify multiple prompt boxes are visible
   - Verify "Add Prompt Box" or similar control exists
   - Verify each prompt box has independent controls:
     - [ ] Positive/Negative prompt toggle
     - [ ] Tag suggestions
     - [ ] Autofill functionality

4. **Verify State Persistence**
   - Toggle flag to different state
   - Close and relaunch application
   - Verify state is remembered
   - Repeat test for both ON and OFF states

5. **Test Data Migration**
   - Create prompts in multi-prompt mode
   - Disable multi-prompt flag
   - Verify prompts are preserved or migrated appropriately
   - Re-enable flag
   - Verify prompts are restored

**Expected Outcome:**
- [ ] Flag controls multi-prompt feature visibility
- [ ] Single prompt mode works when flag is OFF
- [ ] Multi-prompt mode works when flag is ON
- [ ] State persists across restarts
- [ ] Prompt data preserved/migrated correctly when toggling

**Pass/Fail Criteria:**
- **PASS:** Flag works correctly, UI adapts, data preserved
- **FAIL:** Flag doesn't control feature, or data loss on toggle

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

### IMPR-014: Character Bar Feature Flag

**Description:** Verify character bar feature can be toggled

**Tools Required:**
- NovelAI Launcher
- Hive storage viewer or app settings

**Verification Steps:**

1. **Locate Feature Flag**
   - Launch application
   - Navigate to Settings → UI → Character Bar
   - Find "Show Character Bar" or similar flag
   - Current state: [ ] ENABLED [ ] DISABLED

2. **Test Flag ENABLED State**
   - Ensure character bar flag is ON
   - Navigate to prompt editor or main view
   - Verify character bar is visible
   - Verify character bar shows:
     - [ ] Character count badge (e.g., "3/6")
     - [ ] Add character button
     - [ ] Character list if characters added
     - [ ] Expand/collapse control

3. **Test Flag DISABLED State**
   - Toggle character bar flag OFF
   - Verify character bar immediately hides
   - Verify no blank space where bar was (layout should collapse)
   - Verify prompt editor expands to use available space
   - Check for no visual glitches or layout issues

4. **Verify State Persistence**
   - Set flag to OFF
   - Close and relaunch application
   - Verify character bar remains hidden
   - Set flag to ON
   - Close and relaunch
   - Verify character bar remains visible

5. **Test Layout Adaptation**
   - With character bar VISIBLE:
     - Measure prompt editor width: _______ px
   - With character bar HIDDEN:
     - Measure prompt editor width: _______ px
   - Verify prompt editor expands appropriately when bar hidden
   - Verify no horizontal scroll appears

**Expected Outcome:**
- [ ] Flag toggles character bar visibility
- [ ] Layout adapts appropriately when toggling
- [ ] State persists across app restarts
- [ ] No layout issues or visual glitches
- [ ] Prompt editor expands when bar hidden

**Pass/Fail Criteria:**
- **PASS:** Flag works, layout adapts, state persists
- **FAIL:** Flag doesn't work, or layout problems when toggling

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

### IMPR-015: Drag-and-Drop Metadata Feature Flag

**Description:** Verify drag-and-drop metadata extraction can be toggled

**Tools Required:**
- NovelAI Launcher
- Test images with PNG metadata: `test/fixtures/images/test_metadata.png`
- Hive storage viewer or app settings

**Verification Steps:**

1. **Locate Feature Flag**
   - Launch application
   - Navigate to Settings → Advanced → Features
   - Find "Enable Drag-and-Drop Metadata" or similar flag
   - Current state: [ ] ENABLED [ ] DISABLED

2. **Test Flag ENABLED State**
   - Ensure metadata extraction flag is ON
   - Navigate to prompt editor
   - Drag test image: `test/fixtures/images/test_metadata.png`
   - Drop into prompt editor area
   - Verify metadata is extracted and fields populate:
     - [ ] Prompt text extracted and inserted
     - [ ] Negative prompt extracted (if present)
     - [ ] Sampler setting applied
     - [ ] Steps value applied
     - [ ] Scale value applied
     - [ ] Seed value applied
     - [ ] Dimensions applied (width/height)

3. **Test Flag DISABLED State**
   - Toggle metadata extraction flag OFF
   - Drag and drop same test image
   - Verify NO metadata extraction occurs:
     - [ ] Prompt fields remain unchanged
     - [ ] Settings remain unchanged
     - [ ] Image may still upload as reference (depends on implementation)
     - [ ] No automatic population of fields

4. **Verify State Persistence**
   - Toggle flag between states
   - Close and relaunch application
   - Verify last state is remembered
   - Test both ON and OFF states

5. **Test User Feedback**
   - With flag ON: Verify visual feedback when metadata extracted
   - With flag OFF: Verify appropriate behavior (image handled differently)
   - Check for no error messages or crashes in either state

**Expected Outcome:**
- [ ] Flag controls metadata extraction behavior
- [ ] Metadata extracted when flag is ON
- [ ] Metadata NOT extracted when flag is OFF
- [ ] State persists across restarts
- [ ] No errors or crashes when toggling

**Pass/Fail Criteria:**
- **PASS:** Flag controls extraction, correct behavior in both states
- **FAIL:** Flag doesn't work, or extraction occurs when flag is OFF

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

### IMPR-016: Advanced Settings Panel Feature Flag

**Description:** Verify advanced settings panel can be toggled

**Tools Required:**
- NovelAI Launcher
- Hive storage viewer or app settings

**Verification Steps:**

1. **Locate Feature Flag**
   - Launch application
   - Navigate to Settings or check feature flags
   - Find "Show Advanced Settings" or similar flag
   - Current state: [ ] ENABLED [ ] DISABLED

2. **Test Flag ENABLED State**
   - Ensure advanced settings flag is ON
   - Navigate to settings panel
   - Verify advanced settings section is visible:
     - [ ] Seed input/controls
     - [ ] Negative prompt box
     - [ ] Sampler-specific options
     - [ ] Custom model selection
     - [ ] Advanced generation parameters
   - Verify all advanced controls are functional

3. **Test Flag DISABLED State**
   - Toggle advanced settings flag OFF
   - Verify advanced section hides or collapses
   - Verify basic settings remain visible and functional:
     - [ ] Sampler selection
     - [ ] Steps slider
     - [ ] Guidance scale
     - [ ] Image dimensions
   - Verify settings panel shows simplified view
   - Verify layout adjusts (no blank space)

4. **Verify Settings Preserved**
   - Configure some advanced settings (seed, custom parameters)
   - Disable advanced settings flag
   - Verify advanced settings are saved but hidden
   - Re-enable flag
   - Verify advanced settings are restored to previous values

5. **Test State Persistence**
   - Toggle flag to OFF
   - Close and relaunch application
   - Verify flag remains OFF
   - Toggle flag to ON
   - Close and relaunch
   - Verify flag remains ON

**Expected Outcome:**
- [ ] Flag toggles advanced settings visibility
- [ ] Advanced settings accessible when flag is ON
- [ ] Advanced settings hidden but preserved when flag is OFF
- [ ] Basic settings always accessible
- [ ] State persists across restarts

**Pass/Fail Criteria:**
- **PASS:** Flag works, settings preserved, layout adapts
- **FAIL:** Flag doesn't work, or settings lost when toggling

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

## Workflow Tests

### IMPR-006: Multi-Prompt Box Workflow

**Description:** Verify multiple prompt boxes work independently and correctly

**Tools Required:**
- NovelAI Launcher with multi-prompt enabled (IMPR-013)
- DevTools for monitoring state (optional)

**Verification Steps:**

1. **Enable Multi-Prompt Mode**
   - Launch application: `flutter run -d windows`
   - Navigate to Settings → Feature Flags
   - Enable "Enable Multi-Prompt Boxes" flag
   - Restart if required
   - Navigate to prompt editor

2. **Verify Initial Prompt Boxes**
   - Verify at least 2 prompt boxes are visible by default
   - Count visible prompt boxes: _______
   - Verify each box has:
     - [ ] Positive/Negative toggle
     - [ ] Text input area
     - [ ] Tag suggestion button
     - [ ] Clear button
     - [ ] Label/indicator (e.g., "Prompt 1", "Prompt 2")

3. **Add New Prompt Box**
   - Click "Add Prompt Box" or similar button
   - Verify new prompt box appears
   - Verify it's properly positioned and styled
   - Repeat to add 3-4 prompt boxes total

4. **Test Independent Editing**
   - In Prompt Box 1, enter: "outdoor scenery, mountains"
   - In Prompt Box 2, enter: "portrait, young woman"
   - In Prompt Box 3, enter: "abstract art, colorful"
   - Verify each box maintains its own text independently
   - Toggle one to negative prompt
   - Verify other boxes remain positive

5. **Test Tag Insertion**
   - Click tag suggestion button in Prompt Box 1
   - Search for and select a tag (e.g., "sunset")
   - Verify tag is inserted into Prompt Box 1 ONLY
   - Verify Prompt Box 2 and 3 are unchanged
   - Repeat for other boxes

6. **Test Clear Functionality**
   - Clear text in Prompt Box 2
   - Verify only Prompt Box 2 is cleared
   - Verify Prompt Box 1 and 3 unchanged

7. **Test Delete Prompt Box**
   - Click delete/remove button on Prompt Box 3
   - Verify Prompt Box 3 is removed
   - Verify Prompt Box 1 and 2 remain and unchanged
   - Verify no blank space or layout issues

8. **Test Prompt Combination**
   - Configure multiple prompts with different content
   - Trigger generation (if API available) or preview
   - Verify prompts are combined correctly:
     - [ ] All positive prompts included
     - [ ] Negative prompts properly separated
     - [ ] No duplicate content
     - [ ] Proper formatting

**Expected Outcome:**
- [ ] Multiple prompt boxes visible and functional
- [ ] Each prompt box operates independently
- [ ] Add/delete functionality works correctly
- [ ] Tag insertion targets correct box
- [ ] Clear functionality isolated to specific box
- [ ] Prompts combine correctly for generation

**Pass/Fail Criteria:**
- **PASS:** All multi-prompt features work, boxes independent
- **FAIL:** Cross-contamination between boxes, or add/delete issues

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

### IMPR-007: Tag Suggestions Integration with Multi-Prompt

**Description:** Verify tag suggestions work correctly with multiple prompt boxes

**Tools Required:**
- NovelAI Launcher with multi-prompt enabled
- Active internet connection (for tag database)

**Verification Steps:**

1. **Setup Multi-Prompt Environment**
   - Launch application
   - Enable multi-prompt mode
   - Navigate to prompt editor
   - Ensure 3+ prompt boxes are visible

2. **Test Tag Suggestions per Box**

   **Prompt Box 1:**
   - Click tag suggestion button in Box 1
   - Search for: "landscape"
   - Select "mountain landscape" tag
   - Verify tag inserts into Box 1 prompt text
   - Verify Box 2 and 3 are unchanged

   **Prompt Box 2:**
   - Click tag suggestion button in Box 2
   - Search for: "character"
   - Select "young woman" tag
   - Verify tag inserts into Box 2 prompt text
   - Verify Box 1 and 3 are unchanged

   **Prompt Box 3:**
   - Click tag suggestion button in Box 3
   - Search for: "art style"
   - Select "watercolor painting" tag
   - Verify tag inserts into Box 3 prompt text
   - Verify Box 1 and 2 are unchanged

3. **Test Weighted Tags**
   - In Box 1, search for "dramatic lighting"
   - Add with increased weight (e.g., using bracket syntax)
   - Verify weight syntax applied correctly
   - Verify other boxes unaffected

4. **Test Recent Tags**
   - Add several tags to different boxes
   - Close tag suggestion panel
   - Reopen tag suggestions in Box 1
   - Verify recent tags shown are specific to Box 1 usage
   - Repeat for Box 2 and verify separate history

5. **Test Tag Categories**
   - In Box 1, explore different tag categories:
     - [ ] Characters
     - [ ] Settings/Backgrounds
     - [ ] Styles/Mediums
     - [ ] Themes
   - Verify category filtering works per box
   - Verify categories are independent across boxes

6. **Test Negative Prompt Tags**
   - Toggle Box 2 to negative prompt mode
   - Open tag suggestions in Box 2
   - Search and select tags
   - Verify tags insert into negative prompt
   - Verify tag suggestions include negative-appropriate tags

7. **Test Autofill Integration**
   - Type partial tag in Box 1: "sun..."
   - Verify autofill suggestions appear below Box 1
   - Select "sunset" from autofill
   - Verify tag completes in Box 1 only
   - Repeat for Box 2 with different partial tag

**Expected Outcome:**
- [ ] Tag suggestions work independently for each prompt box
- [ ] Tag insertion targets correct box only
- [ ] Recent tag history is per-box
- [ ] Weighted tags work correctly
- [ ] Negative prompt tag suggestions work
- [ ] Autofill integrates correctly with multi-prompt

**Pass/Fail Criteria:**
- **PASS:** Tag suggestions work correctly with all prompt boxes
- **FAIL:** Cross-box interference or tag insertion issues

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

### IMPR-008: Prompt Box State Persistence

**Description:** Verify multi-prompt box state persists across app restarts

**Tools Required:**
- NovelAI Launcher with multi-prompt enabled
- DevTools (optional, for monitoring Hive storage)

**Verification Steps:**

1. **Configure Multi-Prompt State**
   - Launch application: `flutter run -d windows`
   - Enable multi-prompt mode
   - Add 4 prompt boxes total
   - Configure each box:
     - Box 1: "outdoor landscape, mountains, river"
     - Box 2: "portrait, young woman, detailed face"
     - Box 3: "abstract art, colorful shapes, modern"
     - Box 4: Toggle to negative, enter: "blurry, low quality"
   - Adjust weights/scales if available

2. **Verify State Saved**
   - Open DevTools and connect to app
   - Check Hive storage or local storage
   - Look for multi-prompt state keys
   - Verify state is persisted to storage

3. **Test Application Restart**
   - Fully close the application
   - Relaunch: `flutter run -d windows`
   - Navigate to prompt editor
   - Verify all 4 prompt boxes are restored
   - Verify each box has correct content:
     - [ ] Box 1: "outdoor landscape, mountains, river"
     - [ ] Box 2: "portrait, young woman, detailed face"
     - [ ] Box 3: "abstract art, colorful shapes, modern"
     - [ ] Box 4: Negative mode with "blurry, low quality"
   - Verify box count matches (4 boxes)

4. **Test Partial State Changes**
   - Delete Box 3
   - Modify Box 1 to: "outdoor landscape, mountains, river, sunset"
   - Add Box 5 with: "test content"
   - Close and relaunch application
   - Verify changes persisted:
     - [ ] Box 3 is deleted (only 4 boxes total)
     - [ ] Box 1 has modified content
     - [ ] Box 5 is present

5. **Test State Migration**
   - Disable multi-prompt mode
   - Verify prompt state is migrated to single-prompt format
   - Re-enable multi-prompt mode
   - Verify state is restored from single-prompt format
   - Verify all boxes and content are recovered

6. **Test State Reset**
   - Use "Reset All" or "Clear All" if available
   - Verify all prompt boxes reset to default
   - Close and relaunch
   - Verify reset state persists

7. **Test State Corruption Recovery**
   - Manually corrupt stored state (optional advanced test)
   - Restart application
   - Verify graceful recovery (default state or error message)
   - Verify no crashes or hangs

**Expected Outcome:**
- [ ] Multi-prompt state persists across restarts
- [ ] All prompt boxes restored with correct content
- [ ] Box count preserved
- [ ] Negative/positive toggle state preserved
- [ ] Changes to state save correctly
- [ ] State migration works when toggling multi-prompt mode
- [ ] Graceful recovery from corrupted state

**Pass/Fail Criteria:**
- **PASS:** All state persists correctly across restarts
- **FAIL:** State lost or corrupted on restart

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

### IMPR-012: Drag-and-Drop Metadata Extraction

**Description:** Verify drag-and-drop image metadata extraction workflow

**Tools Required:**
- NovelAI Launcher
- Test images with PNG metadata: `test/fixtures/images/test_metadata.png`
- Test images without metadata: `test/fixtures/images/test_no_metadata.png`
- DevTools (optional, for monitoring)

**Preparation:**
Create test images with PNG metadata. If not available, use any PNG image and note that metadata extraction will be tested conceptually.

**Verification Steps:**

1. **Enable Drag-and-Drop Metadata**
   - Launch application: `flutter run -d windows`
   - Navigate to Settings → Advanced
   - Ensure "Enable Drag-and-Drop Metadata" flag is ON
   - Navigate to prompt editor

2. **Test Basic Drag-and-Drop (No Metadata)**
   - Drag image: `test/fixtures/images/test_no_metadata.png`
   - Drop into prompt editor area
   - Verify image is accepted (no errors)
   - Verify behavior:
     - [ ] Image may upload as reference attachment
     - [ ] Or visual indication of drop (depends on implementation)
     - [ ] No metadata extraction occurs

3. **Test Metadata Extraction**
   - Drag image: `test/fixtures/images/test_metadata.png`
   - Drop into prompt editor area
   - Verify metadata extraction indicator (loading spinner or progress)
   - Verify fields populate automatically:
     - **Positive Prompt:**
       - Check if prompt text extracted: _______
       - Content matches image metadata? [ ] YES [ ] NO
     - **Negative Prompt:**
       - Check if negative prompt extracted: _______
       - Content matches? [ ] YES [ ] NO
     - **Sampler:**
       - Sampler set to: _______
       - Matches metadata? [ ] YES [ ] NO
     - **Steps:**
       - Steps set to: _______
       - Matches metadata? [ ] YES [ ] NO
     - **Guidance Scale:**
       - Scale set to: _______
       - Matches metadata? [ ] YES [ ] NO
     - **Seed:**
       - Seed set to: _______
       - Matches metadata? [ ] YES [ ] NO
     - **Dimensions:**
       - Width: _______ px
       - Height: _______ px
       - Match metadata? [ ] YES [ ] NO

4. **Test Multi-Prompt Metadata**
   - Enable multi-prompt mode
   - Drag and drop `test_metadata.png`
   - Verify metadata distributes correctly:
     - [ ] Positive prompt goes to main positive box
     - [ ] Negative prompt goes to negative box
     - [ ] Or creates separate boxes if metadata indicates

5. **Test Metadata Override Confirmation**
   - Manually set some parameters (e.g., seed: 12345)
   - Drag and drop metadata image
   - Verify if user is prompted about overwriting:
     - [ ] Confirmation dialog appears
     - [ ] Options: "Overwrite", "Merge", "Cancel"
   - Test each option:
     - **Overwrite:** All settings replaced with metadata
     - **Merge:** Metadata fills only empty fields
     - **Cancel:** No changes made

6. **Test Invalid/Missing Metadata**
   - Drag and drop image with corrupted metadata
   - Verify graceful handling:
     - [ ] Error message or warning displayed
     - [ ] No crash or hang
     - [ ] Partial extraction if some metadata valid
     - [ ] Manual entry still works

7. **Test Multiple Image Drops**
   - Drag and drop first metadata image
   - Verify fields populate
   - Drag and drop second metadata image
   - Verify fields update to new metadata
   - Test with images dropped in quick succession

8. **Test Different Image Formats**
   - Test with PNG images (with metadata): [ ] WORKS [ ] FAILS
   - Test with JPEG images (no PNG metadata): [ ] WORKS [ ] FAILS
   - Verify appropriate behavior for each format

9. **Test Visual Feedback**
   - Verify drag-over visual indicator (highlight drop zone)
   - Verify drop success/failure feedback
   - Verify metadata extraction progress indicator
   - Verify completed state (fields populated indicator)

**Expected Outcome:**
- [ ] Drag-and-drop accepts images correctly
- [ ] Metadata extracts and populates fields accurately
- [ ] All metadata fields mapped to correct inputs
- [ ] User prompted before overwriting manual changes
- [ ] Invalid metadata handled gracefully
- [ ] Works with multi-prompt mode
- [ ] Visual feedback provided throughout process
- [ ] No crashes or hangs

**Pass/Fail Criteria:**
- **PASS:** Metadata extraction works correctly, fields populate, graceful error handling
- **FAIL:** Extraction fails, fields not populated, or crashes occur

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

## Performance Tests

### IMPR-011: Gallery Pagination and Infinite Scroll Performance

**Description:** Verify gallery view maintains 60fps during scrolling and has acceptable memory usage

**Tools Required:**
- NovelAI Launcher with 100+ images in gallery
- Flutter DevTools (Performance tab)
- Test gallery data or generate test images

**Preparation:**
Ensure gallery has at least 100 images for meaningful performance testing. If using test data, generate 100+ test image entries.

**Verification Steps:**

1. **Launch Application with DevTools**
   - Launch application: `flutter run -d windows`
   - Open Flutter DevTools and connect to app
   - Navigate to **Performance** tab
   - Ensure gallery has 100+ images loaded

2. **Start Performance Recording**
   - In DevTools Performance tab, click **Record**
   - Note the start time: _______
   - Navigate to gallery view in app

3. **Baseline Measurements**
   Before scrolling, capture baseline metrics:
   - **Memory:**
     - Current memory usage: _______ MB
     - GC (Garbage Collection) count: _______
   - **Frames:**
     - Current frame rate: _______ fps
   - **Widget Build Count:**
     - Total widgets built: _______

4. **Scroll Performance Test - Rapid Scroll**
   - Scroll rapidly from top to bottom of gallery (100+ items)
   - Use scroll wheel, drag scrollbar, or page down keys
   - Perform 3-5 complete top-to-bottom passes
   - Stop recording in DevTools

   **Analyze Results:**
   - **Frame Rate:**
     - Average FPS during scroll: _______
     - Minimum FPS: _______
     - Maximum FPS: _______
     - Target: 60fps maintained? [ ] YES [ ] NO
   - **Frame Time:**
     - Average frame time: _______ ms
     - Maximum frame time: _______ ms
     - Target: <16.67ms (60fps)? [ ] YES [ ] NO
   - **Jank (Frame Time Warnings):**
     - Number of jank frames: _______
     - Percentage of jank frames: _______%
     - Target: <5%? [ ] YES [ ] NO
   - **Overlay GUI:**
     - Check for red/yellow frame warnings
     - Count warnings: _______

5. **Memory Usage Test**
   - Monitor memory tab in DevTools during scrolling
   - Record memory at different points:
     - Start (top of gallery): _______ MB
     - Middle of gallery: _______ MB
     - Bottom of gallery: _______ MB
     - After scrolling back to top: _______ MB
   - **Calculate Growth:**
     - Peak memory: _______ MB
     - Memory growth from baseline: _______ MB
     - Target: <50MB growth? [ ] YES [ ] NO
   - **Check for Leaks:**
     - After scrolling, return to top
     - Force GC if possible
     - Verify memory returns near baseline
     - Memory after GC: _______ MB
     - Leak suspected if growth >20MB after GC

6. **Widget Build Efficiency**
   - In Performance trace, analyze widget builds
   - Check for unnecessary rebuilds:
     - [ ] Widgets only rebuild when needed
     - [ ] No full tree rebuilds on scroll
     - [ ] Const widgets used where appropriate
   - Identify frequently rebuilt widgets:
     - Most rebuilt widget: _______
     - Build count: _______

7. **Lazy Loading Test**
   - Verify gallery uses lazy loading (viewport-based)
   - Scroll to middle of gallery
   - Check if off-screen widgets are disposed:
     - [ ] Yes, off-screen widgets disposed (efficient)
     - [ ] No, all widgets kept in memory (inefficient)
   - Verify smooth scroll back up (widgets should rebuild)

8. **Image Loading Performance**
   - Monitor network/disk I/O during scroll
   - Verify images load efficiently:
     - [ ] Thumbnails used, not full resolution
     - [ ] Images cached appropriately
     - [ ] No blocking I/O on UI thread
   - Check for placeholder/loading states:
     - [ ] Placeholders shown while loading
     - [ ] Images fade in when loaded

9. **Pagination Test (if applicable)**
   - If gallery uses pagination instead of infinite scroll:
   - Scroll to end of first page
   - Verify next page loads automatically
   - Measure page load time: _______ ms
   - Verify smooth transition between pages
   - Check for duplicate items or gaps

10. **Stress Test**
   - Perform rapid scroll for 2+ minutes
   - Alternate between fast and slow scrolling
   - Monitor for performance degradation:
     - FPS at start: _______
     - FPS after 2 min: _______
     - Degradation: [ ] NONE [ ] MINOR [ ] SIGNIFICANT

11. **Low-End Device Test (if applicable)**
   - If testing on Android, test on lower-end device
   - Repeat scroll performance test
   - Verify acceptable performance even on slower hardware
   - Minimum acceptable: 30fps sustained? [ ] YES [ ] NO

**Expected Outcome:**
- [ ] 60fps maintained during scrolling (or 30fps on low-end)
- [ ] Memory growth <50MB during scrolling
- [ ] Jank frames <5% of total frames
- [ ] No memory leaks (memory returns to baseline after GC)
- [ ] Widget rebuilds optimized (no unnecessary rebuilds)
- [ ] Images load efficiently with caching
- [ ] Smooth pagination/infinite scroll
- [ ] No performance degradation over time

**Pass/Fail Criteria:**
- **PASS:** All performance metrics within acceptable ranges
- **FAIL:** Frame rate drops below target, excessive memory growth, or jank >5%

**Performance Metrics Summary:**
- Average FPS: _______
- Jank Percentage: _______%
- Memory Growth: _______ MB
- GC Count: _______
- Build Count: _______

**Notes:**
___________________________________________________________________________
___________________________________________________________________________

---

## Verification Summary

### Test Completion Checklist

| ID | Description | Status | Tester | Date |
|----|-------------|--------|--------|------|
| IMPR-001 | Main Layout Structure | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-002 | Prompt Editor Layout | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-003 | Gallery Grid Layout | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-004 | Settings Panel Layout | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-005 | Vibe Encoding Feature Flag | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-006 | Multi-Prompt Box Workflow | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-007 | Tag Suggestions Integration | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-008 | Prompt Box State Persistence | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-011 | Gallery Performance | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-012 | Drag-and-Drop Metadata | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-013 | Multi-Prompt Feature Flag | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-014 | Character Bar Feature Flag | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-015 | Drag-and-Drop Metadata Flag | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |
| IMPR-016 | Advanced Settings Flag | [ ] PASS / [ ] FAIL / [ ] SKIPPED | | |

### Overall Statistics

- **Total Tests:** 14
- **Passed:** _______
- **Failed:** _______
- **Skipped:** _______
- **Pass Rate:** _______%

### Blockers and Issues

List any blockers or critical issues found during verification:

1. ___________________________________________________________________
2. ___________________________________________________________________
3. ___________________________________________________________________

### Recommendations

List any recommendations for improvements or fixes:

1. ___________________________________________________________________
2. ___________________________________________________________________
3. ___________________________________________________________________

---

## Appendix A: Flutter DevTools Usage Guide

### Opening DevTools

**Method 1: From Running Flutter App**
```bash
flutter run -d windows
# In the terminal, press 'v' to open DevTools
```

**Method 2: Standalone DevTools**
```bash
flutter pub global activate devtools
flutter pub global run devtools
# Then open http://localhost:9100 in browser
```

### Key DevTools Features for Verification

**1. Inspector Tab**
- **Widget Tree:** Browse widget hierarchy
- **Layout Explorer:** Click widgets to see dimensions and positioning
- **Screenshot:** Capture screenshots of current app state
- **Properties Panel:** View widget properties and state

**2. Performance Tab**
- **Frame Charts:** Visualize frame rendering times
- **Frame Statistics:** See FPS, frame times, jank percentage
- **Memory Profile:** Track memory usage over time
- **Widget Builds:** Identify frequently rebuilt widgets

**3. Memory Tab**
- **Memory Timeline:** See memory allocation and GC events
- **Allocation Tracking:** Identify memory allocations by type
- **Snapshot Analysis:** Compare memory snapshots

### Capturing Screenshots

1. Open DevTools Inspector tab
2. Click the camera icon (Screenshot button)
3. Screenshot appears in DevTools pane
4. Right-click screenshot → "Save image as..."
5. Save to appropriate location in `test/screenshots/actual/`

### Measuring Layout Dimensions

1. Open DevTools Inspector tab
2. Expand widget tree to find target widget
3. Click on widget in tree (highlights in app)
4. In Layout Explorer, view widget's size and position:
   - **Size:** Width x Height in pixels
   - **Position:** (x, y) coordinates
   - **Padding/Margin:** Space around widget

### Recording Performance

1. Open DevTools Performance tab
2. Click "Record" button
3. Perform action in app (e.g., scroll gallery)
4. Click "Stop" button
5. Analyze frame charts and statistics:
   - Look for red/yellow bars (jank)
   - Check FPS counter
   - Review frame time graph

---

## Appendix B: Test Fixture Files

### Required Test Images

Place these test images in `test/fixtures/images/`:

1. **test_vibe_image.png**
   - Purpose: Test vibe encoding (IMPR-005, IMPR-012)
   - Requirements: Any PNG image
   - Size: ~500x500px

2. **test_metadata.png**
   - Purpose: Test drag-and-drop metadata extraction (IMPR-012)
   - Requirements: PNG with embedded metadata
   - Metadata should include:
     - Prompt text
     - Negative prompt
     - Sampler
     - Steps
     - Scale
     - Seed
     - Dimensions

3. **test_no_metadata.png**
   - Purpose: Test drag-and-drop without metadata (IMPR-012)
   - Requirements: PNG without NovelAI metadata
   - Size: ~500x500px

### Generating Test Metadata

To create test images with metadata, use a NovelAI image generation:
1. Generate image with specific parameters
2. Save the PNG
3. This PNG will contain all generation metadata
4. Copy to `test/fixtures/images/test_metadata.png`

---

## Appendix C: Verification Tools Setup

### Hive Storage Inspector

**Install Hive Viewer:**
```bash
# There is no official Hive GUI tool, but you can:
# 1. Use Flutter DevTools to inspect Hive boxes
# 2. Add debug logging to print Hive contents
# 3. Use Hive.inspect() in debug mode
```

**Programmatic Hive Inspection:**
```dart
// In debug mode, add this to main.dart
void inspectHiveBoxes() {
  final box = Hive.box('settings');
  print('All keys: ${box.keys.toList()}');
  print('All values: ${box.toMap()}');
}
```

### Reference Screenshots

**Capturing Reference Screenshots:**
1. Ensure app is in known good state
2. Use Flutter DevTools to capture screenshots
3. Save to `test/screenshots/reference/`
4. Name with descriptive names:
   - `main_layout.png`
   - `prompt_editor.png`
   - `gallery_grid.png`
   - `settings_panel.png`

**Updating Reference Screenshots:**
If UI changes legitimately, update reference screenshots:
1. Capture new screenshot
2. Replace old file in `test/screenshots/reference/`
3. Document change and reason in this manual

---

**End of Manual Verification Document**

**Next Steps:**
- Complete all 14 manual verification tests
- Document results in summary table
- Report blockers and issues
- Provide recommendations for fixes

**Questions or Issues?**
Refer to the main specification document: `./.auto-claude/specs/021-create-comprehensive-verification-checklist-for-pr/spec.md`
