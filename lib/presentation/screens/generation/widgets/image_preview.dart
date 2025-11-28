import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/app_toast.dart';
import 'upscale_dialog.dart';

/// 图像预览组件
class ImagePreviewWidget extends ConsumerWidget {
  const ImagePreviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(imageGenerationNotifierProvider);
    final theme = Theme.of(context);

    // 使用 GestureDetector 吸收整个区域的点击事件，避免 Windows 系统提示音
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // 空回调，仅吸收点击
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: _buildContent(context, ref, state, theme),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ImageGenerationState state,
    ThemeData theme,
  ) {
    // 生成中状态
    if (state.isGenerating) {
      return _buildGeneratingState(theme, state.progress);
    }

    // 错误状态
    if (state.status == GenerationStatus.error) {
      return _buildErrorState(theme, state.errorMessage);
    }

    // 有图像
    if (state.hasImages) {
      return _buildImageView(context, ref, state.currentImages.first, theme);
    }

    // 空状态
    return _buildEmptyState(theme);
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_outlined,
          size: 80,
          color: theme.colorScheme.onSurface.withOpacity(0.2),
        ),
        const SizedBox(height: 16),
        Text(
          '输入提示词并点击生成',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '图像将在这里显示',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratingState(ThemeData theme, double progress) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            value: progress > 0 ? progress : null,
            strokeWidth: 6,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '生成中...',
          style: theme.textTheme.titleMedium,
        ),
        if (progress > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}%',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, String? message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          '生成失败',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageView(
    BuildContext context,
    WidgetRef ref,
    Uint8List imageBytes,
    ThemeData theme,
  ) {
    return Column(
      children: [
        // 图像显示
        Expanded(
          child: GestureDetector(
            onTap: () => _showFullscreenImage(context, imageBytes),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),

        // 操作按钮
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            // 保存按钮
            FilledButton.icon(
              onPressed: () => _saveImage(context, imageBytes),
              icon: const Icon(Icons.save_alt, size: 20),
              label: const Text('保存'),
            ),
            // 分享按钮
            OutlinedButton.icon(
              onPressed: () => _shareImage(context, imageBytes),
              icon: const Icon(Icons.share, size: 20),
              label: const Text('分享'),
            ),
            // 放大按钮
            OutlinedButton.icon(
              onPressed: () => UpscaleDialog.show(context, image: imageBytes),
              icon: const Icon(Icons.zoom_out_map, size: 20),
              label: const Text('放大'),
            ),
          ],
        ),
      ],
    );
  }

  /// 获取保存目录
  Future<Directory> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      // Android: 保存到外部存储的 Pictures/NAI_Launcher 目录
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // 尝试保存到 Pictures 目录
        final picturesPath = externalDir.path.replaceFirst(
          RegExp(r'/Android/data/[^/]+/files'),
          '/Pictures/NAI_Launcher',
        );
        final picturesDir = Directory(picturesPath);
        if (!await picturesDir.exists()) {
          await picturesDir.create(recursive: true);
        }
        return picturesDir;
      }
    }

    // 其他平台或备用: 使用文档目录
    final docDir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${docDir.path}/NAI_Launcher');
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }
    return saveDir;
  }

  /// 保存图片到文件
  Future<void> _saveImage(BuildContext context, Uint8List imageBytes) async {
    try {
      final saveDir = await _getSaveDirectory();
      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      if (context.mounted) {
        AppToast.success(context, '图片已保存到: ${saveDir.path}');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '保存失败: $e');
      }
    }
  }

  /// 分享文件
  Future<void> _shareFile(BuildContext context, File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Generated by NAI Launcher',
      );
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '分享失败: $e');
      }
    }
  }

  /// 分享图片
  Future<void> _shareImage(BuildContext context, Uint8List imageBytes) async {
    try {
      // 保存到临时目录
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/NAI_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);

      // 分享
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Generated by NAI Launcher',
      );
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '分享失败: $e');
      }
    }
  }

  void _showFullscreenImage(BuildContext context, Uint8List imageBytes) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenImageView(imageBytes: imageBytes);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }
}

/// 沉浸式全屏图像查看器
class _FullscreenImageView extends StatefulWidget {
  final Uint8List imageBytes;

  const _FullscreenImageView({required this.imageBytes});

  @override
  State<_FullscreenImageView> createState() => _FullscreenImageViewState();
}

class _FullscreenImageViewState extends State<_FullscreenImageView> {
  final TransformationController _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景 + 图像（点击关闭）
          GestureDetector(
            onTap: _close,
            child: Container(
              color: Colors.black.withOpacity(0.95),
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          
          // 左上角返回按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: _buildControlButton(
              icon: Icons.arrow_back_rounded,
              onTap: _close,
              tooltip: '返回',
            ),
          ),
          
          // 右上角保存按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: _buildControlButton(
              icon: Icons.save_alt_rounded,
              onTap: () => _saveImage(context),
              tooltip: '保存',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Future<Directory> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final picturesPath = externalDir.path.replaceFirst(
          RegExp(r'/Android/data/[^/]+/files'),
          '/Pictures/NAI_Launcher',
        );
        final picturesDir = Directory(picturesPath);
        if (!await picturesDir.exists()) {
          await picturesDir.create(recursive: true);
        }
        return picturesDir;
      }
    }

    final docDir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${docDir.path}/NAI_Launcher');
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }
    return saveDir;
  }

  Future<void> _saveImage(BuildContext context) async {
    try {
      final saveDir = await _getSaveDirectory();
      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(widget.imageBytes);

      if (context.mounted) {
        AppToast.success(context, '图片已保存到: ${saveDir.path}');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '保存失败: $e');
      }
    }
  }
}
