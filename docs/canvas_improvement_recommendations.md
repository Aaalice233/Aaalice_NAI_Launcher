# Canvas System Improvement Recommendations

**Generated:** 2026-01-25
**Component:** Flutter Image Editor Canvas
**Based on:** Architecture Audit (subtask-1-1) + Performance Profile (subtask-1-2)
**Purpose:** Actionable recommendations for improving canvas architecture and performance

---

## Executive Summary

This document synthesizes findings from the architecture audit and performance profiling to provide a prioritized roadmap for canvas system improvements. The overall architecture is **strong (4/5 stars)** but has specific critical issues and optimization opportunities.

**Overall Assessment:**
- ✅ **Architecture:** Well-designed with excellent Manager pattern and separation of concerns
- ⚠️ **Performance:** Good optimizations in place, but critical bottlenecks limit soft brush performance
- ⚠️ **Code Quality:** Some coupling issues and large classes that impact maintainability
- 🔴 **Critical Bug:** Contradictory CustomPainter flags causing performance degradation

**Quick Wins (Immediate Impact):**
1. Fix contradictory CustomPainter flags (10 min, 5-10x performance improvement for some scenarios)
2. Optimize soft brush rendering with stamp cache (4-8 hours, 5-10x improvement)
3. Add spatial culling (2-4 hours, 2-5x improvement for zoomed views)

**Strategic Improvements (Medium-term):**
4. Introduce dependency injection for EditorState (8-16 hours)
5. Split EditorState into smaller coordinators (16-32 hours)
6. Add comprehensive unit tests (40-80 hours)

---

## Priority Matrix

| Priority | Recommendation | Impact | Effort | Risk | ROI |
|----------|---------------|--------|--------|------|-----|
| 🔴 **P0-CRITICAL** | Fix contradictory CustomPainter flags | 🔥🔥🔥🔥🔥 | 🟢 (10 min) | 🟢 Low | ⭐⭐⭐⭐⭐ |
| 🔴 **P0-CRITICAL** | Implement brush stamp cache for soft brushes | 🔥🔥🔥🔥🔥 | 🟡 (4-8 hrs) | 🟡 Medium | ⭐⭐⭐⭐⭐ |
| 🟠 **P1-HIGH** | Add spatial culling for viewport | 🔥🔥🔥🔥 | 🟢 (2-4 hrs) | 🟢 Low | ⭐⭐⭐⭐⭐ |
| 🟠 **P1-HIGH** | Fix brush button contrast issue | 🔥🔥🔥 | 🟢 (1-2 hrs) | 🟢 Low | ⭐⭐⭐⭐ |
| 🟠 **P1-HIGH** | Optimize canvas transformations | 🔥🔥🔥 | 🟢 (1-2 hrs) | 🟢 Low | ⭐⭐⭐⭐ |
| 🟡 **P2-MEDIUM** | Add dependency injection | 🔥🔥🔥 | 🟡 (8-16 hrs) | 🟡 Medium | ⭐⭐⭐ |
| 🟡 **P2-MEDIUM** | Cache path objects for strokes | 🔥🔥 | 🟢 (2-4 hrs) | 🟢 Low | ⭐⭐⭐ |
| 🟡 **P2-MEDIUM** | Optimize CursorPainter repaint | 🔥🔥 | 🟢 (1 hr) | 🟢 Low | ⭐⭐⭐ |
| 🟢 **P3-LOW** | Split EditorState into coordinators | 🔥🔥🔥 | 🔴 (16-32 hrs) | 🔴 High | ⭐⭐ |
| 🟢 **P3-LOW** | Extract action classes from HistoryManager | 🔥 | 🟢 (2-4 hrs) | 🟢 Low | ⭐ |
| 🟢 **P3-LOW** | Add comprehensive unit tests | 🔥🔥🔥🔥 | 🔴 (40-80 hrs) | 🟢 Low | ⭐⭐⭐ |
| 🟢 **P3-LOW** | Split Layer class (renderer/cache) | 🔥🔥 | 🟡 (8-16 hrs) | 🟡 Medium | ⭐⭐ |

**Legend:**
- 🔥 Impact: 🔥🔥🔥🔥🔥 Critical, 🔥🔥🔥🔥 High, 🔥🔥🔥 Medium, 🔥🔥 Low, 🔥 Minimal
- 🟢🟡🔴 Effort: 🟢 < 4 hours, 🟡 4-16 hours, 🔴 > 16 hours
- 🟢🟡🔴 Risk: 🟢 Low, 🟡 Medium, 🔴 High (regression risk)
- ⭐ ROI: Return on Investment (impact vs effort)

---

## Part 1: Critical Performance Fixes (P0)

### 1.1 Fix Contradictory CustomPainter Flags 🔴

**Issue:** `editor_canvas.dart:117-118` uses both `isComplex: true` and `willChange: true`, which contradicts each other.

**Current Code:**
```dart
CustomPaint(
  painter: LayerPainter(state: widget.state),
  isComplex: true,   // "Cache this"
  willChange: true,  // "Don't cache this"
)
```

