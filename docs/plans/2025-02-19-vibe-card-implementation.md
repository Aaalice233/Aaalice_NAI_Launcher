# Vibe 卡片重构实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 重写 VibeCard 组件，统一 Bundle 和非 Bundle 卡片，实现斜向百叶窗展开动画效果

**Architecture:** 使用 StatefulWidget 管理动画状态，通过 Stack + Transform + ClipPath 实现斜向百叶窗分割效果。Bundle 卡片悬停时百叶窗叶片斜向展开，露出背后的子 vibe 预览。

**Tech Stack:** Flutter, Dart, CustomPainter, AnimationController

---

## 前置检查

### Task 0: 检查现有文件和引用

**目的:** 了解当前 vibe_card_3d.dart 被哪些文件引用

**命令:**
```bash
grep -r "VibeCard3D\|vibe_card_3d" lib/ --include="*.dart" -l
```

**预期输出:**
- lib/presentation/screens/vibe_library/vibe_library_screen.dart
- lib/presentation/screens/vibe_library/widgets/vibe_selector_dialog.dart
- lib/presentation/screens/generation/widgets/unified_reference_panel.dart

---

## 第一阶段：创建新的统一 VibeCard 组件

### Task 1: 创建新的 vibe_card.dart 文件

**Files:**
- Create: `lib/presentation/screens/vibe_library/widgets/vibe_card.dart`

**步骤:**

**Step 1: 创建基础组件结构**

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../themes/theme_extension.dart';
import '../../../widgets/common/animated_favorite_button.dart';

/// 统一 Vibe 卡片组件
///
/// 支持 Bundle 和非 Bundle 类型：
/// - 非 Bundle: 简洁悬停效果（放大、阴影、发光边框）
/// - Bundle: 斜向百叶窗展开效果，展示子 vibe 预览
class VibeCard extends StatefulWidget {
  final VibeLibraryEntry entry;
  final double width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(TapDownDetails)? onSecondaryTapDown;
  final bool isSelected;
  final bool showFavoriteIndicator;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onSendToGeneration;
  final VoidCallback? onExport;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const VibeCard({
    super.key,
    required this.entry,
    required this.width,
    this.height,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.isSelected = false,
    this.showFavoriteIndicator = true,
    this.onFavoriteToggle,
    this.onSendToGeneration,
    this.onExport,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<VibeCard> createState() => _VibeCardState();
}

class _VibeCardState extends State<VibeCard>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isHovered = false;
  late AnimationController _blindsController;
  late Animation<double> _blindsAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _blindsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _blindsAnimation = CurvedAnimation(
      parent: _blindsController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _blindsController.dispose();
    super.dispose();
  }

  void _onHoverEnter(PointerEvent event) {
    setState(() => _isHovered = true);
    if (widget.entry.isBundle) {
      _blindsController.forward();
    }
  }

  void _onHoverExit(PointerEvent event) {
    setState(() => _isHovered = false);
    if (widget.entry.isBundle) {
      _blindsController.reverse();
    }
  }

  Uint8List? get _thumbnailData {
    if (widget.entry.thumbnail != null && widget.entry.thumbnail!.isNotEmpty) {
      return widget.entry.thumbnail;
    }
    if (widget.entry.vibeThumbnail != null &&
        widget.entry.vibeThumbnail!.isNotEmpty) {
      return widget.entry.vibeThumbnail;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final cardHeight = widget.height ?? widget.width;
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: _onHoverEnter,
      onExit: _onHoverExit,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
          transformAlignment: Alignment.center,
          child: Container(
            width: widget.width,
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: widget.isSelected
                  ? Border.all(color: colorScheme.primary, width: 3)
                  : _isHovered
                      ? Border.all(
                          color: colorScheme.primary.withOpacity(0.3),
                          width: 2,
                        )
                      : null,
              boxShadow: _buildShadows(),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 主内容层
                  _buildMainContent(),

                  // Bundle 百叶窗效果层
                  if (widget.entry.isBundle)
                    _buildDiagonalBlindsEffect(),

                  // 信息层
                  _buildInfoOverlay(),

                  // 收藏按钮
                  if (widget.showFavoriteIndicator)
                    _buildFavoriteButton(),

                  // 选中状态
                  if (widget.isSelected)
                    _buildSelectionOverlay(colorScheme),

                  // 操作按钮
                  if (_isHovered && !widget.isSelected)
                    _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _buildShadows() {
    if (_isHovered) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 28,
          offset: const Offset(0, 14),
          spreadRadius: 2,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 40,
          offset: const Offset(0, 20),
          spreadRadius: -4,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.12),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  Widget _buildMainContent() {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (widget.width * pixelRatio).toInt();

    return Container(
      color: Colors.black.withOpacity(0.05),
      child: _thumbnailData != null
          ? Image.memory(
              _thumbnailData!,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  ),
                );
              },
            )
          : Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  widget.entry.isBundle ? Icons.style : Icons.auto_fix_high,
                  size: 32,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
    );
  }

  Widget _buildDiagonalBlindsEffect() {
    final previews = widget.entry.bundledVibePreviews?.take(5).toList() ?? [];
    if (previews.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _blindsAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _DiagonalBlindsPainter(
            progress: _blindsAnimation.value,
            previews: previews,
            themeColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }

  Widget _buildInfoOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.entry.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            _buildProgressBar(
              label: context.l10n.vibe_strength,
              value: widget.entry.strength,
              color: Colors.blue,
            ),
            const SizedBox(height: 4),
            _buildProgressBar(
              label: context.l10n.vibe_infoExtracted,
              value: widget.entry.infoExtracted,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required double value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton() {
    final isFavorite = widget.entry.isFavorite;
    final showButton = _isHovered || isFavorite;

    if (!showButton) return const SizedBox.shrink();

    return Positioned(
      top: 8,
      right: 8,
      child: CardFavoriteButton(
        isFavorite: isFavorite,
        onToggle: widget.onFavoriteToggle,
        size: 18,
      ),
    );
  }

  Widget _buildSelectionOverlay(ColorScheme colorScheme) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.check,
                color: colorScheme.onPrimary,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      top: 8,
      right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onSendToGeneration != null)
            _ActionButton(
              icon: Icons.send,
              tooltip: context.l10n.vibe_reuseButton,
              onTap: widget.onSendToGeneration,
            ),
          if (widget.onExport != null)
            _ActionButton(
              icon: Icons.download,
              tooltip: context.l10n.common_export,
              onTap: widget.onExport,
            ),
          if (widget.onEdit != null)
            _ActionButton(
              icon: Icons.edit,
              tooltip: context.l10n.common_edit,
              onTap: widget.onEdit,
            ),
          if (widget.onDelete != null)
            _ActionButton(
              icon: Icons.delete,
              tooltip: context.l10n.common_delete,
              onTap: widget.onDelete,
              isDanger: true,
            ),
        ],
      ),
    );
  }
}

