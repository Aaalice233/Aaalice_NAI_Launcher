import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../data/models/vibe/vibe_reference.dart';
import '../../app_toast.dart';

/// Vibe Transfer 数据展示组件
///
/// 用于在图像详情页中展示 Vibe 数据列表
/// 支持显示缩略图、strength、infoExtracted，以及保存到 Vibe 库
class VibeSection extends StatefulWidget {
  /// 分组标题
  final String title;

  /// Vibe 数据列表
  final List<VibeReference> vibes;

  /// 是否默认展开
  final bool initiallyExpanded;

  /// 点击"保存到Vibe库"回调
  final Function(VibeReference vibe)? onSaveToLibrary;

  const VibeSection({
    super.key,
    this.title = 'Vibe Transfer',
    required this.vibes,
    this.initiallyExpanded = true,
    this.onSaveToLibrary,
  });

  @override
  State<VibeSection> createState() => _VibeSectionState();
}

class _VibeSectionState extends State<VibeSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _copyAllVibes() {
    if (widget.vibes.isEmpty) return;

    final buffer = StringBuffer();
    for (var i = 0; i < widget.vibes.length; i++) {
      final vibe = widget.vibes[i];
      buffer.writeln('Vibe ${i + 1}: ${vibe.displayName}');
      buffer.writeln('  Strength: ${(vibe.strength * 100).toStringAsFixed(0)}%');
      buffer.writeln('  Info Extracted: ${(vibe.infoExtracted * 100).toStringAsFixed(0)}%');
      buffer.writeln('  Encoding: ${vibe.vibeEncoding.substring(0, vibe.vibeEncoding.length > 50 ? 50 : vibe.vibeEncoding.length)}...');
      if (i < widget.vibes.length - 1) buffer.writeln();
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    AppToast.success(context, 'Vibe 数据已复制');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasVibes = widget.vibes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(colorScheme, theme, hasVibes),
        AnimatedCrossFade(
          firstChild: const SizedBox(height: 0),
          secondChild: Column(
            children: [
              const SizedBox(height: 10),
              _buildVibeList(colorScheme, theme),
            ],
          ),
          crossFadeState: _isExpanded && hasVibes
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, ThemeData theme, bool hasVibes) {
    return Row(
      children: [
        // 可点击的标题区域
        Expanded(
          child: GestureDetector(
            onTap: hasVibes ? () => setState(() => _isExpanded = !_isExpanded) : null,
            child: MouseRegion(
              cursor: hasVibes ? SystemMouseCursors.click : SystemMouseCursors.basic,
              child: Row(
                children: [
                  Icon(
                    Icons.style_outlined,
                    size: 16,
                    color: hasVibes ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: hasVibes ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasVibes)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.vibes.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (hasVibes)
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
        // 操作按钮
        if (hasVibes) ...[
          const SizedBox(width: 4),
          // 复制全部按钮
          IconButton(
            onPressed: _copyAllVibes,
            icon: Icon(
              Icons.copy_all,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: '复制全部 Vibe 数据',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(28, 28),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVibeList(ColorScheme colorScheme, ThemeData theme) {
    return Column(
      children: widget.vibes.asMap().entries.map((entry) {
        final index = entry.key;
        final vibe = entry.value;
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < widget.vibes.length - 1 ? 8 : 0,
          ),
          child: _VibeCard(
            index: index,
            vibe: vibe,
            onSaveToLibrary: widget.onSaveToLibrary != null
                ? () => widget.onSaveToLibrary!(vibe)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

/// Vibe 卡片组件
class _VibeCard extends StatelessWidget {
  final int index;
  final VibeReference vibe;
  final VoidCallback? onSaveToLibrary;

  const _VibeCard({
    required this.index,
    required this.vibe,
    this.onSaveToLibrary,
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
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 序号和缩略图
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#${index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildThumbnail(colorScheme),
            ],
          ),
          const SizedBox(width: 12),
          // 信息区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名称
                Text(
                  vibe.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Strength
                _buildInfoRow(
                  context,
                  icon: Icons.tune,
                  label: 'Strength',
                  value: '${(vibe.strength * 100).toStringAsFixed(0)}%',
                  valueColor: colorScheme.primary,
                ),
                const SizedBox(height: 4),
                // Info Extracted
                _buildInfoRow(
                  context,
                  icon: Icons.info_outline,
                  label: 'Info',
                  value: '${(vibe.infoExtracted * 100).toStringAsFixed(0)}%',
                  valueColor: colorScheme.tertiary,
                ),
                const SizedBox(height: 4),
                // Source Type
                _buildInfoRow(
                  context,
                  icon: Icons.source_outlined,
                  label: 'Source',
                  value: vibe.sourceType.displayLabel,
                  valueColor: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          // 操作按钮
          if (onSaveToLibrary != null)
            IconButton(
              onPressed: onSaveToLibrary,
              icon: Icon(
                Icons.save_alt,
                size: 18,
                color: colorScheme.primary,
              ),
              tooltip: '保存到 Vibe 库',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(6),
                minimumSize: const Size(32, 32),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(ColorScheme colorScheme) {
    final thumbnail = vibe.thumbnail;

    if (thumbnail != null && thumbnail.isNotEmpty) {
      // 显示缩略图
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          thumbnail,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderThumbnail(colorScheme);
          },
        ),
      );
    }

    // 尝试从 vibeEncoding 生成预览（如果它是 Base64 编码的图片）
    if (vibe.vibeEncoding.isNotEmpty && vibe.vibeEncoding.length > 100) {
      try {
        final decoded = base64Decode(vibe.vibeEncoding);
        if (decoded.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              decoded,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderThumbnail(colorScheme);
              },
            ),
          );
        }
      } catch (_) {
        // 不是有效的 base64 图片，使用占位符
      }
    }

    return _buildPlaceholderThumbnail(colorScheme);
  }

  Widget _buildPlaceholderThumbnail(ColorScheme colorScheme) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Icon(
        Icons.image_outlined,
        size: 24,
        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          '$label:',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
