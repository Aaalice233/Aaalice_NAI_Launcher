import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_panel_dock_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../common/app_toast.dart';
import 'character_editor_dialog.dart';
import 'character_tooltip_content.dart';

/// 多人角色提示词触发按钮
///
/// 显示在提示词区域工具栏中，点击打开角色编辑对话框。
/// 当存在角色时，显示角色数量徽章。
///
/// Requirements: 1.1, 5.3
class CharacterPromptButton extends ConsumerWidget {
  const CharacterPromptButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(characterPromptNotifierProvider);
    final characterCount = config.characters.length;
    final hasCharacters = characterCount > 0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDocked = ref.watch(characterPanelDockProvider);

    return _CharacterTooltipWrapper(
      config: config,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isDocked) {
                  // 停靠模式下提示用户面板已显示在图像区域
                  AppToast.info(
                    context,
                    AppLocalizations.of(context)!
                        .characterEditor_dockedHint,
                  );
                } else {
                  CharacterEditorDialog.show(context);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasCharacters
                        ? colorScheme.primary.withOpacity(0.5)
                        : colorScheme.outline.withOpacity(0.3),
                    width: 1,
                  ),
                  color: hasCharacters
                      ? colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _DynamicCharacterIcon(
                      characters: config.characters,
                      size: 18,
                      emptyColor: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)!.character_buttonLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: hasCharacters
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 按钮右上角角标
          if (hasCharacters)
            Positioned(
              right: -4,
              top: -4,
              child: _CharacterCountBadge(count: characterCount),
            ),
        ],
      ),
    );
  }
}

/// 角色数量角标
class _CharacterCountBadge extends StatelessWidget {
  final int count;

  const _CharacterCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(
        minWidth: 14,
        minHeight: 14,
      ),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 9,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// 紧凑版角色提示词按钮（仅图标）
///
/// 用于空间受限的工具栏
class CharacterPromptIconButton extends ConsumerWidget {
  const CharacterPromptIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(characterPromptNotifierProvider);
    final characterCount = config.characters.length;
    final hasCharacters = characterCount > 0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _CharacterTooltipWrapper(
      config: config,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: () => CharacterEditorDialog.show(context),
            icon: _DynamicCharacterIcon(
              characters: config.characters,
              size: 24,
              emptyColor: colorScheme.onSurfaceVariant,
            ),
          ),
          if (hasCharacters)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  characterCount.toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 动态角色图标组件
///
/// 根据角色列表动态显示人形图标：
/// - 无角色：显示空心人形轮廓
/// - 有角色：根据性别显示不同颜色的人形（粉色=女，蓝色=男，灰色=其他）
class _DynamicCharacterIcon extends StatelessWidget {
  final List<CharacterPrompt> characters;
  final double size;
  final Color emptyColor;

  const _DynamicCharacterIcon({
    required this.characters,
    required this.size,
    required this.emptyColor,
  });

  /// 根据性别获取对应颜色
  static Color getGenderColor(CharacterGender gender) {
    switch (gender) {
      case CharacterGender.female:
        return const Color(0xFFE91E63); // 粉色
      case CharacterGender.male:
        return const Color(0xFF2196F3); // 蓝色
      case CharacterGender.other:
        return const Color(0xFF9E9E9E); // 灰色
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabledCharacters = characters.where((c) => c.enabled).toList();

    if (enabledCharacters.isEmpty) {
      // 空状态：显示空心人形图标
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: _EmptyPersonPainter(color: emptyColor),
        ),
      );
    }

    // 有角色时：显示多个彩色人形
    // 最多显示4个人形图标，超过时仅显示前4个
    final displayCharacters = enabledCharacters.take(4).toList();
    final personWidth = size * 0.55;
    final overlap = personWidth * 0.3; // 重叠量
    final step = personWidth - overlap;
    final totalWidth = personWidth + (displayCharacters.length - 1) * step;

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < displayCharacters.length; i++)
            Positioned(
              left: i * step,
              top: 0,
              bottom: 0,
              width: personWidth,
              child: CustomPaint(
                size: Size(personWidth, size),
                painter: _FilledPersonPainter(
                  color: getGenderColor(displayCharacters[i].gender),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 空心人形图标绘制器
class _EmptyPersonPainter extends CustomPainter {
  final Color color;

  _EmptyPersonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final centerX = size.width / 2;
    final headRadius = size.height * 0.16;
    final bodyHeight = size.height * 0.48;
    final gap = size.height * 0.04;

    // 计算总高度并居中
    final totalHeight = headRadius * 2 + gap + bodyHeight;
    final startY = (size.height - totalHeight) / 2;
    final headCenterY = startY + headRadius;

    // 绘制头部（圆形）
    canvas.drawCircle(
      Offset(centerX, headCenterY),
      headRadius,
      paint,
    );

    // 绘制身体（简化的圆角矩形躯干）
    final bodyTop = headCenterY + headRadius + gap;
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(
        centerX - size.width * 0.30,
        bodyTop,
        size.width * 0.60,
        bodyHeight,
      ),
      topLeft: const Radius.circular(6),
      topRight: const Radius.circular(6),
      bottomLeft: const Radius.circular(3),
      bottomRight: const Radius.circular(3),
    );
    canvas.drawRRect(bodyRect, paint);
  }

  @override
  bool shouldRepaint(covariant _EmptyPersonPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// 实心人形图标绘制器
class _FilledPersonPainter extends CustomPainter {
  final Color color;

  _FilledPersonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final headRadius = size.height * 0.16;
    final bodyHeight = size.height * 0.48;
    final gap = size.height * 0.04;

    // 计算总高度并居中
    final totalHeight = headRadius * 2 + gap + bodyHeight;
    final startY = (size.height - totalHeight) / 2;
    final headCenterY = startY + headRadius;

    // 绘制头部（圆形）
    canvas.drawCircle(
      Offset(centerX, headCenterY),
      headRadius,
      paint,
    );

    // 绘制身体（简化的圆角矩形躯干）
    final bodyTop = headCenterY + headRadius + gap;
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(
        centerX - size.width * 0.32,
        bodyTop,
        size.width * 0.64,
        bodyHeight,
      ),
      topLeft: const Radius.circular(6),
      topRight: const Radius.circular(6),
      bottomLeft: const Radius.circular(3),
      bottomRight: const Radius.circular(3),
    );
    canvas.drawRRect(bodyRect, paint);
  }

  @override
  bool shouldRepaint(covariant _FilledPersonPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// 自定义悬浮提示包装器
///
/// 提供详细的多角色配置信息悬浮提示
class _CharacterTooltipWrapper extends StatelessWidget {
  final CharacterPromptConfig config;
  final Widget child;

  const _CharacterTooltipWrapper({
    required this.config,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Tooltip(
      richMessage: WidgetSpan(
        child: CharacterTooltipContent(config: config),
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      waitDuration: const Duration(milliseconds: 400),
      showDuration: const Duration(seconds: 8),
      preferBelow: true,
      child: child,
    );
  }
}