/// 斜向百叶窗绘制器
class _DiagonalBlindsPainter extends CustomPainter {
  final double progress;
  final List<Uint8List> previews;
  final Color themeColor;

  _DiagonalBlindsPainter({
    required this.progress,
    required this.previews,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final count = previews.length.clamp(2, 5);
    final stripHeight = size.height / count;
    final diagonalOffset = size.width * 0.3;

    for (int i = 0; i < count; i++) {
      final y = i * stripHeight;
      final slideOffset = diagonalOffset * progress;

      // 绘制子 vibe 预览（在叶片下方）
      _drawStripContent(canvas, size, i, y, stripHeight, slideOffset);

      // 绘制百叶窗叶片（半透明的遮盖层）
      _drawBlindStrip(canvas, size, y, stripHeight, slideOffset, i);
    }
  }

  void _drawStripContent(
    Canvas canvas,
    Size size,
    int index,
    double y,
    double height,
    double slideOffset,
  ) {
    // 创建斜向裁剪路径
    final path = Path()
      ..moveTo(slideOffset, y)
      ..lineTo(size.width + slideOffset, y)
      ..lineTo(size.width - diagonalOffset + slideOffset, y + height)
      ..lineTo(-diagonalOffset + slideOffset, y + height)
      ..close();

    // 这里应该绘制对应的子 vibe 预览
    // 简化版本：使用主题色渐变块代替
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          themeColor.withOpacity(0.3 + index * 0.1),
          themeColor.withOpacity(0.5 + index * 0.1),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, y, size.width, height));

    canvas.drawPath(path, paint);
  }

  void _drawBlindStrip(
    Canvas canvas,
    Size size,
    double y,
    double height,
    double slideOffset,
    int index,
  ) {
    final path = Path()
      ..moveTo(slideOffset, y)
      ..lineTo(size.width + slideOffset, y)
      ..lineTo(size.width - diagonalOffset + slideOffset, y + height)
      ..lineTo(-diagonalOffset + slideOffset, y + height)
      ..close();

    // 叶片半透明覆盖层
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3 * (1 - progress))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // 叶片边缘发光
    if (progress > 0.1) {
      final borderPaint = Paint()
        ..color = themeColor.withOpacity(0.5 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawPath(path, borderPaint);
    }
  }

  double get diagonalOffset => 50.0;

  @override
  bool shouldRepaint(covariant _DiagonalBlindsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.previews != previews ||
        oldDelegate.themeColor != themeColor;
  }
}

