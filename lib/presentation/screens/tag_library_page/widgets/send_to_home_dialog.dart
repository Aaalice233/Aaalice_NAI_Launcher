import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/comfyui_prompt_parser/pipe_parser.dart';
import '../../../../core/utils/sd_to_nai_converter.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../../presentation/providers/pending_prompt_provider.dart';

// 使用现有的 SendTargetType 从 pending_prompt_provider.dart

/// 发送选项配置
class SendOptions {
  final SendTargetType targetType;
  final bool sendAsAlias;

  const SendOptions({
    required this.targetType,
    this.sendAsAlias = false,
  });
}

/// 发送到主页对话框
///
/// 功能：
/// 1. 智能检测竖线格式并提供分解选项
/// 2. 实时预览发送效果
/// 3. 别名解析开关
class SendToHomeDialog extends ConsumerStatefulWidget {
  final TagLibraryEntry entry;

  const SendToHomeDialog({
    super.key,
    required this.entry,
  });

  static Future<SendOptions?> show(
    BuildContext context, {
    required TagLibraryEntry entry,
  }) {
    return showDialog<SendOptions>(
      context: context,
      builder: (context) => SendToHomeDialog(entry: entry),
    );
  }

  @override
  ConsumerState<SendToHomeDialog> createState() => _SendToHomeDialogState();
}

class _SendToHomeDialogState extends ConsumerState<SendToHomeDialog> {
  late SendTargetType _selectedTarget;
  bool _sendAsAlias = false;

  @override
  void initState() {
    super.initState();
    // 默认选择：如果是竖线格式，默认智能分解；否则发送到主提示词
    _selectedTarget = _isPipeFormat
        ? SendTargetType.smartDecompose
        : SendTargetType.mainPrompt;
  }

  /// 检测是否为竖线格式
  bool get _isPipeFormat => PipeParser.isPipeFormat(widget.entry.content);

  /// 获取发送内容
  /// 如果 sendAsAlias 为 true，返回 <条目名> 形式
  /// 否则返回实际内容
  String get _processedContent {
    if (_sendAsAlias) {
      // 作为别名发送：包装为 <条目名>
      return '<${widget.entry.name}>';
    }
    // 应用 SD→NAI 转换和格式化
    return SdToNaiConverter.convert(widget.entry.content);
  }