**Problem:**
- `isComplex: true` tells Flutter to enable raster cache for complex paintings
- `willChange: true` tells Flutter to disable cache (will change every frame)
- **Result:** Undefined behavior, performance degradation

**Fix:**
```dart
CustomPaint(
  painter: LayerPainter(state: widget.state),
  isComplex: true,   // Keep - canvas is complex
  // Remove willChange: true
)
```

**Files to Modify:**
- `lib/presentation/widgets/image_editor/canvas/editor_canvas.dart` (line 118)

**Verification:**
```bash
grep -n 'isComplex.*willChange\|willChange.*isComplex' lib/presentation/widgets/image_editor/canvas/editor_canvas.dart
# Expected: No matches found
```

**Estimated Impact:**
- **Performance:** Eliminates undefined behavior, may improve frame rate by 10-30% in some scenarios
- **Risk:** 🟢 **Very Low** - Removing contradictory flag cannot make things worse
- **Effort:** 10 minutes

**Status:** 🔄 **Ready to implement** (assigned to subtask-3-1)

---

### 1.2 Implement Brush Stamp Cache 🔴

**Issue:** Soft brush rendering uses `MaskFilter.blur` which is 5-20x slower than hard brushes, causing frame drops to 25-40fps during drawing.

**Root Cause:** Every stroke segment applies blur filter in real-time.

**Solution:** Pre-render brush stamps at different sizes/hardness levels and cache them.

**Implementation Plan:**

#### Step 1: Create BrushStampCache class

```dart
// lib/presentation/widgets/image_editor/core/brush_stamp_cache.dart
class BrushStampCache {
  static final Map<String, ui.Image> _stamps = {};
  static const int _maxCacheSize = 100;

  /// Get or create a brush stamp
  static Future<ui.Image> getStamp({
    required double size,
    required double hardness,
    required Color color,
  }) async {
    final key = _generateKey(size, hardness, color);

    if (_stamps.containsKey(key)) {
      return _stamps[key]!;
    }

    // Create new stamp
    final stamp = await _renderStamp(size, hardness, color);

    // Evict old entries if cache is full
    if (_stamps.length >= _maxCacheSize) {
      _stamps.remove(_stamps.keys.first);
    }

    _stamps[key] = stamp;
    return stamp;
  }

  static String _generateKey(double size, double hardness, Color color) {
    return '${size.toInt()}_${hardness.toStringAsFixed(2)}_${color.value}';
  }

  static Future<ui.Image> _renderStamp(
    double size,
    double hardness,
    Color color,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final center = Offset(size / 2, size / 2);
    final radius = size / 2;

    final paint = Paint()
      ..color = color
      ..maskFilter = hardness < 1.0
          ? MaskFilter.blur(BlurStyle.normal, size * (1.0 - hardness) * 0.25)
          : null;

    canvas.drawCircle(center, radius, paint);

    final picture = recorder.endRecording();
    return await picture.toImage(size.toInt(), size.toInt());
  }

  static void clear() {
    _stamps.clear();
  }
}
```

#### Step 2: Modify LayerPainter to use stamps

```dart
// In layer_painter.dart, _drawCurrentStroke method
void _drawCurrentStroke(Canvas canvas) {
  if (points.isEmpty) return;

  final paint = Paint()
    ..color = color.withOpacity(opacity)
    ..blendMode = blendMode;

  if (hardness >= 1.0) {
    // Hard brush: use existing path-based drawing
    final path = _createSmoothPath(points);
    canvas.drawPath(path, paint);
  } else {
    // Soft brush: use stamp cache for better performance
    for (final point in points) {
      final stamp = await BrushStampCache.getStamp(
        size: size,
        hardness: hardness,
        color: color,
      );

      final paintStamp = Paint()
        ..filterQuality = FilterQuality.high;

      canvas.drawImage(
        stamp,
        Offset(point.dx - size / 2, point.dy - size / 2),
        paintStamp,
      );
    }
  }
}
```

**Files to Create:**
- `lib/presentation/widgets/image_editor/core/brush_stamp_cache.dart`

**Files to Modify:**
- `lib/presentation/widgets/image_editor/canvas/layer_painter.dart` (_drawCurrentStroke method)

**Estimated Impact:**
- **Performance:** 5-10x faster soft brush drawing (25-40fps → 60fps)
- **Memory:** +10-50MB for stamp cache (acceptable)
- **Risk:** 🟡 **Medium** - Changes rendering logic, needs thorough testing

**Effort:** 4-8 hours

**Status:** 🔄 **Recommended for implementation** (future sprint)

---

### 1.3 Add Spatial Culling 🔴

**Issue:** All layers rendered fully regardless of viewport, causing 2-5x over-rendering when zoomed in.

**Solution:** Calculate viewport bounds and skip off-screen layers.

**Implementation Plan:**

#### Step 1: Add viewport tracking to CanvasController