/// 操作按钮组件
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isDanger;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.isDanger = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = widget.isDanger
        ? (_isHovered ? colorScheme.error : colorScheme.error.withOpacity(0.9))
        : (_isHovered ? Colors.white : Colors.white.withOpacity(0.9));
    final iconColor = widget.isDanger
        ? colorScheme.onError
        : (_isHovered ? Colors.black : Colors.black.withOpacity(0.65));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.28 : 0.2),
                blurRadius: _isHovered ? 8 : 4,
                offset: Offset(0, _isHovered ? 3 : 2),
              ),
            ],
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            scale: _isHovered ? 1.08 : 1.0,
            child: Icon(widget.icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}
```

**Step 2: 验证文件创建**

运行:
```bash
ls -la lib/presentation/screens/vibe_library/widgets/vibe_card.dart
```

预期: 文件存在

**Step 3: Commit**

```bash
git add lib/presentation/screens/vibe_library/widgets/vibe_card.dart
git commit -m "feat(vibe-card): 创建新的统一 VibeCard 组件框架"
```

---

## 第二阶段：更新引用文件

### Task 2: 更新 vibe_library_screen.dart

**Files:**
- Modify: `lib/presentation/screens/vibe_library/vibe_library_screen.dart`

**步骤:**

**Step 1: 修改导入语句**

将:
```dart
import 'widgets/vibe_card_3d.dart';
```

改为:
```dart
import 'widgets/vibe_card.dart';
```

**Step 2: 替换组件使用**

将所有 `VibeCard3D` 替换为 `VibeCard`。

搜索文件中的 `VibeCard3D`，通常在使用的地方会有：
```dart
VibeCard3D(
  entry: entry,
  width: cardWidth,
  // ...
)
```

改为:
```dart
VibeCard(
  entry: entry,
  width: cardWidth,
  // ...
)
```

**Step 3: 运行分析检查**

```bash
/mnt/e/flutter/bin/flutter.bat analyze lib/presentation/screens/vibe_library/vibe_library_screen.dart
```

预期: 无错误

**Step 4: Commit**

```bash
git add lib/presentation/screens/vibe_library/vibe_library_screen.dart
git commit -m "refactor(vibe-card): 更新 vibe_library_screen 使用新的 VibeCard 组件"
```

---

### Task 3: 更新 vibe_selector_dialog.dart

**Files:**
- Modify: `lib/presentation/screens/vibe_library/widgets/vibe_selector_dialog.dart`

**步骤:**

**Step 1: 修改导入语句**

将:
```dart
import 'vibe_card_3d.dart';
```

改为:
```dart
import 'vibe_card.dart';
```

**Step 2: 替换组件使用**

将所有 `VibeCard3D` 替换为 `VibeCard`。

**Step 3: 运行分析检查**

```bash
/mnt/e/flutter/bin/flutter.bat analyze lib/presentation/screens/vibe_library/widgets/vibe_selector_dialog.dart
```

**Step 4: Commit**

```bash
git add lib/presentation/screens/vibe_library/widgets/vibe_selector_dialog.dart
git commit -m "refactor(vibe-card): 更新 vibe_selector_dialog 使用新的 VibeCard 组件"
```

---

### Task 4: 更新 unified_reference_panel.dart

**Files:**
- Modify: `lib/presentation/screens/generation/widgets/unified_reference_panel.dart`

**步骤:**

**Step 1: 修改导入语句**

将:
```dart
import '../vibe_library/widgets/vibe_card_3d.dart';
```

改为:
```dart
import '../vibe_library/widgets/vibe_card.dart';
```

**Step 2: 替换组件使用**

将所有 `VibeCard3D` 替换为 `VibeCard`。

**Step 3: 运行分析检查**

```bash
/mnt/e/flutter/bin/flutter.bat analyze lib/presentation/screens/generation/widgets/unified_reference_panel.dart
```

**Step 4: Commit**

```bash
git add lib/presentation/screens/generation/widgets/unified_reference_panel.dart
git commit -m "refactor(vibe-card): 更新 unified_reference_panel 使用新的 VibeCard 组件"
```

---

## 第三阶段：删除旧文件

### Task 5: 删除旧的 vibe_card_3d.dart

**Files:**
- Delete: `lib/presentation/screens/vibe_library/widgets/vibe_card_3d.dart`

**步骤:**

**Step 1: 删除文件**

```bash
rm lib/presentation/screens/vibe_library/widgets/vibe_card_3d.dart
```

**Step 2: 验证无残留引用**

```bash
grep -r "VibeCard3D\|vibe_card_3d" lib/ --include="*.dart"
```

预期: 无输出（或只有导入已更新文件的旧历史）

**Step 3: 运行项目分析**

```bash
/mnt/e/flutter/bin/flutter.bat analyze
```

预期: 无错误

**Step 4: Commit**

```bash
git add lib/presentation/screens/vibe_library/widgets/vibe_card_3d.dart
git commit -m "chore(vibe-card): 删除旧的 VibeCard3D 组件"
```

---

## 第四阶段：完善百叶窗效果

### Task 6: 优化百叶窗绘制器显示子 vibe 缩略图

**Files:**
- Modify: `lib/presentation/screens/vibe_library/widgets/vibe_card.dart`
（_DiagonalBlindsPainter 类）

**步骤:**

当前实现使用渐变块代替实际缩略图。需要修改为显示真实的子 vibe 缩略图。

**Step 1: 修改绘制器以支持实际图像**

由于 CustomPainter 中直接使用 Image.memory 比较复杂，考虑改用 Stack + Positioned 方式实现百叶窗效果。

重写 `_buildDiagonalBlindsEffect` 方法：

```dart
Widget _buildDiagonalBlindsEffect() {
  final previews = widget.entry.bundledVibePreviews?.take(5).toList() ?? [];
  final names = widget.entry.bundledVibeNames?.take(5).toList() ?? [];
  if (previews.isEmpty) return const SizedBox.shrink();

  final count = previews.length.clamp(2, 5);

  return AnimatedBuilder(
    animation: _blindsAnimation,
    builder: (context, child) {
      final progress = _blindsAnimation.value;

      return Stack(
        fit: StackFit.expand,
        children: [
          // 子 vibe 预览层
          ...List.generate(count, (index) {
            return _buildStripContent(index, count, previews[index], progress);
          }),

          // 百叶窗叶片层
          CustomPaint(
            size: Size.infinite,
            painter: _BlindsOverlayPainter(
              progress: progress,
              count: count,
              themeColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildStripContent(int index, int total, Uint8List preview, double progress) {
  final stripHeight = (widget.height ?? widget.width) / total;
  final y = index * stripHeight;
  final diagonalOffset = widget.width * 0.3 * progress;

  return Positioned(
    left: -diagonalOffset,
    top: y,
    right: diagonalOffset,
    height: stripHeight,
    child: ClipPath(
      clipper: _DiagonalStripClipper(index: index, total: total),
      child: Image.memory(
        preview,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    ),
  );
}
```

添加对角线条形裁剪器：

```dart
class _DiagonalStripClipper extends CustomClipper<Path> {
  final int index;
  final int total;

  _DiagonalStripClipper({required this.index, required this.total});

  @override
  Path getClip(Size size) {
    final diagonalOffset = size.width * 0.3;
    final y = 0.0;

    return Path()
      ..moveTo(0, y)
      ..lineTo(size.width, y)
      ..lineTo(size.width - diagonalOffset, size.height)
      ..lineTo(-diagonalOffset, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) => false;
}
```

**Step 2: 运行分析检查**

```bash
/mnt/e/flutter/bin/flutter.bat analyze lib/presentation/screens/vibe_library/widgets/vibe_card.dart
```

**Step 3: Commit**

```bash
git add lib/presentation/screens/vibe_library/widgets/vibe_card.dart
git commit -m "feat(vibe-card): 优化百叶窗效果显示子 vibe 缩略图"
```

---

## 第五阶段：代码生成和最终检查

### Task 7: 运行代码生成（如果需要）

检查是否有代码生成依赖：

```bash
/mnt/e/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs
```

---

### Task 8: 最终分析检查

```bash
/mnt/e/flutter/bin/flutter.bat analyze
```

预期: 无错误

---

### Task 9: 最终 Commit

```bash
git status
git add -A
git commit -m "feat(vibe-card): 完成 VibeCard 重构，添加斜向百叶窗展开效果

- 统一 Bundle 和非 Bundle 卡片使用同一组件
- 实现斜向百叶窗展开动画效果
- Bundle 卡片悬停时展示子 vibe 预览
- 非 Bundle 卡片保持简洁悬停效果
- 删除旧的 VibeCard3D 组件"
```

---

## 验收清单

- [ ] 新 VibeCard 组件创建完成
- [ ] vibe_library_screen.dart 更新完成
- [ ] vibe_selector_dialog.dart 更新完成
- [ ] unified_reference_panel.dart 更新完成
- [ ] 旧 vibe_card_3d.dart 已删除
- [ ] Bundle 卡片悬停时显示百叶窗展开效果
- [ ] 非 Bundle 卡片悬停时显示简洁效果
- [ ] 项目分析无错误
- [ ] 所有引用已更新

---

## 注意事项

1. **测试 Bundle 卡片**: 确保有足够数据的 Bundle 条目来测试百叶窗效果
2. **性能**: 如果子 vibe 数量较多，考虑限制预览数量（当前限制为 5 个）
3. **主题适配**: 百叶窗颜色应随主题变化
4. **动画流畅度**: 在低端设备上测试动画性能
