import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/datasources/remote/nai_api_service.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../providers/image_generation_provider.dart';

/// 参考模式类型
enum ReferenceMode {
  vibe, // 风格迁移
  character, // 角色参考
}

/// 统一参考面板 - 合并风格迁移和角色参考（二选一）
class UnifiedReferencePanel extends ConsumerStatefulWidget {
  const UnifiedReferencePanel({super.key});

  @override
  ConsumerState<UnifiedReferencePanel> createState() =>
      _UnifiedReferencePanelState();
}

class _UnifiedReferencePanelState extends ConsumerState<UnifiedReferencePanel> {
  bool _isExpanded = false;
  ReferenceMode? _manualMode; // 用户手动选择的模式

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = ref.watch(generationParamsNotifierProvider);
    final hasVibes = params.vibeReferences.isNotEmpty;
    final hasCharacterRefs = params.characterReferences.isNotEmpty;
    final hasAnyRefs = hasVibes || hasCharacterRefs;
    final isV4Model = params.isV4Model;

    // 根据数据或手动选择确定模式
    ReferenceMode currentMode;
    if (hasCharacterRefs) {
      currentMode = ReferenceMode.character;
      _manualMode = null; // 有数据时清除手动选择
    } else if (hasVibes) {
      currentMode = ReferenceMode.vibe;
      _manualMode = null;
    } else {
      // 没有数据时，使用手动选择的模式，默认 vibe
      currentMode = _manualMode ?? ReferenceMode.vibe;
    }

    // 非 V4 模型时强制使用 vibe 模式
    if (!isV4Model && currentMode == ReferenceMode.character) {
      currentMode = ReferenceMode.vibe;
      _manualMode = null;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_fix_high,
                    size: 20,
                    color: hasAnyRefs
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.unifiedRef_title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: hasAnyRefs ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ),
                  if (hasAnyRefs)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasVibes
                            ? '${params.vibeReferences.length}/4'
                            : '${params.characterReferences.length}/1', // 角色参考只能1张
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // 展开内容
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),

                  // 模式选择器 (SegmentedButton)
                  _buildModeSelector(
                      context, theme, currentMode, isV4Model, hasVibes, hasCharacterRefs),

                  const SizedBox(height: 12),

                  // 根据模式显示对应内容
                  if (currentMode == ReferenceMode.vibe)
                    _buildVibeContent(context, theme, params)
                  else
                    _buildCharacterContent(context, theme, params, isV4Model),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// 构建模式选择器
  Widget _buildModeSelector(
    BuildContext context,
    ThemeData theme,
    ReferenceMode currentMode,
    bool isV4Model,
    bool hasVibes,
    bool hasCharacterRefs,
  ) {
    return SegmentedButton<ReferenceMode>(
      segments: [
        ButtonSegment<ReferenceMode>(
          value: ReferenceMode.vibe,
          label: Text(context.l10n.vibe_title),
          icon: const Icon(Icons.auto_awesome, size: 18),
        ),
        ButtonSegment<ReferenceMode>(
          value: ReferenceMode.character,
          label: Text(context.l10n.characterRef_title),
          icon: const Icon(Icons.person_pin, size: 18),
          enabled: isV4Model,
        ),
      ],
      selected: {currentMode},
      onSelectionChanged: (Set<ReferenceMode> newSelection) {
        final newMode = newSelection.first;
        if (newMode == currentMode) return;

        // 检查是否有数据需要清除
        if (newMode == ReferenceMode.character && hasVibes) {
          _showSwitchConfirmDialog(context, newMode, () {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .clearVibeReferences();
            setState(() => _manualMode = newMode);
          });
        } else if (newMode == ReferenceMode.vibe && hasCharacterRefs) {
          _showSwitchConfirmDialog(context, newMode, () {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .clearCharacterReferences();
            setState(() => _manualMode = newMode);
          });
        } else {
          // 没有数据，直接切换模式
          setState(() => _manualMode = newMode);
        }
      },
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// 显示切换确认对话框
  void _showSwitchConfirmDialog(
    BuildContext context,
    ReferenceMode targetMode,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.unifiedRef_switchTitle),
        content: Text(context.l10n.unifiedRef_switchContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(context.l10n.common_confirm),
          ),
        ],
      ),
    );
  }

  /// 构建风格迁移内容
  Widget _buildVibeContent(
      BuildContext context, ThemeData theme, ImageParams params) {
    final hasVibes = params.vibeReferences.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 说明文字
        Text(
          context.l10n.vibe_hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),

        // 参考图列表
        if (hasVibes) ...[
          ...List.generate(params.vibeReferences.length, (index) {
            return _VibeReferenceItem(
              index: index,
              vibe: params.vibeReferences[index],
              onRemove: () => _removeVibe(index),
              onStrengthChanged: (value) => _updateVibeStrength(index, value),
              onInfoExtractedChanged: (value) =>
                  _updateVibeInfoExtracted(index, value),
            );
          }),
          const SizedBox(height: 8),
        ],

        // 添加按钮
        if (params.vibeReferences.length < 4)
          OutlinedButton.icon(
            onPressed: _addVibe,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.vibe_addReference),
          ),

        // 清除全部按钮
        if (hasVibes) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _clearAllVibes,
            icon: const Icon(Icons.clear_all, size: 18),
            label: Text(context.l10n.vibe_clearAll),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  /// 构建角色参考内容
  Widget _buildCharacterContent(
    BuildContext context,
    ThemeData theme,
    ImageParams params,
    bool isV4Model,
  ) {
    final hasRef = params.characterReferences.isNotEmpty;
    final reference = hasRef ? params.characterReferences.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 非 V4 模型提示
        if (!isV4Model) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.characterRef_v4Only,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 说明文字
        Text(
          context.l10n.characterRef_hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),

        // 参考图（只能一张）
        if (hasRef && reference != null) ...[
          // 图片预览卡片
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // 预览缩略图
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    bottomLeft: Radius.circular(7),
                  ),
                  child: Image.memory(
                    reference.image,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                // 信息
                Expanded(
                  child: Text(
                    context.l10n.characterRef_title,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                // 删除按钮
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: _clearAllReferences,
                  tooltip: context.l10n.common_delete,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Style Aware 开关
          Row(
            children: [
              Checkbox(
                value: params.characterReferenceStyleAware,
                onChanged: (value) => ref
                    .read(generationParamsNotifierProvider.notifier)
                    .setCharacterReferenceStyleAware(value ?? true),
              ),
              Expanded(
                child: Text(
                  context.l10n.characterRef_styleAware,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),

          // Fidelity 滑块
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${context.l10n.characterRef_fidelity}:',
                style: theme.textTheme.bodyMedium,
              ),
              Expanded(
                child: Slider(
                  value: params.characterReferenceFidelity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  onChanged: (value) => ref
                      .read(generationParamsNotifierProvider.notifier)
                      .setCharacterReferenceFidelity(value),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  params.characterReferenceFidelity.toStringAsFixed(2),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ] else ...[
          // 添加按钮（只能添加一张）
          OutlinedButton.icon(
            onPressed: isV4Model ? _addReference : null,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.characterRef_addReference),
          ),
        ],
      ],
    );
  }

  // ==================== Vibe Transfer 方法 ====================

  Future<void> _addVibe() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes;

        if (file.bytes != null) {
          bytes = file.bytes;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          ref
              .read(generationParamsNotifierProvider.notifier)
              .addVibeReference(VibeReference(image: bytes));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.img2img_selectFailed(e.toString()))),
        );
      }
    }
  }

  void _removeVibe(int index) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .removeVibeReference(index);
  }

  void _updateVibeStrength(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, strength: value);
  }

  void _updateVibeInfoExtracted(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, informationExtracted: value);
  }

  void _clearAllVibes() {
    ref.read(generationParamsNotifierProvider.notifier).clearVibeReferences();
  }

  // ==================== 角色参考方法 ====================

  Future<void> _addReference() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes;

        if (file.bytes != null) {
          bytes = file.bytes;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          // 上传时转换为 PNG 格式（NovelAI Director Reference 要求）
          // 这样生成时就不需要每次都转换了
          final pngBytes = NAIApiService.ensurePngFormat(bytes);
          ref
              .read(generationParamsNotifierProvider.notifier)
              .addCharacterReference(CharacterReference(image: pngBytes));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.img2img_selectFailed(e.toString()))),
        );
      }
    }
  }

  void _clearAllReferences() {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .clearCharacterReferences();
  }
}

