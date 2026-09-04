import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/image_detail/components/selection_copy_shortcuts.dart';
import '../../widgets/common/themed_divider.dart';
import '../../widgets/common/themed_text_selection_toolbar.dart';
import 'prompt_library_entry_dialog.dart';

/// 图片目标类型
enum ImageDestination {
  /// 图生图
  img2img,

  /// 反推
  reversePrompt,

  /// Vibe Transfer
  vibeTransfer,

  /// Vibe Transfer - 复用预编码 Vibe
  vibeTransferReuse,

  /// Vibe Transfer - 作为原始图片（需要编码）
  vibeTransferRaw,

  /// 保存预编码 Vibe 到库
  saveToVibeLibrary,

  /// 角色参考
  characterReference,

  /// 提取元数据并应用到生成参数
  extractMetadata,

  /// 提取提示词加入队列
  addToQueue,
}

/// 图片目标选择对话框
///
/// 当用户拖拽图片到界面时弹出，让用户选择图片的用途
class ImageDestinationDialog extends ConsumerWidget {
  /// 图片数据
  final Uint8List imageBytes;

  /// 文件名
  final String fileName;

  /// 是否显示提取元数据选项
  final bool showExtractMetadata;

  /// 检测到的 NovelAI 图像元数据（如果有）
  final NaiImageMetadata? metadata;

  /// 图片包含元数据载荷但未能解析时的错误详情
  final String? metadataParseError;

  /// 检测到的 Vibe 元数据（如果有）
  final VibeReference? detectedVibe;

  /// 是否为 Bundle（包含多个 Vibe）
  final bool isBundle;

  /// 由自适应表单呈现器持有的主滚动控制器。
  final ScrollController? scrollController;

  const ImageDestinationDialog({
    super.key,
    required this.imageBytes,
    required this.fileName,
    this.showExtractMetadata = true,
    this.metadata,
    this.metadataParseError,
    this.detectedVibe,
    this.isBundle = false,
    this.scrollController,
  });

