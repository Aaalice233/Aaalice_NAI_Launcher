import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/datasources/remote/nai_api_service.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/hover_image_preview.dart';

/// 角色参考面板组件 (Director Reference, 仅 V4+ 模型支持)
class CharacterReferencePanel extends ConsumerStatefulWidget {
  const CharacterReferencePanel({super.key});

  @override
  ConsumerState<CharacterReferencePanel> createState() =>
      _CharacterReferencePanelState();
}

class _CharacterReferencePanelState
    extends ConsumerState<CharacterReferencePanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = ref.watch(generationParamsNotifierProvider);
    final hasRefs = params.characterReferences.isNotEmpty;
    final isV4Model = params.isV4Model;

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
                    Icons.person_pin,
                    size: 20,
                    color: hasRefs
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.characterRef_title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: hasRefs ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ),
                  // V4+ 模型标识
                  if (!isV4Model)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'V4+',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  if (hasRefs) ...[
                    const SizedBox(width: 8),
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
                        '1', // 角色参考只支持1张
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
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

                  // 非 V4 模型提示
                  if (!isV4Model) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.errorContainer.withOpacity(0.3),
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

                  // 参考图（仅支持1张）
                  if (hasRefs) ...[
                    _CharacterReferenceItem(
                      index: 0,
                      reference: params.characterReferences.first,
                      onRemove: () => _removeReference(0),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 添加按钮（仅在没有参考图时显示）
                  if (!hasRefs)
                    OutlinedButton.icon(
                      onPressed: isV4Model ? _addReference : null,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.l10n.characterRef_addReference),
                    ),

                  // Style Aware 开关
                  if (hasRefs) ...[
                    const SizedBox(height: 12),
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
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
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
                  ],

                  // Fidelity 滑块
                  if (hasRefs) ...[
                    const SizedBox(height: 12),
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
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
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
                  ],

                  // 清除全部按钮
                  if (hasRefs) ...[
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
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
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
            content: Text(context.l10n.img2img_selectFailed(e.toString())),
          ),
        );
      }
    }
  }

  void _removeReference(int index) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .removeCharacterReference(index);
  }

  void _clearAllReferences() {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .clearCharacterReferences();
  }
}

/// 单个角色参考图项（简化版，仅显示图片和删除按钮）
class _CharacterReferenceItem extends StatelessWidget {
  final int index;
  final CharacterReference reference;
  final VoidCallback onRemove;

  const _CharacterReferenceItem({
    required this.index,
    required this.reference,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 预览缩略图（支持悬浮放大）
          HoverImagePreview(
            imageBytes: reference.image,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                bottomLeft: Radius.circular(7),
              ),
              child: Image.memory(
                reference.image,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
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
            icon: const Icon(Icons.close, size: 20),
            onPressed: onRemove,
            tooltip: context.l10n.characterRef_remove,
          ),
        ],
      ),
    );
  }
}
