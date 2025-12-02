import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../data/datasources/remote/nai_api_service.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/models/vibe/vibe_reference_v4.dart';
import '../../../providers/image_generation_provider.dart';

/// 参考模式类型
enum ReferenceMode {
  vibe, // 风格迁移
  character, // 角色参考
}

/// 统一参考面板 - 合并风格迁移和角色参考（二选一）
///
/// 支持功能：
/// - V4 Vibe Transfer（16张、预编码、编码成本显示）
/// - 角色参考（1张、Style Aware、Fidelity）
/// - SegmentedButton 模式切换
/// - 切换时有数据则弹确认对话框
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
    // 使用 V4 Vibe 数据
    final hasVibes = params.vibeReferencesV4.isNotEmpty;
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
                            ? '${params.vibeReferencesV4.length}/4'
                            : '${params.characterReferences.length}/4',
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
                      context, theme, currentMode, isV4Model, hasVibes, hasCharacterRefs, params),

                  const SizedBox(height: 12),

                  // 根据模式显示对应内容
                  if (currentMode == ReferenceMode.vibe)
                    _buildVibeContentV4(context, theme, params)
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
    ImageParams params,
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
          _showSwitchConfirmDialog(
            context,
            newMode,
            params.vibeReferencesV4.length,
            true, // isFromVibe
            () {
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .clearVibeReferencesV4();
              setState(() => _manualMode = newMode);
            },
          );
        } else if (newMode == ReferenceMode.vibe && hasCharacterRefs) {
          _showSwitchConfirmDialog(
            context,
            newMode,
            params.characterReferences.length,
            false, // isFromVibe
            () {
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .clearCharacterReferences();
              setState(() => _manualMode = newMode);
            },
          );
        } else {
          // 没有数据，直接切换模式
          setState(() => _manualMode = newMode);
        }
      },
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// 显示切换确认对话框（带数量提示）
  void _showSwitchConfirmDialog(
    BuildContext context,
    ReferenceMode targetMode,
    int count,
    bool isFromVibe,
    VoidCallback onConfirm,
  ) {
    final targetName = targetMode == ReferenceMode.vibe
        ? context.l10n.vibe_title
        : context.l10n.characterRef_title;
    final sourceName = isFromVibe
        ? context.l10n.vibe_title
        : context.l10n.characterRef_title;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.unifiedRef_switchTitle),
        content: Text(
          '切换到 $targetName 将清除当前的 $count 个 $sourceName 参考图。\n此操作无法撤销。',
        ),
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

  // ==================== V4 Vibe Transfer 内容 ====================

  /// 构建 V4 风格迁移内容
  Widget _buildVibeContentV4(
    BuildContext context,
    ThemeData theme,
    ImageParams params,
  ) {
    final vibes = params.vibeReferencesV4;
    final hasVibes = vibes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 说明文字
        Text(
          context.l10n.vibe_description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),

        // Normalize 复选框
        _buildNormalizeOption(context, theme, params),
        const SizedBox(height: 12),

        // Vibe 列表
        if (hasVibes) ...[
          ...List.generate(vibes.length, (index) {
            return _VibeCardV4(
              index: index,
              vibe: vibes[index],
              onRemove: () => _removeVibeV4(index),
              onStrengthChanged: (value) => _updateVibeStrengthV4(index, value),
              onInfoExtractedChanged: (value) =>
                  _updateVibeInfoExtractedV4(index, value),
            );
          }),
          const SizedBox(height: 8),
        ],

        // 添加按钮
        if (vibes.length < 4)
          OutlinedButton.icon(
            onPressed: _addVibeV4,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.vibe_addReference),
          ),


        // 清除全部按钮
        if (hasVibes) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _clearAllVibesV4,
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

  Widget _buildNormalizeOption(
    BuildContext context,
    ThemeData theme,
    ImageParams params,
  ) {
    return Row(
      children: [
        Checkbox(
          value: params.normalizeVibeStrength,
          onChanged: (value) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .setNormalizeVibeStrength(value ?? true);
          },
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .setNormalizeVibeStrength(!params.normalizeVibeStrength);
            },
            child: Text(
              context.l10n.vibe_normalize,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }


  Future<void> _addVibeV4() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'naiv4vibe',
          'naiv4vibebundle'
        ],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final notifier = ref.read(generationParamsNotifierProvider.notifier);

        for (final file in result.files) {
          Uint8List? bytes;
          String fileName = file.name;

          if (file.bytes != null) {
            bytes = file.bytes;
          } else if (file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          }

          if (bytes != null) {
            try {
              final vibes = await VibeFileParser.parseFile(fileName, bytes);
              notifier.addVibeReferencesV4(vibes);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to parse $fileName: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.img2img_selectFailed(e.toString())),
          ),
        );
      }
    }
  }

  void _removeVibeV4(int index) {
    ref.read(generationParamsNotifierProvider.notifier).removeVibeReferenceV4(index);
  }

  void _updateVibeStrengthV4(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReferenceV4(index, strength: value);
  }

  void _updateVibeInfoExtractedV4(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReferenceV4(index, infoExtracted: value);
  }

  void _clearAllVibesV4() {
    ref.read(generationParamsNotifierProvider.notifier).clearVibeReferencesV4();
  }

  // ==================== 角色参考内容 ====================

  /// 构建角色参考内容（支持最多4张）
  Widget _buildCharacterContent(
    BuildContext context,
    ThemeData theme,
    ImageParams params,
    bool isV4Model,
  ) {
    final hasRefs = params.characterReferences.isNotEmpty;

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

        // 参考图列表（最多4张）
        if (hasRefs) ...[
          ...List.generate(params.characterReferences.length, (index) {
            return _CharacterReferenceCard(
              index: index,
              reference: params.characterReferences[index],
              onRemove: () => _removeReference(index),
              onDescriptionChanged: (value) =>
                  _updateCharacterDescription(index, value),
              onStrengthChanged: (value) =>
                  _updateCharacterStrength(index, value),
              onSecondaryStrengthChanged: (value) =>
                  _updateCharacterSecondaryStrength(index, value),
              onInfoExtractedChanged: (value) =>
                  _updateCharacterInfoExtracted(index, value),
            );
          }),
          const SizedBox(height: 8),
        ],

        // 添加按钮（最多4张）
        if (params.characterReferences.length < 4)
          OutlinedButton.icon(
            onPressed: isV4Model ? _addReference : null,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.characterRef_addReference),
          ),

        // 全局设置（有参考图时显示）
        if (hasRefs) ...[
          const SizedBox(height: 12),

          // Style Aware 开关
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.characterRef_styleAware,
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      context.l10n.characterRef_styleAwareHint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: params.characterReferenceStyleAware,
                onChanged: (value) => ref
                    .read(generationParamsNotifierProvider.notifier)
                    .setCharacterReferenceStyleAware(value),
              ),
            ],
          ),

          // Fidelity 滑块
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.l10n.characterRef_fidelity}: ${params.characterReferenceFidelity.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      context.l10n.characterRef_fidelityHint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            value: params.characterReferenceFidelity,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: (value) => ref
                .read(generationParamsNotifierProvider.notifier)
                .setCharacterReferenceFidelity(value),
          ),

          // 标准化强度开关
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.characterRef_normalizeStrength,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Switch(
                value: params.normalizeCharacterReferenceStrength,
                onChanged: (value) => ref
                    .read(generationParamsNotifierProvider.notifier)
                    .setNormalizeCharacterReferenceStrength(value),
              ),
            ],
          ),

          // 清除全部按钮
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _clearAllReferences,
            icon: const Icon(Icons.clear_all, size: 18),
            label: Text(context.l10n.characterRef_clearAll),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  void _removeReference(int index) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .removeCharacterReference(index);
  }

  void _updateCharacterDescription(int index, String value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateCharacterReference(index, description: value);
  }

  void _updateCharacterStrength(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateCharacterReference(index, strengthValue: value);
  }

  void _updateCharacterSecondaryStrength(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateCharacterReference(index, secondaryStrength: value);
  }

  void _updateCharacterInfoExtracted(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateCharacterReference(index, informationExtracted: value);
  }

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