  /// 解析竖线格式结果
  ParsedResult get _parsedResult {
    // 如果作为别名发送，直接返回别名形式，不做竖线解析
    if (_sendAsAlias) {
      return ParsedResult(
        mainPrompt: _processedContent,
        characters: [],
      );
    }

    if (!_isPipeFormat) {
      return ParsedResult(
        mainPrompt: _processedContent,
        characters: [],
      );
    }

    final result = PipeParser.parse(_processedContent);
    return ParsedResult(
      mainPrompt: result.globalPrompt,
      characters: result.characters.map((c) => c.prompt).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parsedResult;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.send_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.sendToHome_dialogTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 发送目标选项
              _buildTargetOptions(theme),

              const SizedBox(height: 16),

              // 别名解析开关
              _buildAliasToggle(theme),

              const Divider(height: 24),

              // 预览区域
              _buildPreviewSection(theme, parsed),

              const SizedBox(height: 16),

              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.l10n.common_cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(
                          SendOptions(
                            targetType: _selectedTarget,
                            sendAsAlias: _sendAsAlias,
                          ),
                        );
                      },
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('发送'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建发送目标选项
  Widget _buildTargetOptions(ThemeData theme) {
    final options = <Widget>[];

    // 主提示词选项（始终可用）
    options.add(
      _TargetOptionTile(
        icon: Icons.auto_awesome,
        iconColor: theme.colorScheme.primary,
        title: context.l10n.sendToHome_mainPrompt,
        subtitle: _isPipeFormat
            ? '发送完整内容到主提示词（包含竖线）'
            : context.l10n.sendToHome_mainPromptSubtitle,
        isSelected: _selectedTarget == SendTargetType.mainPrompt,
        onTap: () =>
            setState(() => _selectedTarget = SendTargetType.mainPrompt),
      ),
    );

    // 智能分解选项（仅竖线格式可用）
    if (_isPipeFormat) {
      options.add(const SizedBox(height: 8));
      options.add(
        _TargetOptionTile(
          icon: Icons.account_tree,
          iconColor: theme.colorScheme.secondary,
          title: '智能分解',
          subtitle: '主提示词 + ${_parsedResult.characters.length}个角色',
          isSelected: _selectedTarget == SendTargetType.smartDecompose,
          onTap: () =>
              setState(() => _selectedTarget = SendTargetType.smartDecompose),
          isRecommended: true,
        ),
      );
    }

    // 角色选项
    options.add(const SizedBox(height: 8));
    options.add(
      _TargetOptionTile(
        icon: Icons.swap_horiz,
        iconColor: theme.colorScheme.tertiary,
        title: context.l10n.sendToHome_replaceCharacter,
        subtitle: context.l10n.sendToHome_replaceCharacterSubtitle,
        isSelected: _selectedTarget == SendTargetType.replaceCharacter,
        onTap: () =>
            setState(() => _selectedTarget = SendTargetType.replaceCharacter),
      ),
    );

    options.add(const SizedBox(height: 8));
    options.add(
      _TargetOptionTile(
        icon: Icons.person_add,
        iconColor: theme.colorScheme.tertiary,
        title: context.l10n.sendToHome_appendCharacter,
        subtitle: context.l10n.sendToHome_appendCharacterSubtitle,
        isSelected: _selectedTarget == SendTargetType.appendCharacter,
        onTap: () =>
            setState(() => _selectedTarget = SendTargetType.appendCharacter),
      ),
    );

    return Column(children: options);
  }

  /// 构建别名解析开关
  Widget _buildAliasToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.transform,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '作为别名发送',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '发送到主页时包装为 <${widget.entry.name}>',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _sendAsAlias,
            onChanged: (value) => setState(() => _sendAsAlias = value),
          ),
        ],
      ),
    );
  }

  /// 构建预览区域
  Widget _buildPreviewSection(ThemeData theme, ParsedResult parsed) {
    return Flexible(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.preview_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '发送预览',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: _buildPreviewContent(theme, parsed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建预览内容
  Widget _buildPreviewContent(ThemeData theme, ParsedResult parsed) {
    // 作为别名发送时，统一显示别名形式
    if (_sendAsAlias) {
      final label = switch (_selectedTarget) {
        SendTargetType.mainPrompt => '主提示词',
        SendTargetType.smartDecompose => '智能分解',
        SendTargetType.replaceCharacter ||
        SendTargetType.appendCharacter =>
          '角色提示词',
      };
      return _PreviewItem(
        label: label,
        content: _processedContent,
        color: _selectedTarget == SendTargetType.mainPrompt
            ? theme.colorScheme.primary
            : theme.colorScheme.tertiary,
      );
    }

    switch (_selectedTarget) {
      case SendTargetType.smartDecompose:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewItem(
              label: '主提示词',
              content: parsed.mainPrompt,
              color: theme.colorScheme.primary,
            ),
            ...parsed.characters.asMap().entries.map((e) {
              return _PreviewItem(
                label: '角色 ${e.key + 1}',
                content: e.value,
                color: theme.colorScheme.secondary,
              );
            }),
          ],
        );

      case SendTargetType.mainPrompt:
        return _PreviewItem(
          label: '主提示词',
          content: _processedContent,
          color: theme.colorScheme.primary,
        );

      case SendTargetType.replaceCharacter:
      case SendTargetType.appendCharacter:
        // 如果有竖线格式，只显示角色部分；否则显示全部内容
        final characterContent = _isPipeFormat && parsed.characters.isNotEmpty
            ? parsed.characters.join('\n| ')
            : _processedContent;
        return _PreviewItem(
          label: _isPipeFormat && parsed.characters.isNotEmpty
              ? '角色提示词 (${parsed.characters.length}个)'
              : '角色提示词',
          content: characterContent,
          color: theme.colorScheme.tertiary,
        );
    }
  }
}

/// 解析结果
class ParsedResult {
  final String mainPrompt;
  final List<String> characters;

  ParsedResult({
    required this.mainPrompt,
    required this.characters,
  });
}

/// 目标选项卡片
class _TargetOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isRecommended;

  const _TargetOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : null,
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                  if (isRecommended)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2,),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '推荐',
                          style: TextStyle(
                            fontSize: 8,
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                )
              else
                Icon(
                  Icons.circle_outlined,
                  color: theme.colorScheme.outline,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 预览项
class _PreviewItem extends StatelessWidget {
  final String label;
  final String content;
  final Color color;

  const _PreviewItem({
    required this.label,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content.isEmpty ? '(空)' : content,
            style: theme.textTheme.bodySmall?.copyWith(
              color: content.isEmpty
                  ? theme.colorScheme.outline
                  : theme.colorScheme.onSurface,
              fontFamily: 'monospace',
              height: 1.4,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
