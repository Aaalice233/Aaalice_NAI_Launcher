import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../tag_library/tag_library_picker_dialog.dart';

/// 添加角色按钮组件
///
/// 包含性别按钮（女/男/其他）和词库按钮，横向布局
/// 采用无边框+色差的简洁风格
class AddCharacterButtons extends ConsumerWidget {
  const AddCharacterButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        // 女性按钮
        _GenderButton(
          icon: Icons.female,
          label: l10n.characterEditor_addFemale,
          color: const Color(0xFFEC4899), // pink-500
          onTap: () => _addCharacter(ref, CharacterGender.female),
        ),
        // 男性按钮
        _GenderButton(
          icon: Icons.male,
          label: l10n.characterEditor_addMale,
          color: const Color(0xFF3B82F6), // blue-500
          onTap: () => _addCharacter(ref, CharacterGender.male),
        ),
        // 其他按钮
        _GenderButton(
          icon: Icons.transgender,
          label: l10n.characterEditor_addOther,
          color: const Color(0xFF8B5CF6), // violet-500
          onTap: () => _addCharacter(ref, CharacterGender.other),
        ),
        // 词库按钮
        _LibraryButton(
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
      // 记录使用
      ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entry.id);

      // 创建新角色
      ref.read(characterPromptNotifierProvider.notifier).addCharacter(
            CharacterGender.female, // 默认女性
            name: entry.displayName,
            prompt: entry.content,
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
  final VoidCallback onTap;

  const _GenderButton({
    required this.icon,
    required this.label,
    required this.color,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            // 无边框，常态淡背景，悬停时加深
            color: _isHovered
                ? widget.color.withOpacity(0.18)
                : widget.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                size: 15,
                color: _isHovered
                    ? widget.color
                    : colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              const SizedBox(width: 2),
              Icon(
                widget.icon,
                size: 17,
                color: widget.color,
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color:
                      _isHovered ? widget.color : colorScheme.onSurfaceVariant,
                  fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
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
  final VoidCallback onTap;

  const _LibraryButton({required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            // 无边框，常态淡背景，悬停时加深
            color: _isHovered
                ? accentColor.withOpacity(0.18)
                : accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 17,
                color: _isHovered ? accentColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                l10n.characterEditor_addFromLibrary,
                style: theme.textTheme.labelMedium?.copyWith(
                  color:
                      _isHovered ? accentColor : colorScheme.onSurfaceVariant,
                  fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
