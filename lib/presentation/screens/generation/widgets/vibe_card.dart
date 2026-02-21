import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/hover_image_preview.dart';

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

  /// 编码 Vibe 的回调，返回编码后的字符串或 null
  final Future<String?> Function(Uint8List imageData, {
    required double informationExtracted,
    required String vibeName,
  })? onEncode;

  /// 更新 Vibe 编码的回调
  final void Function(int index, {required String vibeEncoding})? onUpdateEncoding;

  const VibeCard({
    super.key,
    required this.index,
    required this.vibe,
    required this.onRemove,
    required this.onStrengthChanged,
    required this.onInfoExtractedChanged,
    this.onEncode,
    this.onUpdateEncoding,
  });

  @override
  ConsumerState<VibeCard> createState() => _VibeCardState();
}

class _VibeCardState extends ConsumerState<VibeCard> {
  bool _isEncoding = false;

  // 跟踪已经显示过编码对话框的 vibe（使用缩略图哈希作为 ID）
  static final Set<String> _shownDialogs = {};

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
    final needsEncoding = vibe.sourceType == VibeSourceType.rawImage &&
        vibe.vibeEncoding.isEmpty &&
        vibe.rawImageData != null;

    if (needsEncoding) {
      // 生成唯一 ID（基于图片数据哈希）
      final vibeId = _calculateVibeId(vibe);

      // 确保只显示一次
      if (!_shownDialogs.contains(vibeId)) {
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

                // Information Extracted 滑条
                _buildSliderRow(
                  context,
                  theme,
                  label: context.l10n.vibe_infoExtraction,
                  value: vibe.infoExtracted,
                  onChanged: widget.onInfoExtractedChanged,
                ),
              ],
            ),
          ),
        ],
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
                      child: Image.memory(
                        thumbnailBytes,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholder(theme);
                        },
                      ),
                    )
                  : Image.memory(
                      thumbnailBytes,
                      fit: BoxFit.cover,
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
  Widget _buildEncodingStatusChip(BuildContext context, ThemeData theme) {
    final isEncoded = widget.vibe.vibeEncoding.isNotEmpty;
    final needsEncoding = widget.vibe.sourceType == VibeSourceType.rawImage;

    if (isEncoded) {
      // 已编码状态
      return Container(
        constraints: const BoxConstraints(maxWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.green.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              size: 12,
              color: Colors.green,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '已编码',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    } else if (needsEncoding) {
      // 需要编码状态 - 可点击按钮
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isEncoding ? null : _showEncodingDialog,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 100),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isEncoding)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  )
                else
                  const Icon(
                    Icons.pending,
                    size: 12,
                    color: Colors.orange,
                  ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _isEncoding ? '编码中...' : '待编码 (2 Anlas)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // 预编码文件状态
      return Container(
        constraints: const BoxConstraints(maxWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.blue.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.file_present,
              size: 12,
              color: Colors.blue,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                widget.vibe.sourceType.displayLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.blue,
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
  }

  /// 显示编码确认对话框
  Future<void> _showEncodingDialog() async {
    final context = this.context;
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认编码 Vibe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('是否编码此图片以供生成使用？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
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
                      '此操作将消耗 2 Anlas（点数）',
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
            child: const Text('编码'),
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
        AppToast.success(context, 'Vibe 编码成功！');
      } else if (mounted) {
        AppToast.error(context, 'Vibe 编码失败，请重试');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '编码失败: $e');
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
            color: theme.colorScheme.tertiary.withOpacity(0.5),
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
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: theme.textTheme.bodySmall?.copyWith(
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
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