```dart
// In canvas_controller.dart
class CanvasController extends ChangeNotifier {
  // ... existing code ...

  Rect get viewportBounds {
    // Calculate visible canvas area based on offset and scale
    final viewportSize = _getViewportSize(); // From MediaQuery or similar
    final topLeft = screenToCanvas(Offset.zero);
    final bottomRight = screenToCanvas(viewportSize);

    return Rect.fromPoints(topLeft, bottomRight);
  }

  // Keep existing transform logic
}
```

#### Step 2: Add bounds tracking to Layer

```dart
// In layer.dart
class Layer {
  Rect? _bounds;

  Rect get bounds {
    _bounds ??= _calculateBounds();
    return _bounds!;
  }

  Rect _calculateBounds() {
    if (baseImage != null) {
      return Rect.fromLTWH(0, 0, baseImage!.width.toDouble(), baseImage!.height.toDouble());
    }

    if (strokes.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final stroke in strokes) {
      for (final point in stroke.points) {
        minX = math.min(minX, point.dx);
        minY = math.min(minY, point.dy);
        maxX = math.max(maxX, point.dx);
        maxY = math.max(maxY, point.dy);
      }
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void invalidateBounds() {
    _bounds = null;
  }
}
```

#### Step 3: Check bounds before rendering

```dart
// In layer_painter.dart
void paint(Canvas canvas, Size size) {
  for (final layer in state.layers) {
    if (!layer.visible) continue;

    // NEW: Spatial culling
    final viewport = state.canvasController.viewportBounds;
    if (!layer.bounds.intersects(viewport)) {
      continue; // Skip off-screen layers
    }

    layer.renderWithCache(canvas, canvasSize);
  }
}
```

**Files to Modify:**
- `lib/presentation/widgets/image_editor/core/canvas_controller.dart` (add viewportBounds getter)
- `lib/presentation/widgets/image_editor/layers/layer.dart` (add bounds tracking)
- `lib/presentation/widgets/image_editor/canvas/layer_painter.dart` (add culling check)

**Estimated Impact:**
- **Performance:** 2-5x reduction in rendered pixels when zoomed in
- **Frame Rate:** +10-30fps in zoomed-in scenarios
- **Risk:** 🟢 **Low** - Pure optimization, no behavior change

**Effort:** 2-4 hours

**Status:** 🔄 **Recommended for implementation** (future sprint)

---

## Part 2: High-Priority Fixes (P1)

### 2.1 Fix Brush Button Contrast Issue 🟠

**Issue:** Selected brush preset buttons use `primaryContainer` background with `primary` text, causing poor contrast in dark themes (WCAG AA requires 4.5:1 contrast ratio).

**Current Code (`brush_tool.dart:381-434`):**
```dart
Widget _BrushPresetButton({
  required BuildContext context,
  required BrushPreset preset,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);

  return GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer  // ← Problem: low contrast
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
      ),
      child: Icon(
        preset.icon,
        color: isSelected
            ? theme.colorScheme.primary  // ← Problem: low contrast on primaryContainer
            : theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
```

**Solution Options:**

#### Option A: Border-Only Approach (Recommended) ⭐

```dart
Widget _BrushPresetButton({
  required BuildContext context,
  required BrushPreset preset,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);

  return GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Icon(
        preset.icon,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
```

**Pros:**
- Works in both light and dark themes
- No contrast issues (uses surface colors)
- Clear visual feedback (border)
- Minimal code change

**Cons:**
- Less dramatic visual change

#### Option B: Badge/Overlay Pattern

```dart
Widget _BrushPresetButton({
  required BuildContext context,
  required BrushPreset preset,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);

  return GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Icon(
            preset.icon,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          if (isSelected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
```

**Pros:**
- Shows selection without affecting icon readability
- Modern design pattern
- Works in all themes

**Cons:**
- More complex implementation
- Badge might be too subtle

#### Option C: Invert Colors (High Contrast)

```dart
Widget _BrushPresetButton({
  required BuildContext context,
  required BrushPreset preset,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);

  return GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary  // Use primary instead
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        preset.icon,
        color: isSelected
            ? theme.colorScheme.onPrimary  // High contrast
            : theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
```

**Pros:**
- High contrast (onPrimary always readable on primary)
- Clear visual difference
- Simple implementation

**Cons:**
- Inverts colors (might look odd)

**Recommended:** Option A (Border-Only)

**Files to Modify:**
- `lib/presentation/widgets/image_editor/tools/brush_tool.dart` (lines 381-434)

**Verification:**
1. Test in light theme - selected button clearly visible
2. Test in dark theme - selected button clearly visible
3. Check contrast ratio with accessibility tools

**Estimated Impact:**
- **Usability:** Fixes critical accessibility issue
- **Risk:** 🟢 **Low** - UI-only change

**Effort:** 1-2 hours

**Status:** 🔄 **Ready to implement** (assigned to subtask-2-1)

---

### 2.2 Optimize Canvas Transformations 🟠

