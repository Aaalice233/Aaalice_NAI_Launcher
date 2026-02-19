import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/gallery/nai_image_metadata.dart';
import '../../app_toast.dart';
import '../../themed_divider.dart';
import '../image_detail_data.dart';

/// 元数据面板组件
///
/// 用于在全屏预览器右侧显示完整的图片元数据信息
/// 支持折叠/展开功能
class DetailMetadataPanel extends StatefulWidget {
  /// 当前显示的图片数据
  final ImageDetailData? currentImage;

  /// 是否默认展开
  final bool initialExpanded;

  /// 面板宽度
  final double expandedWidth;

  /// 折叠宽度
  final double collapsedWidth;

  const DetailMetadataPanel({
    super.key,
    this.currentImage,
    this.initialExpanded = true,
    this.expandedWidth = 320,
    this.collapsedWidth = 40,
  });

  @override
  State<DetailMetadataPanel> createState() => _DetailMetadataPanelState();
}

class _DetailMetadataPanelState extends State<DetailMetadataPanel> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _isExpanded ? widget.expandedWidth : widget.collapsedWidth,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: colorScheme.surface.withOpacity(0.92),
          // 使用 OverflowBox 允许子组件按固定宽度布局，避免动画过程中的溢出警告
          child: OverflowBox(
            maxWidth: widget.expandedWidth,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: widget.expandedWidth,
              child: _isExpanded
                  ? _buildExpandedPanel(theme)
                  : _buildCollapsedPanel(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedPanel(ThemeData theme) {
    final metadata = widget.currentImage?.metadata;
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        _PanelHeader(
          isExpanded: true,
          onToggle: _toggleExpanded,
        ),
        const ThemedDivider(height: 1),
        Expanded(
          child: widget.currentImage == null
              ? Center(
                  child: Text(
                    '无图片',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: metadata != null && metadata.hasData
                      ? _MetadataContent(
                          metadata: metadata,
                          fileInfo: widget.currentImage!.fileInfo,
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant
                                      .withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '此图片无元数据',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
        ),
        if (metadata != null && metadata.hasData) ...[
          const ThemedDivider(height: 1),
          _ActionButtons(
            metadata: metadata,
          ),
        ],
      ],
    );
  }

  Widget _buildCollapsedPanel(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: _toggleExpanded,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          alignment: Alignment.center,
          child: RotatedBox(
            quarterTurns: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chevron_left,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '元数据',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 面板标题栏
class _PanelHeader extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;

  const _PanelHeader({
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '图片详情',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              isExpanded ? Icons.chevron_right : Icons.chevron_left,
              size: 20,
            ),
            onPressed: onToggle,
            tooltip: isExpanded ? '收起' : '展开',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// 元数据内容
class _MetadataContent extends StatelessWidget {
  final NaiImageMetadata metadata;
  final FileInfo? fileInfo;

  const _MetadataContent({
    required this.metadata,
    this.fileInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 基本信息（仅在有文件信息时显示）
        if (fileInfo != null) ...[
          _InfoSection(
            title: '基本信息',
            icon: Icons.insert_drive_file_outlined,
            children: [
              _InfoRow(label: '文件名', value: fileInfo!.fileName),
              _InfoRow(
                label: '修改时间',
                value: _formatTime(context, fileInfo!.modifiedAt),
              ),
              _InfoRow(
                label: '文件大小',
                value: _formatSize(fileInfo!.size),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        // 生成参数
        _InfoSection(
          title: context.l10n.gallery_generationParams,
          icon: Icons.tune,
          children: [
            if (metadata.model != null)
              _InfoRow(label: context.l10n.gallery_metaModel, value: metadata.model!),
            if (metadata.seed != null)
              _InfoRow(label: context.l10n.gallery_metaSeed, value: metadata.seed.toString()),
            if (metadata.steps != null)
              _InfoRow(label: context.l10n.gallery_metaSteps, value: metadata.steps.toString()),
            if (metadata.scale != null)
              _InfoRow(label: context.l10n.gallery_metaCfgScale, value: metadata.scale.toString()),
            if (metadata.sampler != null)
              _InfoRow(label: context.l10n.gallery_metaSampler, value: metadata.displaySampler),
            if (metadata.sizeString.isNotEmpty)
              _InfoRow(label: context.l10n.gallery_metaResolution, value: metadata.sizeString),
            if (metadata.smea == true || metadata.smeaDyn == true)
              _InfoRow(
                label: context.l10n.gallery_metaSmea,
                value: metadata.smeaDyn == true ? 'DYN' : 'ON',
              ),
            if (metadata.noiseSchedule != null)
              _InfoRow(label: 'Noise', value: metadata.noiseSchedule!),
            if (metadata.cfgRescale != null && metadata.cfgRescale! > 0)
              _InfoRow(
                label: 'CFG Rescale',
                value: metadata.cfgRescale.toString(),
              ),
            if (metadata.qualityToggle == true)
              _InfoRow(
                label: context.l10n.qualityTags_label,
                value: context.l10n.qualityTags_naiDefault,
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Prompt
        _ExpandableSection(
          title: context.l10n.prompt_positivePrompt,
          icon: Icons.text_fields,
          content: metadata.fullPrompt.isNotEmpty ? metadata.fullPrompt : '(无)',
          initiallyExpanded: true,
        ),
        if (metadata.negativePrompt.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ExpandableSection(
            title: context.l10n.prompt_negativePrompt,
            icon: Icons.text_fields_outlined,
            content: metadata.negativePrompt,
            isNegative: true,
          ),
        ],
      ],
    );
  }

  String _formatTime(BuildContext context, DateTime time) {
    final locale =
        Localizations.localeOf(context).languageCode == 'zh' ? 'zh' : 'en';
    return '${timeago.format(time, locale: locale)} (${time.toString().substring(0, 16)})';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// 信息区块
class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 过滤掉空内容
    final validChildren = children
        .whereType<_InfoRow>()
        .where((row) => row.value.isNotEmpty)
        .toList();
    if (validChildren.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: validChildren
                .map(
                  (child) => Padding(
                    padding: EdgeInsets.only(
                      bottom: child != validChildren.last ? 8 : 0,
                    ),
                    child: child,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

/// 可展开区块（用于 Prompt）
class _ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final String content;
  final bool initiallyExpanded;
  final bool isNegative;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.content,
    this.initiallyExpanded = false,
    this.isNegative = false,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _copyContent() {
    Clipboard.setData(ClipboardData(text: widget.content));
    AppToast.success(context, '${widget.title}已复制');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 可点击的标题区域
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Icon(widget.icon, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        widget.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
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
            // 复制按钮
            const SizedBox(width: 4),
            IconButton(
              onPressed: _copyContent,
              icon: Icon(
                Icons.copy,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              tooltip: '复制${widget.title}',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(6),
                minimumSize: const Size(28, 28),
              ),
            ),
          ],
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(height: 10),
          secondChild: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isNegative
                        ? colorScheme.error.withOpacity(0.2)
                        : colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: SelectableText(
                  widget.content,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.5,
                    color: widget.isNegative
                        ? colorScheme.error.withOpacity(0.8)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

/// 底部操作按钮
class _ActionButtons extends StatelessWidget {
  final NaiImageMetadata metadata;

  const _ActionButtons({required this.metadata});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.copy,
              label: context.l10n.prompt_positivePrompt,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: metadata.fullPrompt));
                AppToast.success(context, context.l10n.gallery_promptCopied);
              },
            ),
          ),
          const SizedBox(width: 8),
          if (metadata.seed != null)
            Expanded(
              child: _ActionButton(
                icon: Icons.tag,
                label: 'Seed',
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: metadata.seed.toString()),
                  );
                  AppToast.success(context, context.l10n.gallery_seedCopied);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 操作按钮
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered
                ? colorScheme.primary.withOpacity(0.1)
                : colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered
                  ? colorScheme.primary.withOpacity(0.3)
                  : colorScheme.outline.withOpacity(0.15),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: _isHovered
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '复制${widget.label}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _isHovered
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
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
