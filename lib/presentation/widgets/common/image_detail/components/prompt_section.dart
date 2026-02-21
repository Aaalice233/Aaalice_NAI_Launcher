import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../data/services/tag_translation_service.dart';
import '../../app_toast.dart';

/// 提示词分组展示组件
///
/// 用于在图像详情页中展示分组提示词（主提示词、固定词、质量词等）
/// 支持展开/折叠、复制、添加到词库等功能
class PromptSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final String content;
  final List<String>? tags;
  final bool initiallyExpanded;
  final bool showAddToLibrary;
  final VoidCallback? onAddToLibrary;
  final Color? contentColor;
  final Color? borderColor;
  final bool showTranslation;
  final Widget? customContent;

  const PromptSection({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    this.tags,
    this.initiallyExpanded = false,
    this.showAddToLibrary = false,
    this.onAddToLibrary,
    this.contentColor,
    this.borderColor,
    this.showTranslation = true,
    this.customContent,
  });

  @override
  State<PromptSection> createState() => _PromptSectionState();
}

class _PromptSectionState extends State<PromptSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _copyContent() {
    if (widget.content.isEmpty) return;
    Clipboard.setData(ClipboardData(text: widget.content));
    AppToast.success(context, '${widget.title}已复制');
  }

  void _copyTag(String tag) {
    Clipboard.setData(ClipboardData(text: tag));
    AppToast.success(context, '标签已复制');
  }

  List<String> get _displayTags {
    if (widget.tags != null) return widget.tags!;
    if (widget.content.isEmpty) return [];
    return widget.content.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  int get _tagCount {
    if (widget.tags != null) return widget.tags!.length;
    return _displayTags.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasContent = widget.content.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(colorScheme, theme, hasContent),
        AnimatedCrossFade(
          firstChild: const SizedBox(height: 0),
          secondChild: Column(
            children: [
              const SizedBox(height: 10),
              _buildContent(colorScheme, theme, _displayTags),
            ],
          ),
          crossFadeState: _isExpanded && hasContent
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, ThemeData theme, bool hasContent) {
    final primaryColor = hasContent ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: hasContent ? () => setState(() => _isExpanded = !_isExpanded) : null,
            child: MouseRegion(
              cursor: hasContent ? SystemMouseCursors.click : SystemMouseCursors.basic,
              child: Row(
                children: [
                  Icon(widget.icon, size: 16, color: primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasContent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_tagCount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (hasContent)
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (hasContent) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: _copyContent,
            icon: Icon(Icons.copy, size: 16, color: colorScheme.onSurfaceVariant),
            tooltip: '复制${widget.title}',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(28, 28),
            ),
          ),
          if (widget.showAddToLibrary && widget.onAddToLibrary != null)
            IconButton(
              onPressed: widget.onAddToLibrary,
              icon: Icon(Icons.library_add, size: 16, color: colorScheme.onSurfaceVariant),
              tooltip: '添加到词库',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(6),
                minimumSize: const Size(28, 28),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildContent(ColorScheme colorScheme, ThemeData theme, List<String> tags) {
    final borderColor = widget.borderColor?.withOpacity(0.2) ?? colorScheme.outline.withOpacity(0.1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: widget.customContent ?? (tags.isNotEmpty
          ? _TagChipGrid(
              tags: tags,
              onTagTap: _copyTag,
              contentColor: widget.contentColor,
              showTranslation: widget.showTranslation,
            )
          : Text(
              '(无内容)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )),
    );
  }
}

/// 标签芯片网格组件
class _TagChipGrid extends StatelessWidget {
  final List<String> tags;
  final void Function(String) onTagTap;
  final Color? contentColor;
  final bool showTranslation;

  const _TagChipGrid({
    required this.tags,
    required this.onTagTap,
    this.contentColor,
    this.showTranslation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags.map((tag) => _TranslatedTagChip(
        tag: tag,
        onTap: () => onTagTap(tag),
        contentColor: contentColor,
        showTranslation: showTranslation,
      ),).toList(),
    );
  }
}

/// 带翻译的标签芯片组件
class _TranslatedTagChip extends ConsumerStatefulWidget {
  final String tag;
  final VoidCallback onTap;
  final Color? contentColor;
  final bool showTranslation;

  const _TranslatedTagChip({
    required this.tag,
    required this.onTap,
    this.contentColor,
    this.showTranslation = true,
  });

  @override
  ConsumerState<_TranslatedTagChip> createState() => _TranslatedTagChipState();
}

class _TranslatedTagChipState extends ConsumerState<_TranslatedTagChip> {
  bool _isHovered = false;
  String? _translation;

  @override
  void initState() {
    super.initState();
    _loadTranslation();
  }

  @override
  void didUpdateWidget(_TranslatedTagChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tag != oldWidget.tag) {
      _translation = null;
      _loadTranslation();
    }
  }

  Future<void> _loadTranslation() async {
    if (!widget.showTranslation) return;
    final service = ref.read(tagTranslationServiceProvider);
    // 提取基础标签（去除权重语法）
    final baseTag = _extractBaseTag(widget.tag);
    final result = await service.translate(baseTag);
    if (mounted && result != null) {
      setState(() => _translation = result);
    }
  }

  /// 从带权重的标签中提取基础标签
  /// 例如: "1.10::jaggy_lines::" -> "jaggy_lines"
  String _extractBaseTag(String tag) {
    var text = tag.trim();
    
    // 1. 处理 NAI 数值权重语法: weight::text::
    final weightMatch = RegExp(r'^(-?\d+\.?\d*)::(.+?)(?:::)?$').firstMatch(text);
    if (weightMatch != null) {
      text = weightMatch.group(2)!.trim();
      return text;
    }
    
    // 2. 处理结尾的 ::
    if (text.endsWith('::')) {
      text = text.substring(0, text.length - 2).trim();
    }
    
    return text;
  }

  String get _displayText {
    final displayTag = widget.tag.length > 40
        ? '${widget.tag.substring(0, 40)}...'
        : widget.tag;
    if (_translation?.isNotEmpty == true) {
      return '$displayTag ($_translation)';
    }
    return displayTag;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bgColor = _isHovered
        ? colorScheme.primary.withOpacity(0.15)
        : colorScheme.surfaceContainerHighest;
    final borderColor = _isHovered
        ? colorScheme.primary.withOpacity(0.3)
        : colorScheme.outline.withOpacity(0.15);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            _displayText,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: widget.contentColor ?? colorScheme.onSurface,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// 角色提示词卡片组件
class CharacterPromptCard extends StatelessWidget {
  final int index;
  final String prompt;
  final String? negativePrompt;
  final String? position;
  final VoidCallback? onCopy;

  const CharacterPromptCard({
    super.key,
    required this.index,
    required this.prompt,
    this.negativePrompt,
    this.position,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, colorScheme, theme),
          const SizedBox(height: 8),
          SelectableText(
            prompt,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
          if (negativePrompt?.isNotEmpty == true) _buildNegativePrompt(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '角色 ${index + 1}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (position?.isNotEmpty == true) ...[
          const SizedBox(width: 8),
          Icon(Icons.location_on_outlined, size: 12, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(
            position!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const Spacer(),
        IconButton(
          onPressed: () {
            final textToCopy = negativePrompt?.isNotEmpty == true
                ? '正向: $prompt\n负向: $negativePrompt'
                : prompt;
            Clipboard.setData(ClipboardData(text: textToCopy));
            AppToast.success(context, '角色提示词已复制');
            onCopy?.call();
          },
          icon: Icon(Icons.copy, size: 16, color: colorScheme.onSurfaceVariant),
          tooltip: '复制角色提示词',
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(4),
            minimumSize: const Size(24, 24),
          ),
        ),
      ],
    );
  }

  Widget _buildNegativePrompt(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Divider(color: colorScheme.outline.withOpacity(0.2), height: 1),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.block_outlined, size: 12, color: colorScheme.error.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              '负向:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.error.withOpacity(0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SelectableText(
          negativePrompt!,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            height: 1.5,
            color: colorScheme.error.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

/// 角色提示词分组组件
class CharacterPromptSection extends StatelessWidget {
  final String title;
  final List<({String prompt, String? negativePrompt, String? position})> characters;
  final bool initiallyExpanded;

  const CharacterPromptSection({
    super.key,
    required this.title,
    required this.characters,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return PromptSection(
      title: title,
      icon: Icons.people_outline,
      content: characters.map((c) => c.prompt).join(', '),
      initiallyExpanded: initiallyExpanded,
    );
  }
}
