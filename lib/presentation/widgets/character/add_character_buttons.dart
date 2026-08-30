import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/character_prompt_block_parser.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/tag_library_page_provider.dart';
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
          onTap: () => _addCharacter(ref, CharacterGender.female),
        ),
        _GenderButton(
          key: const Key('character-add-male'),
          icon: Icons.male,
          label: l10n.characterEditor_addMale,
          color: const Color(0xFF3B82F6),
          compact: compact,
          onTap: () => _addCharacter(ref, CharacterGender.male),
        ),
        _GenderButton(
          key: const Key('character-add-other'),
          icon: Icons.transgender,
          label: l10n.characterEditor_addOther,
          color: const Color(0xFF8B5CF6),
          compact: compact,
          onTap: () => _addCharacter(ref, CharacterGender.other),
        ),
        _LibraryButton(
          key: const Key('character-add-from-library'),
          compact: compact,
          onTap: () => _addFromLibrary(context, ref),
        ),
      ],
    );
  }

  void _addCharacter(WidgetRef ref, CharacterGender gender) {
    ref.read(characterPromptNotifierProvider.notifier).addCharacter(gender);
  }

  Future<void> _addFromLibrary(BuildContext context, WidgetRef ref) async {
    final entry = await showDialog(
      context: context,
      builder: (context) => const TagLibraryPickerDialog(),
    );

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

/// 性别按钮组件（无边框+色差风格）
class _GenderButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool compact;
  final VoidCallback onTap;

  const _GenderButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.compact,
    required this.onTap,
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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 6 : 12,
            vertical: widget.compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            // 无边框，常态淡背景，悬停时加深
            color: _isHovered
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
                          color: _isHovered
                              ? widget.color
                              : colorScheme.onSurfaceVariant,
                          fontWeight: _isHovered
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 词库按钮组件（无边框+色差风格）
class _LibraryButton extends StatefulWidget {
  final bool compact;
  final VoidCallback onTap;

  const _LibraryButton({super.key, required this.compact, required this.onTap});

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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 6 : 12,
            vertical: widget.compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            // 无边框，常态淡背景，悬停时加深
            color: _isHovered
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
                color: _isHovered ? accentColor : colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: widget.compact ? 3 : 5),
              Text(
                l10n.characterEditor_addFromLibrary,
                style:
                    (widget.compact
                            ? theme.textTheme.labelSmall
                            : theme.textTheme.labelMedium)
                        ?.copyWith(
                          color: _isHovered
                              ? accentColor
                              : colorScheme.onSurfaceVariant,
                          fontWeight: _isHovered
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