**Issue:** 5-7 matrix transformations applied per frame, multiplied by 3 painters (layer, selection, cursor) = 1.5-3ms overhead per frame.

**Current Code (`layer_painter.dart:110-133`):**
```dart
@override
void paint(Canvas canvas, Size size) {
  canvas.save();
  canvas.translate(controller.offset.dx, controller.offset.dy);

  // Apply rotation/mirror at center
  canvas.translate(centerX, centerY);
  if (controller.rotation != 0) {
    canvas.rotate(controller.rotation);
  }
  if (controller.isMirroredHorizontally) {
    canvas.scale(-1.0, 1.0);
  }
  canvas.translate(-centerX, -centerY);
  canvas.scale(controller.scale);

  // ... render ...

  canvas.restore();
}
```

**Problem:** Transformations calculated every frame, even when nothing changed.

**Solution:** Cache transformation matrix, only recalculate when transform changes.

**Implementation:**

#### Step 1: Add transform versioning to CanvasController

```dart
// In canvas_controller.dart
class CanvasController extends ChangeNotifier {
  int _transformVersion = 0;
  Matrix4? _cachedTransform;

  int get transformVersion => _transformVersion;

  @override
  void notifyListeners() {
    _transformVersion++;
    _cachedTransform = null;
    super.notifyListeners();
  }

  Matrix4 getTransformMatrix(Size canvasSize) {
    if (_cachedTransform != null) {
      return _cachedTransform!;
    }

    // Build transformation matrix once
    final matrix = Matrix4.identity();

    // Translate to offset
    matrix.translate(offset.dx, offset.dy);

    // Apply rotation/mirror at center
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;
    matrix.translate(centerX, centerY);
    if (rotation != 0) {
      matrix.rotateZ(rotation);
    }
    if (isMirroredHorizontally) {
      matrix.scale(-1.0, 1.0);
    }
    matrix.translate(-centerX, -centerY);

    // Apply scale
    matrix.scale(scale, scale);

    _cachedTransform = matrix;
    return matrix;
  }
}
```

#### Step 2: Use cached transform in painters

```dart
// In layer_painter.dart
class LayerPainter extends CustomPainter {
  final EditorState state;
  int? _lastTransformVersion;

  LayerPainter({required this.state}) : super(repaint: state.renderNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final controller = state.canvasController;

    // Check if transform changed
    if (_lastTransformVersion != controller.transformVersion) {
      _lastTransformVersion = controller.transformVersion;
    }

    // Use cached transform
    final matrix = controller.getTransformMatrix(size);
    canvas.transform(matrix.storage);

    // ... render layers ...
  }
}
```

**Files to Modify:**
- `lib/presentation/widgets/image_editor/core/canvas_controller.dart` (add transform caching)
- `lib/presentation/widgets/image_editor/canvas/layer_painter.dart` (use cached transform)
- `lib/presentation/widgets/image_editor/canvas/selection_painter.dart` (use cached transform)
- `lib/presentation/widgets/image_editor/canvas/cursor_painter.dart` (use cached transform)

**Estimated Impact:**
- **Performance:** Saves 1-2ms per frame
- **Frame Rate:** +5-10fps in transform-heavy scenarios
- **Risk:** 🟢 **Low** - Internal optimization

**Effort:** 1-2 hours

**Status:** 🔄 **Recommended for implementation** (future sprint)

---

## Part 3: Medium-Priority Improvements (P2)

### 3.1 Add Dependency Injection to EditorState 🟡

**Issue:** `EditorState` directly instantiates all managers, causing tight coupling and making testing difficult.

**Current Code:**
```dart
class EditorState extends ChangeNotifier {
  final ToolManager toolManager = ToolManager();
  final LayerManager layerManager = LayerManager();
  final CanvasController canvasController = CanvasController();
  // ... 7 more managers
}
```

**Problems:**
- Cannot substitute managers with mocks for testing
- Hard to reuse EditorState with different configurations
- Violates Dependency Inversion Principle

**Solution:** Use constructor injection with interfaces.

**Implementation Plan:**

#### Step 1: Define interfaces for managers

```dart
// Create: lib/presentation/widgets/image_editor/core/interfaces/tool_manager_interface.dart
abstract class IToolManager {
  EditorTool? get currentTool;
  void setTool(EditorTool tool);
  void setToolById(String id);
  EditorTool? getToolById(String id);
  // ... other public methods ...
}

// Similar interfaces for:
// - ILayerManager
// - IHistoryManager
// - ICanvasController
// - etc.
```

#### Step 2: Modify EditorState to accept dependencies

