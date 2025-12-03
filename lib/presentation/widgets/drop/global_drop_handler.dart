import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/vibe_file_parser.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/vibe/vibe_reference_v4.dart';
import '../../providers/image_generation_provider.dart';
import '../common/app_toast.dart';
import 'image_destination_dialog.dart';

/// 全局拖拽处理器
///
/// 包装整个生成界面，监听拖拽事件
/// 当用户拖拽图片到界面任意位置时，弹出选择对话框
class GlobalDropHandler extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalDropHandler({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<GlobalDropHandler> createState() => _GlobalDropHandlerState();
}

class _GlobalDropHandlerState extends ConsumerState<GlobalDropHandler> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        // 检查是否包含文件
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          if (!_isDragging) {
            setState(() => _isDragging = true);
          }
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onDropLeave: (event) {
        if (_isDragging) {
          setState(() => _isDragging = false);
        }
      },
      onPerformDrop: (event) async {
        setState(() => _isDragging = false);
        await _handleDrop(event);
      },
      child: Stack(
        children: [
          widget.child,
          // 拖拽覆盖层
          if (_isDragging) _buildDropOverlay(context),
        ],
      ),
    );
  }

  Widget _buildDropOverlay(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: theme.colorScheme.primary.withOpacity(0.1),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.drop_hint,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDrop(PerformDropEvent event) async {
    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;

      // 尝试获取文件
      if (reader.canProvide(Formats.fileUri)) {
        reader.getValue(Formats.fileUri, (uri) async {
          if (uri == null) return;

          try {
            final file = File(uri.toFilePath());
            final fileName = file.path.split(Platform.pathSeparator).last;
            final bytes = await file.readAsBytes();

            await _processDroppedFile(fileName, bytes);
          } catch (e) {
            if (kDebugMode) {
              print('Error reading dropped file: $e');
            }
            _showError(e.toString());
          }
        });
      }
      // 尝试获取图片数据
      else if (reader.canProvide(Formats.png)) {
        reader.getFile(Formats.png, (file) async {
          try {
            final bytes = await file.readAll();
            final fileName = file.fileName ?? 'dropped_image.png';

            await _processDroppedFile(fileName, bytes);
          } catch (e) {
            if (kDebugMode) {
              print('Error reading dropped image: $e');
            }
            _showError(e.toString());
          }
        });
      } else if (reader.canProvide(Formats.jpeg)) {
        reader.getFile(Formats.jpeg, (file) async {
          try {
            final bytes = await file.readAll();
            final fileName = file.fileName ?? 'dropped_image.jpg';

            await _processDroppedFile(fileName, bytes);
          } catch (e) {
            if (kDebugMode) {
              print('Error reading dropped image: $e');
            }
            _showError(e.toString());
          }
        });
      }
    }
  }

  Future<void> _processDroppedFile(String fileName, Uint8List bytes) async {
    if (!mounted) return;

    // 检查是否为支持的文件类型
    if (!VibeFileParser.isSupportedFile(fileName)) {
      _showError(context.l10n.drop_unsupportedFormat);
      return;
    }

    // 显示目标选择对话框
    final destination = await ImageDestinationDialog.show(
      context,
      imageBytes: bytes,
      fileName: fileName,
    );

    if (destination == null || !mounted) return;

    final notifier = ref.read(generationParamsNotifierProvider.notifier);

    switch (destination) {
      case ImageDestination.img2img:
        _handleImg2Img(bytes, notifier);
        break;

      case ImageDestination.vibeTransfer:
        await _handleVibeTransfer(fileName, bytes, notifier);
        break;

      case ImageDestination.characterReference:
        _handleCharacterReference(bytes, notifier);
        break;
    }
  }

  void _handleImg2Img(Uint8List bytes, GenerationParamsNotifier notifier) {
    notifier.setSourceImage(bytes);
    notifier.updateAction(ImageGenerationAction.img2img);

    if (mounted) {
      AppToast.success(context, context.l10n.drop_addedToImg2Img);
    }
  }

  Future<void> _handleVibeTransfer(
    String fileName,
    Uint8List bytes,
    GenerationParamsNotifier notifier,
  ) async {
    try {
      final currentCount = notifier.state.vibeReferencesV4.length;
      const maxCount = 16;

      // 解析文件，可能返回多个 vibe（bundle 情况）
      final vibes = await VibeFileParser.parseFile(fileName, bytes);
      final addCount = vibes.length;

      // 检查是否超出上限
      if (currentCount + addCount > maxCount) {
        if (mounted) {
          AppToast.warning(context, '风格参考已达上限 ($maxCount 张)');
        }
        return;
      }

      for (final vibe in vibes) {
        notifier.addVibeReferenceV4(vibe);
      }

      if (mounted) {
        String message;
        if (currentCount > 0) {
          // 追加模式
          message = '已追加 $addCount 个风格参考';
        } else {
          message = vibes.length == 1
              ? context.l10n.drop_addedToVibe
              : context.l10n.drop_addedMultipleToVibe(vibes.length);
        }
        AppToast.success(context, message);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing vibe file: $e');
      }
      _showError(e.toString());
    }
  }

  void _handleCharacterReference(
    Uint8List bytes,
    GenerationParamsNotifier notifier,
  ) {
    final hasExisting = notifier.state.characterReferences.isNotEmpty;

    // 角色参考只支持 1 张，如果已有则替换
    if (hasExisting) {
      notifier.clearCharacterReferences();
    }

    final characterRef = CharacterReference(image: bytes);
    notifier.addCharacterReference(characterRef);

    if (mounted) {
      AppToast.success(
        context,
        hasExisting ? '已替换角色参考' : context.l10n.drop_addedToCharacterRef,
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppToast.error(context, message);
  }
}
