import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../common/themed_switch.dart';
import '../prompt/toolbar/toolbar.dart';
import '../prompt/unified/unified.dart';
import 'position_grid_selector.dart';

/// 角色提示词编辑器（正/负切换 + 统一提示词编辑器）
///
/// 官网布局的卡内编辑与经典布局的全宽编辑面板共用。
/// 挂载时自动把光标送进当前输入框；输入实时写回 provider。
class CharacterPromptEditor extends ConsumerStatefulWidget {
  final CharacterPrompt character;
  final bool compact;

  const CharacterPromptEditor({
    super.key,
    required this.character,
    this.compact = false,
  });

  @override
  ConsumerState<CharacterPromptEditor> createState() =>
      _CharacterPromptEditorState();
}

class _CharacterPromptEditorState extends ConsumerState<CharacterPromptEditor> {
  late final TextEditingController _promptController =
      TextEditingController(text: widget.character.prompt);
  late final TextEditingController _negativeController =
      TextEditingController(text: widget.character.negativePrompt);
  final FocusNode _promptFocusNode = FocusNode();
  final FocusNode _negativeFocusNode = FocusNode();

  /// 0 = 正向提示词，1 = 负向提示词
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    // 编辑器只在进入编辑态时挂载，挂载即聚焦
    _focusCurrentTab();
  }

  @override
  void didUpdateWidget(CharacterPromptEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换编辑目标（同一面板复用 State）时重置输入框并重新聚焦
    if (oldWidget.character.id != widget.character.id) {
      _promptController.text = widget.character.prompt;
      _negativeController.text = widget.character.negativePrompt;
      _focusCurrentTab();
      return;
    }
    // 外部状态变化（随机生成、词库导入等）时同步到输入框，
    // 与当前文本一致时跳过，避免打字回环导致光标跳动
    if (widget.character.prompt != _promptController.text) {
      _promptController.text = widget.character.prompt;
    }
    if (widget.character.negativePrompt != _negativeController.text) {
      _negativeController.text = widget.character.negativePrompt;
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativeController.dispose();
    _promptFocusNode.dispose();
    _negativeFocusNode.dispose();
    super.dispose();
  }

  /// 输入框是否持有焦点（供外层 TapRegion 判断是否应退出编辑态）
  bool get hasEditorFocus =>
      _promptFocusNode.hasFocus || _negativeFocusNode.hasFocus;

  void _focusCurrentTab() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_tabIndex == 0 ? _promptFocusNode : _negativeFocusNode).requestFocus();
    });
  }

  void _updateCharacter(CharacterPrompt updated) {
    ref.read(characterPromptNotifierProvider.notifier).updateCharacter(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _EditorTab(
              label: l10n.prompt_positivePrompt,
              selected: _tabIndex == 0,
              onTap: () {
                setState(() => _tabIndex = 0);
                _focusCurrentTab();
              },
            ),
            const SizedBox(width: 6),
            _EditorTab(
              label: l10n.prompt_negativePrompt,
              selected: _tabIndex == 1,
              onTap: () {
                setState(() => _tabIndex = 1);
                _focusCurrentTab();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_tabIndex == 0)
          _buildPromptEditor(
            controller: _promptController,
            focusNode: _promptFocusNode,
            hintText: l10n.characterEditor_promptHint,
            onChanged: (value) => _updateCharacter(
              widget.character.copyWith(prompt: value),
            ),
          )
        else
          _buildPromptEditor(
            controller: _negativeController,
            focusNode: _negativeFocusNode,
            hintText: l10n.characterEditor_negativePromptHint,
            onChanged: (value) => _updateCharacter(
              widget.character.copyWith(negativePrompt: value),
            ),
          ),
      ],
    );
  }

  Widget _buildPromptEditor({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String? hintText,
    required ValueChanged<String> onChanged,
  }) {
    final enableAutocomplete = ref.watch(autocompleteSettingsProvider);
    final enableAutoFormat = ref.watch(autoFormatPromptSettingsProvider);
    final enableHighlight = ref.watch(highlightEmphasisSettingsProvider);
    final enableSdSyntaxAutoConvert =
        ref.watch(sdSyntaxAutoConvertSettingsProvider);

    final inputConfig = UnifiedPromptConfig.compactMode.copyWith(
      hintText: hintText,
      enableAutocomplete: enableAutocomplete,
      enableAutoFormat: enableAutoFormat,
      enableSyntaxHighlight: enableHighlight,
      enableSdSyntaxAutoConvert: enableSdSyntaxAutoConvert,
      showClearButton: true,
      clearNeedsConfirm: true,
      onClearPressed: () => onChanged(''),
    );

    return PromptEditorWithToolbar(
      toolbarConfig:
          PromptEditorToolbarConfig.compactMode.copyWith(showClearButton: false),
      inputConfig: inputConfig,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onCleared: () => onChanged(''),
      minLines: widget.compact ? 1 : 2,
      maxLines: widget.compact ? 4 : 6,
    );
  }
}

/// 编辑态正/负切换小标签
class _EditorTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _EditorTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 角色位置设置对话框
///
/// 集中管理位置相关设置：全局 AI 选择开关 + 该角色的 5x5 网格位置。
/// 全局 AI 开启时网格禁用。
class CharacterPositionDialog extends ConsumerWidget {
  final String characterId;

  const CharacterPositionDialog({super.key, required this.characterId});

  static Future<void> show(BuildContext context, String characterId) {
    return showDialog<void>(
      context: context,
      builder: (context) => CharacterPositionDialog(characterId: characterId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final config = ref.watch(characterPromptNotifierProvider);
    final character = config.findCharacterById(characterId);
    if (character == null) {
      return const SizedBox.shrink();
    }
    final globalAiChoice = config.globalAiChoice;

    return AlertDialog(
      title: Text(l10n.characterEditor_position),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.characterEditor_globalAiChoice,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Tooltip(
                message: l10n.characterEditor_globalAiChoiceHint,
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              ThemedSwitch(
                value: globalAiChoice,
                onChanged: (value) => ref
                    .read(characterPromptNotifierProvider.notifier)
                    .setGlobalAiChoice(value),
                scale: 0.85,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: globalAiChoice ? 0.4 : 1.0,
            child: LabeledPositionGridSelector(
              selectedPosition: character.customPosition ??
                  const CharacterPosition(row: 0.5, column: 0.5),
              enabled: !globalAiChoice,
              onPositionSelected: (position) {
                ref.read(characterPromptNotifierProvider.notifier).updateCharacter(
                      character.copyWith(
                        customPosition: position,
                        positionMode: CharacterPositionMode.custom,
                      ),
                    );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_close),
        ),
      ],
    );
  }
}

/// 角色重命名对话框，确认后直接写回 provider
Future<void> showCharacterRenameDialog(
  BuildContext context,
  WidgetRef ref,
  CharacterPrompt character,
) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: character.name);
  final newName = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.characterEditor_name),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 50,
        decoration: InputDecoration(
          hintText: l10n.characterEditor_nameHint,
          counterText: '',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(l10n.common_save),
        ),
      ],
    ),
  );
  controller.dispose();

  final trimmed = newName?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    ref
        .read(characterPromptNotifierProvider.notifier)
        .updateCharacter(character.copyWith(name: trimmed));
  }
}