```dart
class EditorState extends ChangeNotifier {
  final IToolManager toolManager;
  final ILayerManager layerManager;
  final ICanvasController canvasController;
  final IColorManager colorManager;
  final ISelectionManager selectionManager;
  final IStrokeManager strokeManager;
  final IHistoryManager historyManager;

  EditorState({
    required this.toolManager,
    required this.layerManager,
    required this.canvasController,
    required this.colorManager,
    required this.selectionManager,
    required this.strokeManager,
    required this.historyManager,
  }) {
    // Initialize notifiers
    toolChangeNotifier = ValueNotifier(toolManager.currentTool);
    canvasSizeNotifier = ValueNotifier(canvasController.canvasSize);

    // Set up listeners
    _setupManagerListeners();
  }

  // Factory constructor for default implementation
  factory EditorState.defaultImpl() {
    return EditorState(
      toolManager: ToolManager(),
      layerManager: LayerManager(),
      canvasController: CanvasController(),
      colorManager: ColorManager(),
      selectionManager: SelectionManager(),
      strokeManager: StrokeManager(),
      historyManager: HistoryManager(),
    );
  }
}
```

#### Step 3: Update all call sites

```dart
// Before:
final state = EditorState();

// After (default):
final state = EditorState.defaultImpl();

// After (testing):
final state = EditorState(
  toolManager: MockToolManager(),
  layerManager: MockLayerManager(),
  // ... mocks for testing
);
```

**Estimated Impact:**
- **Testability:** Enables unit testing with mocks
- **Flexibility:** Allows different manager implementations
- **Risk:** 🟡 **Medium** - Requires updating all instantiation points

**Effort:** 8-16 hours

**Status:** 🔄 **Recommended for future refactoring**

---

### 3.2 Cache Path Objects for Strokes 🟡

**Issue:** Path objects created for every stroke render, causing GC pressure.

**Solution:** Cache path in `StrokeData` after creation.

**Implementation:**

```dart
// In stroke_data.dart (or wherever stroke data is defined)
class StrokeData {
  final List<Offset> points;
  final double size;
  final Color color;
  // ... other properties ...

  Path? _cachedPath;

  Path get path {
    _cachedPath ??= _createSmoothPath(points);
    return _cachedPath!;
  }

  void invalidatePath() {
    _cachedPath = null;
  }

  static Path _createSmoothPath(List<Offset> points) {
    // Existing smoothing algorithm
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final control = current;
      final end = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(
        control.dx,
        control.dy,
        end.dx,
        end.dy,
      );
    }

    // Connect to last point
    if (points.length > 1) {
      path.lineTo(points.last.dx, points.last.dy);
    }

    return path;
  }
}
```

**Estimated Impact:**
- **Performance:** 10-20% reduction in stroke rendering cost
- **Memory:** +5-20MB for path cache (acceptable)
- **Risk:** 🟢 **Low** - Internal optimization

**Effort:** 2-4 hours

**Status:** 🔄 **Recommended for future optimization**

---

### 3.3 Optimize CursorPainter Repaint Behavior 🟡

**Issue:** CursorPainter recreated on every mouse move.

**Solution:** Use `repaint` parameter with cursor position notifier.

**Implementation:**

```dart
// In editor_canvas.dart
ValueListenableBuilder<Offset?>(
  valueListenable: _inputHandler.cursorPositionNotifier,
  builder: (context, cursorPosition, _) {
    if (cursorPosition == null || isColorPicker) return SizedBox.shrink();

    return Positioned.fill(
      child: CustomPaint(
        painter: CursorPainter(
          state: widget.state,
          cursorPosition: cursorPosition,
        ),
        // No willChange: true needed
      ),
    );
  },
)
```

**Estimated Impact:**
- **Performance:** Minor reduction in widget rebuilds
- **Risk:** 🟢 **Low** - Simple refactor

**Effort:** 1 hour

**Status:** 🔄 **Ready to implement** (assigned to subtask-3-2)

---

## Part 4: Long-Term Architectural Improvements (P3)

### 4.1 Split EditorState into Smaller Coordinators 🟢

**Issue:** EditorState has 480 lines, 80+ methods, and too many responsibilities (factory, facade, orchestrator).

**Current Architecture:**
```
EditorState (does everything)
├── Creates all managers (factory)
├── Exposes 80+ proxy methods (facade)
├── Routes notifications (observer)
└── Orchestrates high-level operations (coordinator)
```

**Proposed Architecture:**
```
EditorState (minimal core)
├── DrawingCoordinator (stroke → layer workflow)
├── ViewportCoordinator (canvas transforms)
├── HistoryCoordinator (undo/redo orchestration)
└── ToolCoordinator (tool lifecycle)

Each coordinator uses injected managers
```

**Implementation Plan:**

#### Step 1: Create DrawingCoordinator

```dart
class DrawingCoordinator {
  final IStrokeManager strokeManager;
  final ILayerManager layerManager;
  final IToolManager toolManager;

  DrawingCoordinator({
    required this.strokeManager,
    required this.layerManager,
    required this.toolManager,
  });

  void startStroke(Offset point) {
    strokeManager.startStroke(point);
  }

  void updateStroke(Offset point) {
    strokeManager.updateStroke(point);
  }

  void endStroke() {
    final stroke = strokeManager.endStroke();
    if (stroke != null) {
      final activeLayer = layerManager.activeLayer;
      activeLayer?.addStroke(stroke);
    }
  }
}
```