/// V4 Vibe 卡片组件 - 官网风格
class _VibeCardV4 extends StatelessWidget {
  final int index;
  final VibeReferenceV4 vibe;
  final VoidCallback onRemove;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onInfoExtractedChanged;

  const _VibeCardV4({
    required this.index,
    required this.vibe,
    required this.onRemove,
    required this.onStrengthChanged,
    required this.onInfoExtractedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRawImage = vibe.sourceType == VibeSourceType.rawImage;

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
          // 左侧：缩略图 + 删除按钮
          Column(
            children: [
              // 缩略图
              _buildThumbnail(theme),
              const SizedBox(height: 8),
              // 删除按钮
              SizedBox(
                height: 28,
                width: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: onRemove,
                  tooltip: context.l10n.vibe_remove,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // 右侧：滑条
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reference Strength 滑条
                _buildSliderRow(
                  context,
                  theme,
                  label: context.l10n.vibe_referenceStrength,
                  value: vibe.strength,
                  onChanged: onStrengthChanged,
                ),

                // Information Extracted 滑条 (仅原始图片)
                if (isRawImage)
                  _buildSliderRow(
                    context,
                    theme,
                    label: context.l10n.vibe_infoExtraction,
                    value: vibe.infoExtracted,
                    onChanged: onInfoExtractedChanged,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 64,
        height: 64,
        color: theme.colorScheme.surfaceContainerHighest,
        child: vibe.thumbnail != null
            ? Image.memory(
                vibe.thumbnail!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder(theme);
                },
              )
            : _buildPlaceholder(theme),
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

/// 角色参考卡片组件
class _CharacterReferenceCard extends StatefulWidget {
  final int index;
  final CharacterReference reference;
  final VoidCallback onRemove;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onSecondaryStrengthChanged;
  final ValueChanged<double> onInfoExtractedChanged;

  const _CharacterReferenceCard({
    required this.index,
    required this.reference,
    required this.onRemove,
    required this.onDescriptionChanged,
    required this.onStrengthChanged,
    required this.onSecondaryStrengthChanged,
    required this.onInfoExtractedChanged,
  });

  @override
  State<_CharacterReferenceCard> createState() => _CharacterReferenceCardState();
}

class _CharacterReferenceCardState extends State<_CharacterReferenceCard> {
  bool _showSliders = false;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.reference.description);
  }

  @override
  void didUpdateWidget(_CharacterReferenceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference.description != widget.reference.description) {
      _descriptionController.text = widget.reference.description;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

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
                  widget.reference.image,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),

              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.characterRef_referenceNumber(widget.index + 1),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.characterRef_strengthInfo(
                        widget.reference.strengthValue.toStringAsFixed(2),
                        widget.reference.secondaryStrength.toStringAsFixed(2),
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
                tooltip: context.l10n.characterRef_adjustParams,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onRemove,
                tooltip: context.l10n.characterRef_remove,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 角色描述输入框
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: context.l10n.characterRef_description,
                      hintText: context.l10n.characterRef_descriptionHint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    onChanged: widget.onDescriptionChanged,
                  ),
                  const SizedBox(height: 12),

                  // 主要强度滑块
                  _buildSliderRow(
                    context,
                    theme,
                    label: context.l10n.characterRef_strengthValue,
                    value: widget.reference.strengthValue,
                    onChanged: widget.onStrengthChanged,
                  ),

                  // 次要强度滑块
                  _buildSliderRow(
                    context,
                    theme,
                    label: context.l10n.characterRef_secondaryStrength,
                    value: widget.reference.secondaryStrength,
                    onChanged: widget.onSecondaryStrengthChanged,
                  ),

                  // 信息提取滑块
                  _buildSliderRow(
                    context,
                    theme,
                    label: context.l10n.characterRef_infoExtraction,
                    value: widget.reference.informationExtracted,
                    onChanged: widget.onInfoExtractedChanged,
                  ),

                  // 说明
                  Text(
                    context.l10n.characterRef_sliderHint,
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

  Widget _buildSliderRow(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(2),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