/// 单个 Vibe 参考图项
class _VibeReferenceItem extends StatefulWidget {
  final int index;
  final VibeReference vibe;
  final VoidCallback onRemove;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onInfoExtractedChanged;

  const _VibeReferenceItem({
    required this.index,
    required this.vibe,
    required this.onRemove,
    required this.onStrengthChanged,
    required this.onInfoExtractedChanged,
  });

  @override
  State<_VibeReferenceItem> createState() => _VibeReferenceItemState();
}

class _VibeReferenceItemState extends State<_VibeReferenceItem> {
  bool _showSliders = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 图像预览和基本操作
          Row(
            children: [
              // 预览缩略图
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  bottomLeft: Radius.circular(7),
                ),
                child: Image.memory(
                  widget.vibe.image,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),

              // 信息和调整
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.vibe_referenceNumber(widget.index + 1),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.vibe_strengthInfo(
                        widget.vibe.strength.toStringAsFixed(2),
                        widget.vibe.informationExtracted.toStringAsFixed(2),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // 操作按钮
              IconButton(
                icon: Icon(
                  _showSliders ? Icons.tune : Icons.tune_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _showSliders = !_showSliders),
                tooltip: context.l10n.vibe_adjustParams,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onRemove,
                tooltip: context.l10n.vibe_remove,
              ),
            ],
          ),

          // 可展开的滑块区域
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            crossFadeState: _showSliders
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  // 强度滑块
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          context.l10n.vibe_referenceStrength,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: widget.vibe.strength,
                          min: 0.0,
                          max: 1.0,
                          divisions: 100,
                          onChanged: widget.onStrengthChanged,
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          widget.vibe.strength.toStringAsFixed(2),
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),

                  // 信息提取滑块
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          context.l10n.vibe_infoExtraction,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: widget.vibe.informationExtracted,
                          min: 0.0,
                          max: 1.0,
                          divisions: 100,
                          onChanged: widget.onInfoExtractedChanged,
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          widget.vibe.informationExtracted.toStringAsFixed(2),
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),

                  // 说明
                  Text(
                    context.l10n.vibe_sliderHint,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