#### Step 2: Create ViewportCoordinator

```dart
class ViewportCoordinator {
  final ICanvasController canvasController;
  final ValueNotifier<Size> canvasSizeNotifier;

  ViewportCoordinator({
    required this.canvasController,
    required this.canvasSizeNotifier,
  });

  // Expose viewport operations
  void pan(Offset delta) => canvasController.offset += delta;
  void zoom(double factor, Offset center) => canvasController.zoom(factor, center);
  // ... other viewport operations
}
```

#### Step 3: Create HistoryCoordinator

```dart
class HistoryCoordinator {
  final IHistoryManager historyManager;
  final IEditorState editorState;

  HistoryCoordinator({
    required this.historyManager,
    required this.editorState,
  });

  void undo() => historyManager.undo();
  void redo() => historyManager.redo();

  void executeAction(EditorAction action) {
    historyManager.executeAction(action);
  }
}
```

#### Step 4: Refactor EditorState

```dart
class EditorState extends ChangeNotifier {
  // Coordinators (instead of raw managers)
  late final DrawingCoordinator drawing;
  late final ViewportCoordinator viewport;
  late final HistoryCoordinator history;
  late final ToolCoordinator tools;

  // Managers (internal, accessed via coordinators)
  final IToolManager _toolManager;
  final ILayerManager _layerManager;
  // ...

  EditorState({
    required IToolManager toolManager,
    required ILayerManager layerManager,
    // ...
  }) {
    // Initialize coordinators
    drawing = DrawingCoordinator(
      strokeManager: strokeManager,
      layerManager: layerManager,
      toolManager: toolManager,
    );
    // ... other coordinators
  }

  // Minimal proxy methods (most delegated to coordinators)
  void startStroke(Offset point) => drawing.startStroke(point);
  void undo() => history.undo();
  void pan(Offset delta) => viewport.pan(delta);
}
```

**Benefits:**
- **Single Responsibility:** Each coordinator has one job
- **Testability:** Can test coordinators independently
- **Maintainability:** Easier to understand and modify
- **Flexibility:** Can swap coordinator implementations

**Estimated Impact:**
- **Maintainability:** Significantly improved
- **Testability:** Much easier to test
- **Risk:** 🔴 **High** - Major refactor, high regression risk

**Effort:** 16-32 hours

**Status:** 🔄 **Long-term architectural improvement**

---

### 4.2 Split Layer Class (Renderer vs Cache) 🟢

**Issue:** Layer class has 806 lines mixing data storage, rendering logic, and caching strategy.

**Proposed Split:**

```
Layer (data holder)
├── strokes: List<StrokeData>
├── baseImage: ui.Image?
├── visible, locked, opacity, blendMode
└── Serialization methods

LayerRenderer (rendering logic)
├── renderWithCache()
├── _drawStrokes()
└── _applyComposition()

LayerCache (caching strategy)
├── rasterizedImage: ui.Image?
├── compositedCache: ui.Image?
├── thumbnail: ui.Image?
├── rasterize()
└── updateCompositeCache()
```

**Estimated Impact:**
- **Maintainability:** Improved separation of concerns
- **Testability:** Can test cache strategy independently
- **Risk:** 🟡 **Medium** - Affects core rendering

**Effort:** 8-16 hours

**Status:** 🔄 **Long-term refactoring**

---

### 4.3 Extract Action Classes from HistoryManager 🟢

**Issue:** HistoryManager contains 7 action classes (404 lines total), mixing responsibilities.

**Proposed Structure:**

```
core/
├── history_manager.dart (100 lines - just stack management)
└── actions/
    ├── add_stroke_action.dart
    ├── clear_layer_action.dart
    ├── merge_layers_action.dart
    ├── delete_layer_action.dart
    ├── move_layer_action.dart
    ├── change_opacity_action.dart
    └── canvas_resize_action.dart
```

**Estimated Impact:**
- **Organization:** Clearer file structure
- **Discoverability:** Easier to find actions
- **Risk:** 🟢 **Low** - File moves only

**Effort:** 2-4 hours

**Status:** 🔄 **Easy win, low priority**

---

### 4.4 Add Comprehensive Unit Tests 🟢

**Current State:** Minimal test coverage for core managers.

**Target:** 80% coverage for managers and coordinators.

**Test Plan:**

#### Priority 1: Independent Managers (Easy)
- ✅ ColorManager tests
- ✅ SelectionManager tests
- ✅ StrokeManager tests
- ✅ CanvasController tests

#### Priority 2: Managers with Dependencies (Medium)
- ToolManager tests (with ToolSettingsManager mock)
- LayerManager tests (with Layer mocks)
- HistoryManager tests (with EditorState mock)

#### Priority 3: Coordinators (After refactor)
- DrawingCoordinator tests
- ViewportCoordinator tests
- HistoryCoordinator tests

**Estimated Effort:** 40-80 hours

