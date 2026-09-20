import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/character_prompt_block_parser.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../common/app_toast.dart';
import '../tag_library/tag_library_picker_dialog.dart';

/// 添加角色按钮组件。
///
/// [compact] 用于角色二级菜单标题行，保留文字识别的同时缩小内边距。
class AddCharacterButtons extends ConsumerWidget {
  const AddCharacterButtons({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasScaledText = MediaQuery.textScalerOf(context).scale(14) > 14;
    // 偏离上游：上游只在 inline_character_row 的行尾添加芯片上做了上限处理，
    // 本组件（挂在参数面板与 web_left_panel 的 headerActions，移动端同样可达）
    // 全文没有任何上限判断，到达官方上限后 addCharacter 只写一行日志就 return，
    // 表现是"点了没反应"。而且上游那处只给 tooltip——触屏没有 hover，
    // 要长按才看得到原因，等于没有提示，所以这里点击也必须有可见反馈。
    final limitReached = ref.watch(characterLimitReachedProvider);
    final disabledReason = limitReached
        ? l10n.character_limitReached(
            ref
                .read(characterPromptNotifierProvider.notifier)
                .characterLimit
                .toString(),
          )
        : null;

    return Wrap(
      spacing: compact && hasScaledText ? 2 : 4,
      runSpacing: 4,
      children: [
        _GenderButton(
          key: const Key('character-add-female'),
          icon: Icons.female,
          label: l10n.characterEditor_addFemale,
          color: const Color(0xFFEC4899),
          compact: compact,
          disabledReason: disabledReason,
          onTap: () => _addCharacter(ref, CharacterGender.female),
        ),
        _GenderButton(
          key: const Key('character-add-male'),
          icon: Icons.male,
          label: l10n.characterEditor_addMale,
          color: const Color(0xFF3B82F6),
          compact: compact,
          disabledReason: disabledReason,
          onTap: () => _addCharacter(ref, CharacterGender.male),
        ),
        _GenderButton(
          key: const Key('character-add-other'),
          icon: Icons.transgender,
          label: l10n.characterEditor_addOther,
          color: const Color(0xFF8B5CF6),
          compact: compact,
          disabledReason: disabledReason,
          onTap: () => _addCharacter(ref, CharacterGender.other),
        ),
        _LibraryButton(
          key: const Key('character-add-from-library'),
          compact: compact,
          disabledReason: disabledReason,
          onTap: () => _addFromLibrary(context, ref),
        ),
      ],
    );
  }

  void _addCharacter(WidgetRef ref, CharacterGender gender) {
    ref.read(characterPromptNotifierProvider.notifier).addCharacter(gender);
  }

  Future<void> _addFromLibrary(BuildContext context, WidgetRef ref) async {
    final entry = await TagLibraryPickerDialog.show(context);

    if (entry != null) {
      final parsed = CharacterPromptBlockParser.parse(entry.content);
      // 记录使用
      ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entry.id);

      // 创建新角色
      ref
          .read(characterPromptNotifierProvider.notifier)
          .addCharacter(
            CharacterGender.female, // 默认女性
            name: entry.displayName,
            prompt: parsed.positivePrompt,
            negativePrompt: parsed.hasNegativeBlock
                ? parsed.negativePrompt
                : null,
            thumbnailPath: entry.thumbnail,
          );
    }
  }
}

/// 禁用态包装：变灰 + tooltip（桌面悬停 / 触屏长按）
///
/// 点击反馈由各按钮自己在 onTap 里给 toast，见 AddCharacterButtons 的注释。
Widget _wrapDisabled({required String? disabledReason, required Widget child}) {
  if (disabledReason == null) return child;
  return Tooltip(
    message: disabledReason,
    child: Opacity(opacity: 0.45, child: child),
  );
}

/// 性别按钮组件（无边框+色差风格）
class _GenderButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool compact;
  final VoidCallback onTap;

  /// 非空表示不可用（当前只有「已达角色上限」一种原因），
  /// 同一句文案同时用于 tooltip 与点击后的 toast
  final String? disabledReason;

  const _GenderButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.compact,
    required this.onTap,
    this.disabledReason,
  });

  @override
  State<_GenderButton> createState() => _GenderButtonState();
}

class _GenderButtonState extends State<_GenderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disabled = widget.disabledReason != null;
    final hovered = _isHovered && !disabled;

    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final reason = widget.disabledReason;
          if (reason != null) {
            AppToast.warning(context, reason);
            return;
          }
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 6 : 12,
            vertical: widget.compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            // 无边框，常态淡背景，悬停时加深
            color: hovered
                ? widget.color.withValues(alpha: 0.18)
                : widget.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: widget.compact ? 15 : 17,
                color: widget.color,
              ),
              SizedBox(width: widget.compact ? 3 : 5),
              Text(
                widget.label,
                style:
                    (widget.compact
                            ? theme.textTheme.labelSmall
                            : theme.textTheme.labelMedium)
                        ?.copyWith(
                          color: hovered
                              ? widget.color
                              : colorScheme.onSurfaceVariant,
                          fontWeight: hovered
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
              ),
            ],
          ),
        ),
      ),
    );
    return _wrapDisabled(
      disabledReason: widget.disabledReason,
      child: button,
    );
  }
}

/// 词库按钮组件（无边框+色差风格）
class _LibraryButton extends StatefulWidget {
  final bool compact;
  final VoidCallback onTap;

  /// 见 [_GenderButton.disabledReason]
  final String? disabledReason;

  const _LibraryButton({
    super.key,
    required this.compact,
    required this.onTap,
    this.disabledReason,
  });

  @override
  State<_LibraryButton> createState() => _LibraryButtonState();
}

class _LibraryButtonState extends State<_LibraryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final accentColor = colorScheme.tertiary;
    final disabled = widget.disabledReason != null;
    final hovered = _isHovered && !disabled;

    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final reason = widget.disabledReason;
          if (reason != null) {
            AppToast.warning(context, reason);
            return;
          }
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 6 : 12,
            vertical: widget.compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            // 无边框，常态淡背景，悬停时加深
            color: hovered
                ? accentColor.withValues(alpha: 0.18)
                : accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: widget.compact ? 15 : 17,
                color: hovered ? accentColor : colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: widget.compact ? 3 : 5),
              Text(
                l10n.characterEditor_addFromLibrary,
                style:
                    (widget.compact
                            ? theme.textTheme.labelSmall
                            : theme.textTheme.labelMedium)
                        ?.copyWith(
                          color: hovered
                              ? accentColor
                              : colorScheme.onSurfaceVariant,
                          fontWeight: hovered
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
              ),
            ],
          ),
        ),
      ),
    );
    return _wrapDisabled(
      disabledReason: widget.disabledReason,
      child: button,
    );
  }
}
