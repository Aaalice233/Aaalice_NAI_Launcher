import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../prompt/toolbar/toolbar.dart';
import '../prompt/unified/unified.dart';

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
  late final TextEditingController _promptController = TextEditingController(
    text: widget.character.prompt,
  );
  late final TextEditingController _negativeController = TextEditingController(
    text: widget.character.negativePrompt,
  );
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
    // 外部状态变化（随机生成、词库导入等）时同步到输入框。
    // 输入框聚焦中绝不同步：生命周期内的 controller.text 赋值会重置
    // 光标并打断键盘输入连接，聚焦时以用户输入为准
    if (!_promptFocusNode.hasFocus &&
        widget.character.prompt != _promptController.text) {
      _promptController.text = widget.character.prompt;
    }
    if (!_negativeFocusNode.hasFocus &&
        widget.character.negativePrompt != _negativeController.text) {
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
            onChanged: (value) =>
                _updateCharacter(widget.character.copyWith(prompt: value)),
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
    final enableSdSyntaxAutoConvert = ref.watch(
      sdSyntaxAutoConvertSettingsProvider,
    );

    final inputConfig = UnifiedPromptConfig.compactMode.copyWith(
      hintText: hintText,
      enableAutocomplete: enableAutocomplete,
      enableAutoFormat: enableAutoFormat,
      enableSyntaxHighlight: enableHighlight,
      enableSdSyntaxAutoConvert: enableSdSyntaxAutoConvert,
      // 清空由 UnifiedPromptInput 内部处理并回调 onChanged('')，无需重复
      showClearButton: true,
      clearNeedsConfirm: true,
    );

    return PromptEditorWithToolbar(
      toolbarConfig: PromptEditorToolbarConfig.compactMode.copyWith(
        showClearButton: false,
      ),
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

/// 清空全部角色（带确认框），官网布局区块头与经典布局角色行共用
Future<void> confirmClearAllCharacters(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.characterEditor_clearAllTitle),
      content: Text(l10n.characterEditor_clearAllConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n.common_clear),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    ref.read(selectedCharacterIdProvider.notifier).clear();
    ref.read(characterPromptNotifierProvider.notifier).clearAllCharacters();
  }
}

/// 角色名称就地编辑框
///
/// 嵌在卡片/编辑面板头部的名字位置，点击即可直接改名，
/// 输入实时写回 provider（空白输入不生效，保留原名）。
class CharacterNameField extends ConsumerStatefulWidget {
  final CharacterPrompt character;
  final TextStyle? style;

  const CharacterNameField({super.key, required this.character, this.style});

  @override
  ConsumerState<CharacterNameField> createState() => _CharacterNameFieldState();
}

class _CharacterNameFieldState extends ConsumerState<CharacterNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.character.name,
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 失焦提交：输入过程完全本地，不触发 provider 更新与整卡重建，
    // 焦点和光标不会被打断
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty || trimmed == widget.character.name) return;
    ref
        .read(characterPromptNotifierProvider.notifier)
        .updateCharacter(widget.character.copyWith(name: trimmed));
  }

  @override
  void didUpdateWidget(CharacterNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character.id != widget.character.id) {
      _controller.text = widget.character.name;
      return;
    }
    // 外部改名（如词库导入覆盖）时同步；编辑中（持有焦点）不覆盖用户输入
    if (!_focusNode.hasFocus && widget.character.name != _controller.text) {
      _controller.text = widget.character.name;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLength: 50,
      maxLines: 1,
      style: widget.style,
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        counterText: '',
        border: InputBorder.none,
        hintText: l10n.characterEditor_nameHint,
        hintStyle: widget.style?.copyWith(
          color: widget.style?.color?.withValues(alpha: 0.5),
        ),
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}