**Status:** 🔄 **Ongoing quality improvement**

---

## Part 5: Implementation Roadmap

### Phase 1: Critical Fixes (Week 1) 🔴

**Goal:** Fix critical bugs and highest-impact performance issues.

| Task | Effort | Owner | Status |
|------|--------|-------|--------|
| 1. Fix contradictory CustomPainter flags | 10 min | Dev | 📋 Planned |
| 2. Fix brush button contrast | 1-2 hrs | Dev | 📋 Planned |
| 3. Implement brush stamp cache | 4-8 hrs | Dev | 📋 Planned |
| 4. Add spatial culling | 2-4 hrs | Dev | 📋 Planned |
| 5. Optimize canvas transformations | 1-2 hrs | Dev | 📋 Planned |
| 6. Optimize CursorPainter | 1 hr | Dev | 📋 Planned |

**Total Effort:** 9-17 hours (~2-3 days)

**Success Metrics:**
- ✅ CustomPainter flags fixed
- ✅ Brush buttons visible in light/dark themes
- ✅ Soft brush performance: 60fps (up from 25-40fps)
- ✅ Zoomed-in performance: 2-5x improvement

---

### Phase 2: Code Quality Improvements (Week 2-3) 🟠

**Goal:** Improve testability and maintainability.

| Task | Effort | Owner | Status |
|------|--------|-------|--------|
| 7. Cache path objects for strokes | 2-4 hrs | Dev | 📋 Planned |
| 8. Add dependency injection | 8-16 hrs | Dev | 📋 Planned |
| 9. Extract action classes | 2-4 hrs | Dev | 📋 Planned |
| 10. Add unit tests for independent managers | 8-16 hrs | Dev | 📋 Planned |

**Total Effort:** 20-40 hours (~1 week)

**Success Metrics:**
- ✅ DI implemented for EditorState
- ✅ Action classes extracted
- ✅ 80% test coverage for independent managers
- ✅ All tests passing

---

### Phase 3: Architectural Refactoring (Month 2) 🟢

**Goal:** Long-term architectural improvements.

| Task | Effort | Owner | Status |
|------|--------|-------|--------|
| 11. Split EditorState into coordinators | 16-32 hrs | Dev | 📋 Planned |
| 12. Split Layer class | 8-16 hrs | Dev | 📋 Planned |
| 13. Add comprehensive integration tests | 16-24 hrs | Dev | 📋 Planned |
| 14. Add UI/golden tests | 8-16 hrs | Dev | 📋 Planned |

**Total Effort:** 48-88 hours (~2 weeks)

**Success Metrics:**
- ✅ EditorState split into 4 coordinators
- ✅ Layer class split (data, renderer, cache)
- ✅ Integration tests covering core workflows
- ✅ Golden tests for painters

---

## Part 6: Risk Assessment

### High-Risk Changes 🔴

| Change | Risk | Mitigation |
|--------|------|------------|
| **Brush stamp cache** | 🟡 Medium - Rendering behavior change | - Thorough testing in staging
- Side-by-side comparison with old rendering
- Performance benchmarks
- A/B testing with users |
| **Split EditorState** | 🔴 High - Core refactor | - Incremental rollout (one coordinator at a time)
- Comprehensive integration tests
- Feature flags to revert quickly
- Code review by senior architect |
| **Split Layer class** | 🟡 Medium - Core rendering | - Unit tests for each new class
- Integration tests for rendering pipeline
- Performance regression tests |

### Low-Risk Changes 🟢

| Change | Risk | Reason |
|--------|------|--------|
| **Fix CustomPainter flags** | 🟢 Very Low | Removing contradictory flag cannot make things worse |
| **Brush button contrast** | 🟢 Low | UI-only change, no behavior change |
| **Spatial culling** | 🟢 Low | Pure optimization, no behavior change |
| **Transform caching** | 🟢 Low | Internal optimization, transparent to users |
| **Path caching** | 🟢 Low | Internal optimization |
| **Extract action classes** | 🟢 Low | File moves only, no logic change |

---

## Part 7: Performance Benchmarks

### Before Optimizations (Baseline)

| Scenario | Frame Time | FPS | Status |
|----------|------------|-----|--------|
| Idle (no drawing) | 2-3ms | 60 | ✅ Good |
| Hard brush drawing | 8-12ms | 60 | ✅ Good |
| **Soft brush (50% hardness)** | **25-40ms** | **25-40** | 🔴 Poor |
| **Very soft brush (20%)** | **50-80ms** | **12-20** | 🔴 Poor |
| Pan/zoom (no rotation) | 5-8ms | 60 | ✅ Good |
| 5 layers @ 50% opacity | 15-20ms | 50-60 | 🟡 OK |
| Large canvas, zoomed in | 20-30ms | 33-50 | 🟡 OK |

### After Phase 1 Optimizations (Target)

