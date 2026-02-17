import 'package:flutter/material.dart';

import '../../../core/utils/comfyui_prompt_parser.dart';
import '../../../core/utils/comfyui_prompt_parser/models/comfyui_parse_result.dart';
import '../../../core/utils/comfyui_prompt_parser/position_converter.dart';
import '../../../data/models/character/character_prompt.dart';

/// ComfyUI 导入结果
class ComfyuiImportResult {
  /// 是否使用位置信息
  final bool usePosition;

  /// 解析结果
  final ComfyuiParseResult parseResult;

  const ComfyuiImportResult({
    required this.usePosition,
    required this.parseResult,
  });
}

/// ComfyUI 多角色提示词导入确认弹窗
///
/// 展示解析预览，让用户确认是否导入
class ComfyuiImportDialog extends StatefulWidget {
  /// 解析结果
  final ComfyuiParseResult parseResult;

  const ComfyuiImportDialog({
    super.key,
    required this.parseResult,
  });

  /// 显示导入弹窗
  ///
  /// 返回 null 表示用户取消
  static Future<ComfyuiImportResult?> show({
    required BuildContext context,
    required ComfyuiParseResult parseResult,
  }) {
    return showDialog<ComfyuiImportResult>(
      context: context,
      builder: (context) => ComfyuiImportDialog(parseResult: parseResult),
    );
  }

  @override
  State<ComfyuiImportDialog> createState() => _ComfyuiImportDialogState();
}

class _ComfyuiImportDialogState extends State<ComfyuiImportDialog> {
  bool _usePosition = true;

  @override
  void initState() {
    super.initState();
    // 如果没有位置信息，默认不勾选
    _usePosition = widget.parseResult.hasPositionInfo;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final characters = widget.parseResult.characters;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.transform,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('检测到 ComfyUI 多角色提示词'),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 语法类型提示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getSyntaxTypeName(widget.parseResult.syntaxType),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 全局提示词卡片
            if (widget.parseResult.globalPrompt.isNotEmpty) ...[
              _GlobalPromptCard(prompt: widget.parseResult.globalPrompt),
              const SizedBox(height: 12),
            ],

            // 角色列表
            Text(
              '角色列表 (${characters.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: characters.length,
                itemBuilder: (context, index) => _CharacterCard(
                  index: index + 1,
                  character: characters[index],
                ),
              ),
            ),

            // 位置选项
            if (widget.parseResult.hasPositionInfo) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _usePosition,
                onChanged: (value) {
                  setState(() => _usePosition = value ?? true);
                },
                title: const Text('使用位置信息'),
                subtitle: const Text('将 ComfyUI 区域映射为 NAI 角色位置'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              ComfyuiImportResult(
                usePosition: _usePosition,
                parseResult: widget.parseResult,
              ),
            );
          },
          child: Text('转换 ${characters.length} 个角色'),
        ),
      ],
    );
  }

  String _getSyntaxTypeName(ComfyuiSyntaxType type) {
    switch (type) {
      case ComfyuiSyntaxType.couple:
        return 'COUPLE 语法';
      case ComfyuiSyntaxType.andMask:
        return 'AND+MASK 语法';
      case ComfyuiSyntaxType.pipe:
        return '竖线格式';
      case ComfyuiSyntaxType.unknown:
        return '未知语法';
    }
  }
}

/// 全局提示词卡片
class _GlobalPromptCard extends StatelessWidget {
  final String prompt;

  const _GlobalPromptCard({required this.prompt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.public,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '全局提示词',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            prompt,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 角色卡片
class _CharacterCard extends StatelessWidget {
  final int index;
  final ParsedCharacter character;

  const _CharacterCard({
    required this.index,
    required this.character,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gender = character.inferredGender ?? CharacterGender.female;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 角色编号
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$index',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 性别图标
          Icon(
            gender == CharacterGender.male ? Icons.male : Icons.female,
            size: 16,
            color: gender == CharacterGender.male ? Colors.blue : Colors.pink,
          ),
          const SizedBox(width: 8),

          // 提示词预览
          Expanded(
            child: Text(
              character.prompt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),

          // 位置标签
          if (character.position != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                PositionConverter.toNaiPosition(character.position!)
                    .toNaiString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
