import 'dart:collection';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/model_capabilities.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/decoded_memory_image.dart';
import '../../../widgets/common/editable_double_field.dart';
import '../../../providers/generation/generation_params_notifier.dart';
import '../../../widgets/common/hover_image_preview.dart';
import '../handlers/vibe_import_handler.dart';

const double _disabledVibeCardOpacity = 0.48;

/// Vibe 卡片组件
///
/// 显示单个 Vibe Reference 的信息，包括：
/// - 缩略图（带悬浮预览）
/// - 编码状态标签
/// - Reference Strength 滑条
/// - Information Extracted 滑条
/// - 删除按钮
class VibeCard extends ConsumerStatefulWidget {
  final int index;
  final VibeReference vibe;
  final VoidCallback onRemove;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onInfoExtractedChanged;
  final ValueChanged<bool>? onEnabledChanged;

  /// 编码 Vibe 的回调，返回编码后的字符串或 null
  final Future<String?> Function(
    Uint8List imageData, {
    required double informationExtracted,
    required String vibeName,
  })?
  onEncode;

  /// 更新 Vibe 编码的回调
  final void Function(int index, {required String vibeEncoding})?
  onUpdateEncoding;

  const VibeCard({
    super.key,
    required this.index,
    required this.vibe,
    required this.onRemove,
    required this.onStrengthChanged,
    required this.onInfoExtractedChanged,
    this.onEnabledChanged,
    this.onEncode,
    this.onUpdateEncoding,
  });

  @override
  ConsumerState<VibeCard> createState() => _VibeCardState();
}

class _VibeCardState extends ConsumerState<VibeCard> {
  bool _isEncoding = false;

  // 跟踪已经显示过编码对话框的 vibe（使用缩略图哈希作为 ID）
  // 使用 LinkedHashSet 保持插入顺序，便于实现 LRU 淘汰
  static final LinkedHashSet<String> _shownDialogs = LinkedHashSet<String>();

  /// 把当前这一条 Vibe 保存到 Vibe 库（复用已有的命名/查重流程）
  Future<void> _saveToLibrary() async {
    final handler = VibeImportHandler(ref: ref, context: context);
    await handler.saveToLibrary([widget.vibe]);
  }