| Scenario | Frame Time | FPS | Improvement | Status |
|----------|------------|-----|-------------|--------|
| Idle (no drawing) | 2-3ms | 60 | - | ✅ Good |
| Hard brush drawing | 8-12ms | 60 | - | ✅ Good |
| **Soft brush (50% hardness)** | **5-10ms** | **60** | **5-10x faster** | ✅ Fixed |
| **Very soft brush (20%)** | **8-15ms** | **60** | **5-10x faster** | ✅ Fixed |
| Pan/zoom (no rotation) | 3-5ms | 60 | 1.5-2x faster | ✅ Improved |
| 5 layers @ 50% opacity | 12-15ms | 60 | 1.2-1.5x faster | ✅ Improved |
| Large canvas, zoomed in | 5-10ms | 60 | 2-5x faster | ✅ Fixed |

**Target:** All scenarios at 60fps (≤16ms per frame)

---

## Part 8: Success Criteria

### Phase 1 Success (Critical Fixes)

- [ ] CustomPainter contradictory flags removed
- [ ] Brush preset buttons clearly visible in light and dark themes
- [ ] Soft brush rendering at 60fps (up from 25-40fps)
- [ ] Zoomed-in canvas rendering improved by 2-5x
- [ ] No regressions in existing functionality
- [ ] All existing tests passing

### Phase 2 Success (Code Quality)

- [ ] Dependency injection implemented for EditorState
- [ ] Unit test coverage >80% for independent managers
- [ ] Action classes extracted from HistoryManager
- [ ] Path caching implemented
- [ ] All new tests passing

### Phase 3 Success (Architecture)

- [ ] EditorState split into 4 coordinators
- [ ] Layer class split into 3 classes
- [ ] Integration tests covering core workflows
- [ ] Golden tests for painters
- [ ] Documentation updated

---

## Part 9: Testing Strategy

### Performance Testing

**Automated Benchmarks:**
```dart
// test/performance/canvas_performance_test.dart
void main() {
  testWidgets('Soft brush rendering maintains 60fps', (tester) async {
    // Setup canvas with soft brush
    // Draw 100 strokes
    // Measure frame times
    // Assert: all frames ≤ 16ms
  });

  testWidgets('Zoomed-in canvas renders efficiently', (tester) async {
    // Setup large canvas (4096x4096)
    // Zoom to 200%
    // Measure render time
    // Assert: ≤ 10ms per frame
  });
}
```

**Manual Testing:**
1. Enable Flutter DevTools Performance overlay
2. Test scenarios from benchmark table
3. Record frame times
4. Compare against baseline

### Regression Testing

**Existing Tests:**
- Run full test suite before each phase
- Run full test suite after each phase
- Compare pass rates

**Visual Regression:**
- Golden tests for painters
- Screenshot tests for canvas rendering
- Comparison tool to detect pixel differences

---

## Part 10: Rollback Strategy

### If Performance Regressions Occur

1. **Identify the culprit:** Use git bisect to find problematic commit
2. **Quick rollback:** Revert specific commit
3. **Alternative approach:** Try different optimization strategy

### If Bugs Are Introduced

1. **Fix-forward:** Prefer fixing bugs over rolling back
2. **Hotfix:** Create patch release
3. **Feature flags:** Use flags to disable problematic features

### If Refactoring Causes Issues

1. **Incremental revert:** Revert one coordinator at a time
2. **Fallback to old code:** Keep old code in separate branch
3. **A/B testing:** Test new version with subset of users

---

## Conclusion

The canvas system has a **strong architectural foundation** (4/5 stars) with excellent Manager pattern and performance optimizations. The main issues are:

1. **Critical Performance Bug:** Contradictory CustomPainter flags (quick win)
2. **Soft Brush Performance:** MaskFilter.blur bottleneck (high impact)
3. **No Spatial Culling:** Over-rendering in zoomed views (medium impact)
4. **UI Bug:** Brush button contrast issue (accessibility)
5. **Architectural Debt:** Tight coupling in EditorState (long-term)

**Recommended Approach:**

**Immediate (Phase 1):** Fix critical bugs and implement top 3 performance optimizations (9-17 hours). This will resolve the user-reported lag issues and improve experience dramatically.

**Short-term (Phase 2):** Improve code quality with DI and unit tests (20-40 hours). Sets foundation for future development.

**Long-term (Phase 3):** Architectural refactoring to split large classes (48-88 hours). Improves maintainability for years to come.

**Total Estimated Effort:** 77-145 hours (~2-4 weeks for one developer, or 1-2 weeks with two developers working in parallel)

**Expected Outcomes:**
- ✅ 60fps performance in all scenarios (up from 12-40fps for soft brushes)
- ✅ Accessible UI with proper contrast
- ✅ Testable architecture with 80%+ coverage
- ✅ Maintainable codebase for future development

---

**Document Version:** 1.0
**Last Updated:** 2026-01-25
**Author:** Auto-generated via subtask-1-3
**Status:** ✅ Complete
**Next Steps:** Proceed to Phase 2 (UI fixes) and Phase 3 (performance fixes) in parallel
