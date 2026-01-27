import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../../data/models/prompt/weighted_tag.dart';
import '../../../widgets/autocomplete/autocomplete.dart';
import '../../../widgets/common/emoji_picker_dialog.dart';

/// 自定义词组编辑器组件
///
/// 用于创建和编辑自定义词组，包含：
/// - 词组名称和emoji选择（紧凑布局）
/// - 多行文本框编辑词条（支持补全，逗号分隔）
class CustomTagGroupEditor extends ConsumerStatefulWidget {
  /// 初始词组（用于编辑模式）
  final RandomTagGroup? initialGroup;

  /// 保存回调
  final void Function(RandomTagGroup group) onSave;

  /// 取消回调
  final VoidCallback? onCancel;

  const CustomTagGroupEditor({
    super.key,
    this.initialGroup,
    required this.onSave,
    this.onCancel,
  });

  @override
  ConsumerState<CustomTagGroupEditor> createState() =>
      _CustomTagGroupEditorState();
}

class _CustomTagGroupEditorState extends ConsumerState<CustomTagGroupEditor> {
  late TextEditingController _nameController;
  late TextEditingController _tagsController;
  late FocusNode _tagsFocusNode;
  String _selectedEmoji = '✨';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialGroup?.name ?? '',
    );
    _tagsFocusNode = FocusNode();

    // 初始化标签内容
    if (widget.initialGroup != null) {
      _selectedEmoji = widget.initialGroup!.emoji.isNotEmpty
          ? widget.initialGroup!.emoji
          : '✨';
      // 将tags转换为逗号分隔的字符串
      final tagsText = widget.initialGroup!.tags.map((t) => t.tag).join(', ');
      _tagsController = TextEditingController(text: tagsText);
    } else {
      _tagsController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagsController.dispose();
    _tagsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _showEmojiPicker() async {
    final emoji = await EmojiPickerDialog.show(
      context,
      initialEmoji: _selectedEmoji,
    );
    if (emoji != null && mounted) {
      setState(() => _selectedEmoji = emoji);
    }
  }

  List<WeightedTag> _parseTagsFromText() {
    final text = _tagsController.text;
    if (text.trim().isEmpty) return [];

    // 按逗号分隔，清理空白
    final tags = text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .map(
          (t) => WeightedTag(
            tag: t,
            weight: 1,
            source: TagSource.custom,
          ),
        )
        .toList();

    return tags;
  }

  int _getTagCount() {
    final text = _tagsController.text;
    if (text.trim().isEmpty) return 0;
    return text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .length;
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.customGroup_nameRequired)),
      );
      return;
    }

    final tags = _parseTagsFromText();
    final group = RandomTagGroup.custom(
      name: name,
      emoji: _selectedEmoji,
      tags: tags,
    );
    widget.onSave(group);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // === 头部：Emoji + 名称（紧凑一行）===
        Row(
          children: [
            // Emoji 选择器（小尺寸）
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showEmojiPicker,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _selectedEmoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 名称输入框
            Expanded(
              child: TextField(
                controller: _nameController,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: l10n.customGroup_groupName,
                  hintStyle: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // === 标签文本框（多行，带补全）===
        Expanded(
          child: AutocompleteTextField(
            controller: _tagsController,
            focusNode: _tagsFocusNode,
            enableAutocomplete: true,
            useInsetShadow: false,
            config: const AutocompleteConfig(
              maxSuggestions: 8,
              autoInsertComma: true,
            ),
            maxLines: null,
            expands: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l10n.customGroup_tagsPlaceholder,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline.withOpacity(0.5),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.5),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),

        const SizedBox(height: 12),

        // === 底部：统计 + 按钮 ===
        Row(
          children: [
            // 统计信息
            Text(
              l10n.customGroup_entryCount(_getTagCount()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const Spacer(),
            // 取消按钮
            TextButton(
              onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.outline,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              child: Text(l10n.addGroup_cancel),
            ),
            const SizedBox(width: 8),
            // 保存按钮
            FilledButton(
              onPressed: _handleSave,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
              ),
              child: Text(l10n.customGroup_save),
            ),
          ],
        ),
      ],
    );
  }
}