  /// 显示对话框
  static Future<ImageDestination?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    required String fileName,
    bool showExtractMetadata = true,
    NaiImageMetadata? metadata,
    String? metadataParseError,
    VibeReference? detectedVibe,
    bool isBundle = false,
  }) {
    return AdaptivePresenter.showForm<ImageDestination>(
      context: context,
      width: metadata == null ? 480 : 960,
      titleBuilder: (panelContext) {
        final theme = Theme.of(panelContext);
        return Row(
          children: [
            Icon(Icons.image_search_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                panelContext.l10n.drop_dialogTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
      builder: (panelContext, scrollController) => ImageDestinationDialog(
        imageBytes: imageBytes,
        fileName: fileName,
        showExtractMetadata: showExtractMetadata,
        metadata: metadata,
        metadataParseError: metadataParseError,
        detectedVibe: detectedVibe,
        isBundle: isBundle,
        scrollController: scrollController,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final promptMetadata = metadata;
    if (promptMetadata != null) {
      return _buildMetadataDialog(context, promptMetadata);
    }

    return SingleChildScrollView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 图片预览
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 200,
                      height: 200,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          if (metadataParseError != null) ...[
            _buildMetadataParseFailure(context),
            const SizedBox(height: 16),
          ],

          // 选项按钮（垂直排列）
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vibe 检测提示和选项
              if (detectedVibe != null) ...[
                _buildVibeDetectedCard(context),
                const SizedBox(height: 16),
                const ThemedDivider(height: 1),
                const SizedBox(height: 16),
              ],

              // 提取元数据选项（置顶，用主题色高亮）
              if (showExtractMetadata) ...[
                _DestinationButton(
                  icon: Icons.data_object,
                  label: context.l10n.drop_extractMetadata,
                  subtitle: context.l10n.drop_extractMetadataSubtitle,
                  isPrimary: true,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(ImageDestination.extractMetadata),
                ),
                const SizedBox(height: 12),
                Tooltip(
                  message: context.l10n.drop_addToQueueSubtitle,
                  child: _DestinationButton(
                    icon: Icons.playlist_add,
                    label: context.l10n.drop_addToQueue,
                    subtitle: context.l10n.drop_addToQueueSubtitle,
                    onTap: () =>
                        Navigator.of(context).pop(ImageDestination.addToQueue),
                  ),
                ),
                const SizedBox(height: 16),
                const ThemedDivider(height: 1),
                const SizedBox(height: 16),
              ],
              _DestinationButton(
                icon: Icons.manage_search_rounded,
                label: context.l10n.drop_reversePrompt,
                onTap: () =>
                    Navigator.of(context).pop(ImageDestination.reversePrompt),
              ),
              const SizedBox(height: 12),
              _DestinationButton(
                icon: Icons.image_outlined,
                label: context.l10n.drop_img2img,
                onTap: () =>
                    Navigator.of(context).pop(ImageDestination.img2img),
              ),
              const SizedBox(height: 12),
              // Vibe Transfer 按钮（如果没有检测到预编码 Vibe）
              if (detectedVibe == null)
                _DestinationButton(
                  icon: Icons.auto_awesome,
                  label: context.l10n.drop_vibeTransfer,
                  onTap: () =>
                      Navigator.of(context).pop(ImageDestination.vibeTransfer),
                ),
              const SizedBox(height: 12),
              _DestinationButton(
                icon: Icons.person_outline,
                label: context.l10n.drop_characterReference,
                onTap: () => Navigator.of(
                  context,
                ).pop(ImageDestination.characterReference),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataParseFailure(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.drop_metadataParseFailed,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.drop_metadataParseFailedHint,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => _showMetadataErrorDetails(context),
                  child: Text(context.l10n.drop_metadataErrorDetails),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMetadataErrorDetails(BuildContext context) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      title: context.l10n.drop_metadataErrorDetails,
      width: 600,
      builder: (panelContext, scrollController) => ListView(
        key: const ValueKey('metadata-error-details-scroll'),
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        children: [
          SelectableText(
            metadataParseError!,
            key: const ValueKey('metadata-error-details-text'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataDialog(
    BuildContext context,
    NaiImageMetadata promptMetadata,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useActionRail = constraints.maxWidth >= 600;
          if (!useActionRail) {
            return SingleChildScrollView(
              key: const ValueKey('drop-metadata-form-scroll'),
              controller: scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMetadataContent(
                    context,
                    promptMetadata,
                    scrollable: false,
                  ),
                  const SizedBox(height: 14),
                  _buildMetadataActionPanel(context),
                ],
              ),
            );
          }

          final railWidth = constraints.maxWidth >= 900 ? 220.0 : 190.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                key: const ValueKey('drop-metadata-content-pane'),
                child: _buildMetadataContent(
                  context,
                  promptMetadata,
                  controller: scrollController,
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                key: const ValueKey('drop-metadata-action-rail'),
                width: railWidth,
                child: _buildMetadataActionPanel(context, fillHeight: true),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetadataContent(
    BuildContext context,
    NaiImageMetadata promptMetadata, {
    ScrollController? controller,
    bool scrollable = true,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final placeImageBesidePrompts = constraints.maxWidth >= 720;
        final imageWidth = placeImageBesidePrompts
            ? math.min(280.0, constraints.maxWidth * 0.34)
            : math.min(240.0, constraints.maxWidth);
        final preview = _buildImagePreview(
          context,
          width: imageWidth,
          height: placeImageBesidePrompts ? 430 : 240,
        );
        final promptPanel = _PromptMetadataPanel(metadata: promptMetadata);

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MetadataSummary(metadata: promptMetadata),
            const SizedBox(height: 14),
            if (placeImageBesidePrompts)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: imageWidth, child: preview),
                  const SizedBox(width: 18),
                  Expanded(child: promptPanel),
                ],
              )
            else ...[
              Center(child: preview),
              const SizedBox(height: 16),
              promptPanel,
            ],
            if (detectedVibe != null) ...[
              const SizedBox(height: 16),
              _buildVibeDetectedCard(context),
            ],
          ],
        );
        if (!scrollable) return content;
        return SingleChildScrollView(
          controller: controller,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(right: 4),
          child: content,
        );
      },
    );
  }

  Widget _buildImagePreview(
    BuildContext context, {
    required double width,
    required double height,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.memory(
              imageBytes,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 64,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: width,
          child: Text(
            fileName,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataActionPanel(
    BuildContext context, {
    bool fillHeight = false,
  }) {
    final theme = Theme.of(context);
    final actions = _metadataDestinationActions(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          actions[index],
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(11),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.l10n.drop_actions,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 10),
          if (fillHeight)
            Expanded(child: SingleChildScrollView(child: content))
          else
            content,
        ],
      ),
    );
  }

  List<Widget> _metadataDestinationActions(BuildContext context) {
    return <Widget>[
      if (showExtractMetadata)
        _DestinationButton(
          icon: Icons.data_object,
          label: context.l10n.drop_extractMetadata,
          subtitle: context.l10n.drop_extractMetadataSubtitle,
          isPrimary: true,
          onTap: () =>
              Navigator.of(context).pop(ImageDestination.extractMetadata),
        ),
      if (showExtractMetadata)
        Tooltip(
          message: context.l10n.drop_addToQueueSubtitle,
          child: _DestinationButton(
            icon: Icons.playlist_add,
            label: context.l10n.drop_addToQueue,
            subtitle: context.l10n.drop_addToQueueSubtitle,
            onTap: () => Navigator.of(context).pop(ImageDestination.addToQueue),
          ),
        ),
      _DestinationButton(
        icon: Icons.manage_search_rounded,
        label: context.l10n.drop_reversePrompt,
        onTap: () => Navigator.of(context).pop(ImageDestination.reversePrompt),
      ),
      _DestinationButton(
        icon: Icons.image_outlined,
        label: context.l10n.drop_img2img,
        onTap: () => Navigator.of(context).pop(ImageDestination.img2img),
      ),
      if (detectedVibe == null)
        _DestinationButton(
          icon: Icons.auto_awesome,
          label: context.l10n.drop_vibeTransfer,
          onTap: () => Navigator.of(context).pop(ImageDestination.vibeTransfer),
        ),
      _DestinationButton(
        icon: Icons.person_outline,
        label: context.l10n.drop_characterReference,
        onTap: () =>
            Navigator.of(context).pop(ImageDestination.characterReference),
      ),
    ];
  }

  /// 构建 Vibe 检测卡片
  Widget _buildVibeDetectedCard(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = detectedVibe!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.1),
            Colors.orange.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✨ ${context.l10n.drop_vibeDetected}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Vibe 预览
          if (vibe.thumbnail != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 缩略图
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(vibe.thumbnail!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 参数信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vibe.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.drop_vibeStrength(
                            (vibe.strength * 100).toStringAsFixed(0),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          context.l10n.drop_vibeInfoExtracted(
                            (vibe.infoExtracted * 100).toStringAsFixed(0),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // 操作按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 复用 Vibe 按钮（默认推荐）
                _DestinationButton(
                  icon: Icons.recycling,
                  label: context.l10n.drop_reuseVibe,
                  subtitle: context.l10n.drop_reuseVibeSubtitle,
                  isPrimary: true,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(ImageDestination.vibeTransferReuse),
                ),
                const SizedBox(height: 8),
                // 作为原始图片按钮
                _DestinationButton(
                  icon: Icons.refresh,
                  label: context.l10n.drop_useAsRawImage,
                  subtitle: context.l10n.drop_useAsRawImageSubtitle,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(ImageDestination.vibeTransferRaw),
                ),
                const SizedBox(height: 8),
                // 保存到库按钮（仅当 Vibe 已编码时显示）
                _DestinationButton(
                  icon: Icons.save_outlined,
                  label: isBundle
                      ? context.l10n.drop_saveVibeBundle
                      : context.l10n.vibe_saveToLibrary_title,
                  subtitle: isBundle
                      ? context.l10n.drop_saveVibeBundleSubtitle(
                          detectedVibe?.displayName ?? '',
                        )
                      : context.l10n.drop_saveEncodedVibeSubtitle,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(ImageDestination.saveToVibeLibrary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

TextRange topLevelPromptSegmentRange(String text, int offset) {
  if (text.isEmpty) return TextRange.empty;
  final safeOffset = offset.clamp(0, text.length - 1);
  var start = 0;
  var end = text.length;
  var braceDepth = 0;
  var bracketDepth = 0;
  var parenthesisDepth = 0;

  for (var index = 0; index < text.length; index++) {
    final character = text[index];
    final isTopLevelSeparator =
        (character == ',' || character == '\n') &&
        braceDepth == 0 &&
        bracketDepth == 0 &&
        parenthesisDepth == 0;
    if (isTopLevelSeparator) {
      if (index < safeOffset) {
        start = index + 1;
      } else {
        end = index;
        break;
      }
      continue;
    }

    switch (character) {
      case '{':
        braceDepth++;
      case '}':
        if (braceDepth > 0) braceDepth--;
      case '[':
        bracketDepth++;
      case ']':
        if (bracketDepth > 0) bracketDepth--;
      case '(':
        parenthesisDepth++;
      case ')':
        if (parenthesisDepth > 0) parenthesisDepth--;
    }
  }

  while (start < end && _isPromptBoundaryWhitespace(text[start])) {
    start++;
  }
  while (end > start && _isPromptBoundaryWhitespace(text[end - 1])) {
    end--;
  }
  return TextRange(start: start, end: end);
}

bool _isPromptBoundaryWhitespace(String character) {
  return character == ' ' ||
      character == '\t' ||
      character == '\r' ||
      character == '\n';
}

class _MetadataSummary extends StatelessWidget {
  const _MetadataSummary({required this.metadata});

  final NaiImageMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facts = <String>[
      if ((metadata.source ?? metadata.effectiveModel)?.isNotEmpty ?? false)
        metadata.source ?? metadata.effectiveModel!,
      if (metadata.width != null && metadata.height != null)
        '${metadata.width} × ${metadata.height}',
      if (metadata.steps != null) 'Steps ${metadata.steps}',
      if (metadata.scale != null) 'CFG ${metadata.scale}',
      if (metadata.seed != null) 'Seed ${metadata.seed}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.verified_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.drop_metadataDetected,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: facts.map((fact) => _MetadataPill(label: fact)).toList(),
          ),
        ],
      ],
    );
  }
}

class _PromptMetadataPanel extends StatelessWidget {
  final NaiImageMetadata metadata;

  const _PromptMetadataPanel({required this.metadata});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PromptSelectionCard(
          key: const ValueKey('drop-positive-prompt-card'),
          title: context.l10n.drop_positivePrompt,
          content: metadata.prompt,
          fallbackName: context.l10n.drop_promptLibraryPositiveName,
        ),
        const SizedBox(height: 12),
        _PromptSelectionCard(
          key: const ValueKey('drop-negative-prompt-card'),
          title: context.l10n.drop_negativePrompt,
          content: metadata.displayNegativePrompt,
          fallbackName: context.l10n.drop_promptLibraryNegativeName,
        ),
        if (metadata.characterPrompts.isNotEmpty ||
            metadata.characterNegativePrompts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 4),
              title: Text(
                context.l10n.drop_characterPrompts(
                  metadata.characterPrompts.length,
                ),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                for (
                  var index = 0;
                  index <
                      math.max(
                        metadata.characterPrompts.length,
                        metadata.characterNegativePrompts.length,
                      );
                  index++
                ) ...[
                  if (index < metadata.characterPrompts.length)
                    _PromptSelectionCard(
                      key: ValueKey('drop-character-prompt-card-$index'),
                      title: context.l10n.drop_characterPositivePrompt(
                        index + 1,
                      ),
                      content: metadata.characterPrompts[index],
                      fallbackName: context.l10n.drop_characterPositivePrompt(
                        index + 1,
                      ),
                      height: 112,
                    ),
                  if (index < metadata.characterNegativePrompts.length) ...[
                    const SizedBox(height: 8),
                    _PromptSelectionCard(
                      key: ValueKey(
                        'drop-character-negative-prompt-card-$index',
                      ),
                      title: context.l10n.drop_characterNegativePrompt(
                        index + 1,
                      ),
                      content: metadata.characterNegativePrompts[index],
                      fallbackName: context.l10n.drop_characterNegativePrompt(
                        index + 1,
                      ),
                      height: 112,
                    ),
                  ],
                  if (index + 1 <
                      math.max(
                        metadata.characterPrompts.length,
                        metadata.characterNegativePrompts.length,
                      ))
                    const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetadataPill extends StatelessWidget {
  final String label;

  const _MetadataPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _PromptSelectionCard extends StatefulWidget {
  final String title;
  final String content;
  final String fallbackName;
  final double height;

  const _PromptSelectionCard({
    super.key,
    required this.title,
    required this.content,
    required this.fallbackName,
    this.height = 180,
  });

  @override
  State<_PromptSelectionCard> createState() => _PromptSelectionCardState();
}

class _PromptSelectionCardState extends State<_PromptSelectionCard> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  Duration? _lastPointerDownAt;
  Offset? _lastPointerDownPosition;
  PointerDeviceKind? _lastPointerKind;
  String _selectedText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
    _controller.addListener(_syncSelection);
  }

  @override
  void didUpdateWidget(covariant _PromptSelectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _controller.value = TextEditingValue(text: widget.content);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncSelection);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncSelection() {
    final selection = _controller.selection;
    var selectedText = '';
    if (selection.isValid && !selection.isCollapsed) {
      final start = selection.start.clamp(0, _controller.text.length);
      final end = selection.end.clamp(0, _controller.text.length);
      if (start < end) selectedText = _controller.text.substring(start, end);
    }
    _selectedText = selectedText;
  }

  void _handlePointerDown(PointerDownEvent event) {
    final supportsDoubleTap = switch (event.kind) {
      PointerDeviceKind.mouse ||
      PointerDeviceKind.trackpad ||
      PointerDeviceKind.touch ||
      PointerDeviceKind.stylus ||
      PointerDeviceKind.invertedStylus => true,
      _ => false,
    };
    if (!supportsDoubleTap || event.buttons != kPrimaryButton) return;

    final previousTime = _lastPointerDownAt;
    final previousPosition = _lastPointerDownPosition;
    final isDoubleTap =
        previousTime != null &&
        event.timeStamp - previousTime <= kDoubleTapTimeout &&
        previousPosition != null &&
        _lastPointerKind == event.kind &&
        (event.position - previousPosition).distance <= 24;
    _lastPointerDownAt = event.timeStamp;
    _lastPointerDownPosition = event.position;
    _lastPointerKind = event.kind;

    if (!isDoubleTap) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller.text.isEmpty) return;
      final selection = _controller.selection;
      if (!selection.isValid) return;
      final range = topLevelPromptSegmentRange(
        _controller.text,
        selection.baseOffset,
      );
      if (range.isValid && !range.isCollapsed) {
        _controller.selection = TextSelection(
          baseOffset: range.start,
          extentOffset: range.end,
        );
      }
    });
  }

  Future<void> _copy(String value) async {
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) AppToast.success(context, context.l10n.common_copied);
  }

  Future<void> _addToLibrary(String value) async {
    if (value.trim().isEmpty) return;
    await PromptLibraryEntryDialog.show(
      context,
      content: value,
      fallbackName: widget.fallbackName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = widget.content.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
            child: Text(
              widget.title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!hasContent)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                context.l10n.drop_promptNotRecorded,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            Container(
              height: widget.height,
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Listener(
                onPointerDown: _handlePointerDown,
                child: SelectionCopyShortcuts(
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(
                        LogicalKeyboardKey.keyL,
                        control: true,
                        shift: true,
                      ): () =>
                          _addToLibrary(_selectedText),
                      const SingleActivator(
                        LogicalKeyboardKey.keyL,
                        meta: true,
                        shift: true,
                      ): () =>
                          _addToLibrary(_selectedText),
                      const SingleActivator(LogicalKeyboardKey.escape): () {
                        if (_selectedText.isNotEmpty) {
                          final end = _controller.selection.extentOffset.clamp(
                            0,
                            _controller.text.length,
                          );
                          _controller.selection = TextSelection.collapsed(
                            offset: end,
                          );
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    },
                    child: TextField(
                      key: ValueKey('${widget.key}-text'),
                      controller: _controller,
                      focusNode: _focusNode,
                      scrollController: _scrollController,
                      readOnly: true,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      contextMenuBuilder: (context, editableTextState) {
                        final value = editableTextState.textEditingValue;
                        final selection = value.selection;
                        final selectedText =
                            selection.isValid &&
                                !selection.isCollapsed &&
                                selection.start >= 0 &&
                                selection.end <= value.text.length
                            ? selection.textInside(value.text)
                            : '';
                        final hasSelection = selectedText.trim().isNotEmpty;
                        final items = [
                          ContextMenuButtonItem(
                            label: hasSelection
                                ? context.l10n.drop_promptAddSelection
                                : context.l10n.drop_promptAddWhole,
                            onPressed: () {
                              editableTextState.hideToolbar();
                              _addToLibrary(
                                hasSelection ? selectedText : widget.content,
                              );
                            },
                          ),
                          if (!hasSelection)
                            ContextMenuButtonItem(
                              label: context.l10n.drop_promptCopy,
                              onPressed: () {
                                editableTextState.hideToolbar();
                                _copy(widget.content);
                              },
                            ),
                          ...editableTextState.contextMenuButtonItems,
                        ];
                        return buildThemedTextSelectionToolbar(
                          context,
                          anchors: editableTextState.contextMenuAnchors,
                          buttonItems: items,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 目标选项按钮
class _DestinationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isPrimary;

  const _DestinationButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isPrimary
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isPrimary
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isPrimary
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                        fontWeight: isPrimary ? FontWeight.bold : null,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isPrimary
                              ? theme.colorScheme.onPrimaryContainer.withValues(
                                  alpha: 0.7,
                                )
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isPrimary
                    ? theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.5,
                      )
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
