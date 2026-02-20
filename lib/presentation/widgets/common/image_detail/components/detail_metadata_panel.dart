import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/gallery/nai_image_metadata.dart';
import '../../add_to_library_dialog.dart';
import '../../app_toast.dart';
import '../../save_as_preset_dialog.dart';
import '../../themed_divider.dart';
import '../file_image_detail_data.dart';
import '../image_detail_data.dart';
import 'prompt_section.dart';
import 'vibe_section.dart';

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
  Future<NaiImageMetadata?>? _metadataFuture;
  NaiImageMetadata? _loadedMetadata;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
    _startMetadataLoading();
  }

  @override
  void didUpdateWidget(covariant DetailMetadataPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当图片变化时重新加载元数据
    if (widget.currentImage?.identifier != oldWidget.currentImage?.identifier) {
      _startMetadataLoading();
    }
  }

  /// 启动元数据加载（双通道架构）
  ///
  /// **前台高优先级通道**：
  /// - 用户主动打开详情页时触发
  /// - 立即开始解析，不受后台预加载队列影响
  /// - 从后台队列中移除重复任务（避免重复解析）
  ///
  /// **支持的数据源**：
  /// - [FileImageDetailData]: 从 PNG 文件解析（已保存的图像）
  /// - [GeneratedImageDetailData]: 从内存字节解析（未保存的图像）
  void _startMetadataLoading() {
    final image = widget.currentImage;
    if (image == null) return;

    // 1. 先检查同步可用的元数据
    final syncMetadata = image.metadata;
    if (syncMetadata != null && syncMetadata.hasData) {
      _loadedMetadata = syncMetadata;
      _metadataFuture = null;
      return;
    }

    // 2. 异步加载元数据（支持所有数据源）
    Future<NaiImageMetadata?>? future;
    if (image is FileImageDetailData) {
      future = image.getMetadataAsync();
    } else if (image is GeneratedImageDetailData) {
      future = image.getMetadataAsync();
    }

    if (future != null) {
      _metadataFuture = future.then((metadata) {
        if (mounted) {
          setState(() => _loadedMetadata = metadata);
        }
        return metadata;
      });
    } else {
      _metadataFuture = null;
      _loadedMetadata = null;
    }
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }

  /// 获取当前可用的元数据（同步或已加载的异步）
  NaiImageMetadata? get _currentMetadata => _loadedMetadata ?? widget.currentImage?.metadata;

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
    final metadata = _currentMetadata;
    final isLoading = _metadataFuture != null && _loadedMetadata == null;
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
              : isLoading
                  ? _buildLoadingState(theme)
                  : metadata != null && metadata.hasData
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _MetadataContent(
                            metadata: metadata,
                            fileInfo: widget.currentImage!.fileInfo,
                          ),
                        )
                      : _buildNoMetadataState(theme),
        ),
        // 只在有元数据时显示操作按钮
        if (metadata != null && metadata.hasData)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ThemedDivider(height: 1),
              _ActionButtons(
                metadata: metadata,
              ),
            ],
          ),
      ],
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '正在解析元数据...',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建无元数据状态
  Widget _buildNoMetadataState(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
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
        // 提示词分组展示
        _buildPromptSections(context),
      ],
    );
  }

  /// 构建提示词分组
  Widget _buildPromptSections(BuildContext context) {
    // 如果有分离的字段，使用分组展示
    if (metadata.hasSeparatedFields) {
      // 合并固定词（前缀+后缀）
      final fixedTags = [
        ...metadata.fixedPrefixTags,
        ...metadata.fixedSuffixTags,
      ];

      // 主提示词包含角色提示词
      final mainPromptWithChars = _buildMainPromptWithCharacters();
      final mainPromptTags = _extractTags(mainPromptWithChars);

      // 负面提示词标签
      final negativeTags = _extractTags(metadata.negativePrompt);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主提示词（包含角色提示词）
          PromptSection(
            title: '主提示词',
            icon: Icons.text_fields,
            content: mainPromptWithChars,
            tags: mainPromptTags,
            initiallyExpanded: true,
            showAddToLibrary: mainPromptWithChars.isNotEmpty,
            onAddToLibrary: () => _showAddToLibraryDialog(context, mainPromptWithChars),
          ),
          // 固定词（前缀+后缀合并）
          if (fixedTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            PromptSection(
              title: '固定词',
              icon: Icons.push_pin_outlined,
              content: fixedTags.join(', '),
              tags: fixedTags,
              initiallyExpanded: false,
            ),
          ],
          // 质量词
          if (metadata.qualityTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            PromptSection(
              title: '质量词',
              icon: Icons.high_quality,
              content: metadata.qualityTags.join(', '),
              tags: metadata.qualityTags,
              initiallyExpanded: false,
              showAddToLibrary: true,
              onAddToLibrary: () => _showAddToLibraryDialog(context, metadata.qualityTags.join(', ')),
            ),
          ],
          // 角色提示词详细卡片
          if (metadata.characterInfos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCharacterSection(context),
          ],
          // Vibe数据
          if (metadata.vibeReferences.isNotEmpty) ...[
            const SizedBox(height: 12),
            VibeSection(
              vibes: metadata.vibeReferences,
              initiallyExpanded: true,
              onSaveToLibrary: (vibe) => _showSaveVibeDialog(context, vibe),
            ),
          ],
          // 负向提示词（使用标签形式）
          if (metadata.negativePrompt.isNotEmpty) ...[
            const SizedBox(height: 12),
            PromptSection(
              title: context.l10n.prompt_negativePrompt,
              icon: Icons.block,
              content: metadata.negativePrompt,
              tags: negativeTags,
              initiallyExpanded: false,
              contentColor: Theme.of(context).colorScheme.error.withOpacity(0.8),
              borderColor: Theme.of(context).colorScheme.error,
            ),
          ],
        ],
      );
    }

    // 旧数据：使用简单展示
    final mainPromptTags = _extractTags(metadata.fullPrompt);
    final negativeTags = _extractTags(metadata.negativePrompt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主提示词
        PromptSection(
          title: context.l10n.prompt_positivePrompt,
          icon: Icons.text_fields,
          content: metadata.fullPrompt.isNotEmpty ? metadata.fullPrompt : '(无)',
          tags: mainPromptTags,
          initiallyExpanded: true,
          showAddToLibrary: metadata.fullPrompt.isNotEmpty,
          onAddToLibrary: () => _showAddToLibraryDialog(context, metadata.fullPrompt),
        ),
        // 负向提示词（使用标签形式）
        if (metadata.negativePrompt.isNotEmpty) ...[
          const SizedBox(height: 12),
          PromptSection(
            title: context.l10n.prompt_negativePrompt,
            icon: Icons.block,
            content: metadata.negativePrompt,
            tags: negativeTags,
            initiallyExpanded: false,
            contentColor: Theme.of(context).colorScheme.error.withOpacity(0.8),
            borderColor: Theme.of(context).colorScheme.error,
          ),
        ],
      ],
    );
  }

  /// 构建包含角色提示词的主提示词
  String _buildMainPromptWithCharacters() {
    final buffer = StringBuffer(metadata.mainPrompt);

    // 添加角色提示词到主提示词
    for (final character in metadata.characterInfos) {
      if (character.prompt.isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.write(', ');
        }
        buffer.write(character.prompt);
      }
    }

    return buffer.toString();
  }

  /// 从提示词文本提取标签列表
  List<String> _extractTags(String prompt) {
    if (prompt.isEmpty) return [];
    return prompt
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// 构建角色提示词分组（带折叠功能）
  Widget _buildCharacterSection(BuildContext context) {
    return PromptSection(
      title: '角色提示词',
      icon: Icons.people_outline,
      content: metadata.characterInfos.map((c) => c.prompt).join(', '),
      initiallyExpanded: false,
      showAddToLibrary: false,
      // 使用自定义内容展示角色卡片
      customContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: metadata.characterInfos.asMap().entries.map((entry) {
          final index = entry.key;
          final character = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < metadata.characterInfos.length - 1 ? 8 : 0,
            ),
            child: CharacterPromptCard(
              index: index,
              prompt: character.prompt,
              negativePrompt: character.negativePrompt,
              position: character.position,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 显示添加到词库对话框
  Future<void> _showAddToLibraryDialog(BuildContext context, String content) async {
    await AddToLibraryDialog.show(
      context,
      content: content,
      sourceTag: 'from_image',
    );
  }

  /// 显示保存 Vibe 对话框
  void _showSaveVibeDialog(BuildContext context, vibe) {
    // TODO: 实现保存 Vibe 对话框（需要 VibeLibraryService）
    AppToast.info(context, '保存到 Vibe 库功能即将推出');
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

/// 底部操作按钮
class _ActionButtons extends StatelessWidget {
  final NaiImageMetadata metadata;

  const _ActionButtons({required this.metadata});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：复制按钮
          Row(
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
          const SizedBox(height: 8),
          // 第二行：保存按钮
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.bookmark_add,
                  label: '保存预设',
                  onPressed: () => SaveAsPresetDialog.show(context, metadata: metadata),
                ),
              ),
            ],
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