  @override
  void initState() {
    super.initState();
    // 如果是新添加的未编码原始图片，自动显示编码对话框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowEncodingDialog();
    });
  }

  void _checkAndShowEncodingDialog() {
    final vibe = widget.vibe;
    final needsEncoding =
        vibe.canReencodeFromRawSource && vibe.vibeEncoding.isEmpty;

    if (needsEncoding) {
      // 生成唯一 ID（基于图片数据哈希）
      final vibeId = _calculateVibeId(vibe);

      // 确保只显示一次（限制 Set 大小防止内存泄漏）
      if (!_shownDialogs.contains(vibeId)) {
        // LRU 淘汰：如果超过 100 条，移除最旧的
        if (_shownDialogs.length >= 100) {
          _shownDialogs.remove(_shownDialogs.first);
        }
        _shownDialogs.add(vibeId);
        _showEncodingDialog();
      }
    }
  }

  String _calculateVibeId(VibeReference vibe) {
    if (vibe.rawImageData != null) {
      return sha256.convert(vibe.rawImageData!).toString();
    }
    return vibe.displayName + DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = widget.vibe;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: AnimatedOpacity(
        key: ValueKey('vibe-card-enabled-opacity-${widget.index}'),
        opacity: vibe.enabled ? 1.0 : _disabledVibeCardOpacity,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧：缩略图 + Bundle 标签
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThumbnail(theme),
                const SizedBox(height: 6),
                // Bundle 来源标识移到缩略图下方，宽度与缩略图一致
                if (vibe.bundleSource != null)
                  _buildBundleSourceChip(context, theme),
              ],
            ),
            const SizedBox(width: 12),

            // 右侧：滑条和源类型
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部行：编码状态标签 + 删除按钮
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 编码状态标签
                      _buildEncodingStatusChip(context, theme),
                      const Spacer(),
                      _buildEnabledSwitch(context),
                      const SizedBox(width: 4),
                      // 保存到库按钮（右上角）
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          key: Key('vibe-card-save-to-library-${widget.index}'),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.bookmark_add_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: _saveToLibrary,
                          tooltip: context.l10n.vibeLibrary_save,
                        ),
                      ),
                      // 删除按钮（右上角）
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: widget.onRemove,
                          tooltip: context.l10n.vibe_remove,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Reference Strength 滑条
                  _buildSliderRow(
                    context,
                    theme,
                    label: context.l10n.vibe_referenceStrength,
                    value: vibe.strength,
                    onChanged: widget.onStrengthChanged,
                  ),

                  if (vibe.canReencodeFromRawSource) ...[
                    const SizedBox(height: 8),
                    // Information Extracted 滑条
                    _buildSliderRow(
                      context,
                      theme,
                      label: context.l10n.vibe_infoExtraction,
                      value: vibe.infoExtracted,
                      onChanged: widget.onInfoExtractedChanged,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnabledSwitch(BuildContext context) {
    final vibe = widget.vibe;
    return Tooltip(
      message: vibe.enabled
          ? context.l10n.reference_disable
          : context.l10n.reference_enable,
      child: Transform.scale(
        scale: 0.78,
        child: Switch(
          key: ValueKey('vibe-enabled-switch-${widget.index}'),
          value: vibe.enabled,
          onChanged: widget.onEnabledChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    final thumbnailBytes = widget.vibe.thumbnail ?? widget.vibe.rawImageData;

    // 悬浮预览使用原始图片数据或缩略图
    final previewBytes = widget.vibe.rawImageData ?? widget.vibe.thumbnail;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 100,
        height: 100,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: thumbnailBytes != null
              ? (previewBytes != null
                    ? HoverImagePreview(
                        imageBytes: previewBytes,
                        child: DecodedMemoryImage(
                          bytes: thumbnailBytes,
                          fit: BoxFit.cover,
                          maxLogicalWidth: 100,
                          maxLogicalHeight: 100,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder(theme);
                          },
                        ),
                      )
                    : DecodedMemoryImage(
                        bytes: thumbnailBytes,
                        fit: BoxFit.cover,
                        maxLogicalWidth: 100,
                        maxLogicalHeight: 100,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholder(theme);
                        },
                      ))
              : _buildPlaceholder(theme),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.auto_awesome,
        size: 24,
        color: theme.colorScheme.outline,
      ),
    );
  }

  /// 构建编码状态标签
  ///
  /// 编码是绑模型的：同一张图在不同模型下是两份编码。所以这里跟着计费口径
  /// （`needsEncodingForModel`）走当前模型，而不是只看有没有编码数据，
  /// 否则会出现"卡片显示已编码、生成按钮却报 2 Anlas"的矛盾。
  Widget _buildEncodingStatusChip(BuildContext context, ThemeData theme) {
    final model = ref.watch(
      generationParamsNotifierProvider.select((params) => params.model),
    );
    final supportsEncoding = ModelCapabilityRegistry.of(
      model,
    ).supportsEncodedVibeTransfer;
    final isEncoded = widget.vibe.vibeEncoding.isNotEmpty;
    final needsEncoding =
        supportsEncoding && widget.vibe.needsEncodingForModel(model);
    final l10n = context.l10n;

    if (!supportsEncoding && !widget.vibe.canReencodeFromRawSource) {
      return _buildStatusChip(
        theme: theme,
        icon: Icons.broken_image_outlined,
        text: l10n.vibe_statusSourceImageRequired,
        color: theme.colorScheme.error,
        maxWidth: 130,
      );
    } else if (supportsEncoding && isEncoded && !needsEncoding) {
      // 已编码状态（编码与当前模型匹配）
      return _buildStatusChip(
        theme: theme,
        icon: Icons.check_circle,
        text: l10n.vibe_statusEncoded,
        color: Colors.green,
        maxWidth: 80,
      );
    } else if (needsEncoding) {
      // 需要编码状态 - 可点击按钮
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isEncoding ? null : _showEncodingDialog,
          borderRadius: BorderRadius.circular(4),
          child: _buildStatusChip(
            theme: theme,
            icon: _isEncoding ? null : Icons.pending,
            customWidget: _isEncoding
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  )
                : null,
            text: _isEncoding
                ? l10n.vibe_statusEncoding
                : (isEncoded
                      ? l10n.vibe_statusNeedsReencode
                      : l10n.vibe_statusPendingEncode),
            color: Colors.orange,
            maxWidth: 130,
          ),
        ),
      );
    } else {
      // 预编码文件状态
      return _buildStatusChip(
        theme: theme,
        icon: Icons.file_present,
        text: context.vibeSourceTypeLabel(widget.vibe.sourceType),
        color: Colors.blue,
        maxWidth: 80,
      );
    }
  }

  /// 构建状态标签
  Widget _buildStatusChip({
    required ThemeData theme,
    IconData? icon,
    Widget? customWidget,
    required String text,
    required Color color,
    required double maxWidth,
  }) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customWidget != null)
            customWidget
          else if (icon != null)
            Icon(icon, size: 12, color: color),
          if (icon != null || customWidget != null) const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示编码确认对话框
  Future<void> _showEncodingDialog() async {
    final context = this.context;
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.vibe_encodeDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.vibe_encodeDialogMessage),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.vibe_encodeCostWarning,
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.vibe_encodeButton),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _encodeVibe();
    }
  }

  /// 执行编码
  Future<void> _encodeVibe() async {
    if (_isEncoding ||
        widget.vibe.rawImageData == null ||
        widget.onEncode == null ||
        widget.onUpdateEncoding == null) {
      return;
    }

    setState(() => _isEncoding = true);

    try {
      // 调用编码回调
      final encoding = await widget.onEncode!(
        widget.vibe.rawImageData!,
        informationExtracted: widget.vibe.infoExtracted,
        vibeName: widget.vibe.displayName,
      );

      if (encoding != null && mounted) {
        // 更新 vibe 编码状态
        widget.onUpdateEncoding!(widget.index, vibeEncoding: encoding);
        AppToast.success(context, context.l10n.vibe_encodeSuccess);
      } else if (mounted) {
        AppToast.error(context, context.l10n.vibe_encodeFailed);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.vibe_encodeError(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isEncoding = false);
      }
    }
  }

  /// 构建 Bundle 来源标识
  Widget _buildBundleSourceChip(BuildContext context, ThemeData theme) {
    final source = widget.vibe.bundleSource;
    if (source == null) return const SizedBox.shrink();

    // 宽度与缩略图一致 100px
    return SizedBox(
      width: 100,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_zip,
              size: 12,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                source,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final isInfoExtracted = label == context.l10n.vibe_infoExtraction;
    final double? fieldMin = isInfoExtracted
        ? VibeReference.minInfoExtracted
        : null;
    final double? fieldMax = isInfoExtracted
        ? VibeReference.maxInfoExtracted
        : null;
    final sliderMin = isInfoExtracted
        ? VibeReference.minInfoExtracted
        : VibeReference.minSliderStrength;
    final sliderMax = isInfoExtracted
        ? VibeReference.maxInfoExtracted
        : VibeReference.maxSliderStrength;
    final sliderValue = value.clamp(sliderMin, sliderMax).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签 + 数值
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            EditableDoubleField(
              value: value,
              min: fieldMin,
              max: fieldMax,
              decimals: 2,
              width: 60,
              onChanged: onChanged,
              textStyle: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        // 滑条
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: sliderValue,
            min: sliderMin,
            max: sliderMax,
            divisions: 99,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
