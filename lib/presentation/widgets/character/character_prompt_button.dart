import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/character_prompt_block_parser.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../common/rich_tooltip_surface.dart';
import '../tag_library/tag_library_picker_dialog.dart';
import 'character_tooltip_content.dart';

enum _CharacterAddAction {
  female(CharacterGender.female),
  male(CharacterGender.male),
  other(CharacterGender.other),
  library(null);

  const _CharacterAddAction(this.gender);

  final CharacterGender? gender;
}

/// 多人角色提示词触发按钮
///
/// 显示在提示词区域工具栏中，作为内联角色区的状态指示器：
/// - 有角色时点击选中第一个角色进入编辑（角色区常显于布局中）
/// - 无角色时点击弹出添加菜单（女/男/其他/词库）
/// - 当存在角色时，显示角色数量徽章
class CharacterPromptButton extends ConsumerWidget {
  const CharacterPromptButton({
    super.key,
    this.onManage,
    this.compact = false,
    this.iconOnly = false,
  });

  /// When supplied, the button opens an existing-character manager instead of
  /// acting as another add shortcut. The manager owns its own add action.
  final VoidCallback? onManage;
  final bool compact;
  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(characterPromptNotifierProvider);
    final characterCount = config.characters.length;
    final hasCharacters = characterCount > 0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final buttonContent = Container(
      constraints: BoxConstraints(minHeight: compact ? 36 : 48),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: hasCharacters
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerLow,
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
          if (!iconOnly) ...[
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
        ],
      ),
    );

    return _CharacterTooltipWrapper(
      config: config,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: onManage == null
                ? _AddCharacterMenu(child: buttonContent)
                : InkWell(
                    onTap: onManage,
                    borderRadius: BorderRadius.circular(10),
                    child: buttonContent,
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

/// 无角色时的添加菜单包装
class _AddCharacterMenu extends ConsumerWidget {
  final Widget child;

  const _AddCharacterMenu({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<_CharacterAddAction>(
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: (action) => _handleAdd(context, ref, action),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _CharacterAddAction.female,
          child: _menuRow(
            Icons.female,
            l10n.characterEditor_addFemale,
            const Color(0xFFEC4899),
          ),
        ),
        PopupMenuItem(
          value: _CharacterAddAction.male,
          child: _menuRow(
            Icons.male,
            l10n.characterEditor_addMale,
            const Color(0xFF3B82F6),
          ),
        ),
        PopupMenuItem(
          value: _CharacterAddAction.other,
          child: _menuRow(
            Icons.transgender,
            l10n.characterEditor_addOther,
            const Color(0xFF8B5CF6),
          ),
        ),
        PopupMenuItem(
          value: _CharacterAddAction.library,
          child: _menuRow(
            Icons.library_books_outlined,
            l10n.characterEditor_addFromLibrary,
            theme.colorScheme.tertiary,
          ),
        ),
      ],
      child: child,
    );
  }

  Widget _menuRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }

  Future<void> _handleAdd(
    BuildContext context,
    WidgetRef ref,
    _CharacterAddAction action,
  ) async {
    final notifier = ref.read(characterPromptNotifierProvider.notifier);
    final gender = action.gender;

    if (gender != null) {
      notifier.addCharacter(gender);
      _selectLast(ref);
      return;
    }

    final entry = await TagLibraryPickerDialog.show(context);
    if (entry != null) {
      final parsed = CharacterPromptBlockParser.parse(entry.content);
      ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entry.id);
      notifier.addCharacter(
        CharacterGender.female,
        name: entry.displayName,
        prompt: parsed.positivePrompt,
        negativePrompt: parsed.hasNegativeBlock ? parsed.negativePrompt : null,
        thumbnailPath: entry.thumbnail,
      );
      _selectLast(ref);
    }
  }

  /// 新增后直接选中进入编辑，省一次点击
  void _selectLast(WidgetRef ref) {
    final characters = ref.read(characterPromptNotifierProvider).characters;
    if (characters.isNotEmpty) {
      ref.read(selectedCharacterIdProvider.notifier).select(characters.last.id);
    }
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
      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
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

  /// 根据性别获取对应颜色（与角色卡配色一致）
  static Color getGenderColor(CharacterGender gender) {
    switch (gender) {
      case CharacterGender.female:
        return const Color(0xFFEC4899); // 粉色
      case CharacterGender.male:
        return const Color(0xFF3B82F6); // 蓝色
      case CharacterGender.other:
        return const Color(0xFF8B5CF6); // 紫色
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
                  // 颜色跟随提示词首 tag 推导的有效性别
                  color: getGenderColor(displayCharacters[i].effectiveGender),
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
    canvas.drawCircle(Offset(centerX, headCenterY), headRadius, paint);

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
    canvas.drawCircle(Offset(centerX, headCenterY), headRadius, paint);

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

  const _CharacterTooltipWrapper({required this.config, required this.child});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      richMessage: WidgetSpan(child: CharacterTooltipContent(config: config)),
      constraints: const BoxConstraints(maxWidth: 380),
      ignorePointer: false,
      decoration: richTooltipOuterDecoration,
      padding: EdgeInsets.zero,
      waitDuration: const Duration(milliseconds: 400),
      showDuration: const Duration(seconds: 8),
      preferBelow: true,
      child: child,
    );
  }
}
