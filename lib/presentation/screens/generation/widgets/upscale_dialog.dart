import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/image_save_settings_provider.dart';

import '../../../widgets/common/app_toast.dart';

/// 图片放大对话框
class UpscaleDialog extends ConsumerStatefulWidget {
  final Uint8List? initialImage;

  const UpscaleDialog({
    super.key,
    this.initialImage,
  });

  /// 显示放大对话框
  static Future<void> show(BuildContext context, {Uint8List? image}) {
    return showDialog(
      context: context,
      builder: (context) => UpscaleDialog(initialImage: image),
    );
  }

  @override
  ConsumerState<UpscaleDialog> createState() => _UpscaleDialogState();
}

class _UpscaleDialogState extends ConsumerState<UpscaleDialog> {
  Uint8List? _sourceImage;
  int _scale = 2;

  @override
  void initState() {
    super.initState();
    _sourceImage = widget.initialImage;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upscaleState = ref.watch(upscaleNotifierProvider);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.zoom_out_map,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.upscale_title,
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 源图像选择/显示
                    _buildSourceImageSection(theme),

                    if (_sourceImage != null) ...[
                      const SizedBox(height: 16),
                      // 放大倍数选择
                      _buildScaleSelector(theme),
                    ],

                    const SizedBox(height: 16),

                    // 放大结果
                    if (upscaleState.status == UpscaleStatus.processing)
                      _buildProcessingIndicator(theme, upscaleState)
                    else if (upscaleState.status == UpscaleStatus.completed &&
                        upscaleState.result != null)
                      _buildResultSection(theme, upscaleState.result!)
                    else if (upscaleState.status == UpscaleStatus.error)
                      _buildErrorSection(theme, upscaleState.error),
                  ],
                ),
              ),
            ),

            // 底部操作栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      ref.read(upscaleNotifierProvider.notifier).clear();
                      Navigator.of(context).pop();
                    },
                    child: Text(context.l10n.upscale_close),
                  ),
                  const SizedBox(width: 8),
                  if (_sourceImage != null &&
                      upscaleState.status != UpscaleStatus.processing)
                    FilledButton.icon(
                      onPressed: _startUpscale,
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      label: Text(context.l10n.upscale_start),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceImageSection(ThemeData theme) {
    if (_sourceImage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.upscale_sourceImage,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _sourceImage!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SmallIconButton(
                      icon: Icons.refresh,
                      onPressed: _pickImage,
                      tooltip: context.l10n.tooltip_changeImage,
                    ),
                    const SizedBox(width: 4),
                    _SmallIconButton(
                      icon: Icons.close,
                      onPressed: () => setState(() => _sourceImage = null),
                      tooltip: context.l10n.tooltip_removeImage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 40,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.upscale_clickToSelect,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScaleSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.upscale_scale,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 2,
              label: Text('2x'),
              icon: Icon(Icons.looks_two, size: 18),
            ),
            ButtonSegment(
              value: 4,
              label: Text('4x'),
              icon: Icon(Icons.looks_4, size: 18),
            ),
          ],
          selected: {_scale},
          onSelectionChanged: (selection) {
            setState(() {
              _scale = selection.first;
            });
          },
        ),
        const SizedBox(height: 8),
        Text(
          _scale == 2
              ? context.l10n.upscale_2xHint
              : context.l10n.upscale_4xHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingIndicator(ThemeData theme, UpscaleState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            context.l10n.upscale_processing,
            style: theme.textTheme.bodyMedium,
          ),
          if (state.progress > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: state.progress),
            const SizedBox(height: 4),
            Text(
              '${(state.progress * 100).toInt()}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultSection(ThemeData theme, Uint8List result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.upscale_complete,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            result,
            height: 200,
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _saveResult(result),
              icon: const Icon(Icons.save, size: 18),
              label: Text(context.l10n.upscale_save),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _shareResult(result),
              icon: const Icon(Icons.share, size: 18),
              label: Text(context.l10n.upscale_share),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorSection(ThemeData theme, String? error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error ?? context.l10n.upscale_failed,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
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
          setState(() {
            _sourceImage = bytes;
          });
          // 清除之前的结果
          ref.read(upscaleNotifierProvider.notifier).clear();
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.upscale_selectFailed(e.toString()),
        );
      }
    }
  }

  void _startUpscale() {
    if (_sourceImage == null) return;

    ref.read(upscaleNotifierProvider.notifier).upscale(
          _sourceImage!,
          scale: _scale,
        );
  }

  Future<void> _saveResult(Uint8List data) async {
    try {
      // 优先使用设置中的自定义路径
      final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
      Directory saveDir;

      if (saveSettings.hasCustomPath) {
        saveDir = Directory(saveSettings.customPath!);
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        saveDir = Directory('${docDir.path}/NAI_Launcher');
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${saveDir.path}/upscaled_$timestamp.png');
      await file.writeAsBytes(data);

      if (mounted) {
        AppToast.success(context, context.l10n.upscale_savedTo(file.path));
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.upscale_saveFailed(e.toString()));
      }
    }
  }

  Future<void> _shareResult(Uint8List data) async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/upscaled_$timestamp.png');
      await file.writeAsBytes(data);

      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.upscale_shareFailed(e.toString()));
      }
    }
  }
}

/// 小型图标按钮
class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _SmallIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
