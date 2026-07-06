import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../widgets/common/editable_double_field.dart';
import '../../../widgets/common/themed_slider.dart';

/// Vibe 图片编码配置
class VibeImageEncodeConfig {
  /// Vibe 名称
  final String name;

  /// Strength 参数（-1.0-1.0）
  final double strength;

  /// Info Extracted 参数（0.0-1.0）
  final double infoExtracted;

  const VibeImageEncodeConfig({
    required this.name,
    required this.strength,
    required this.infoExtracted,
  });

  @override
  String toString() {
    return 'VibeImageEncodeConfig(name=$name, strength=$strength, infoExtracted=$infoExtracted)';
  }
}

/// Vibe 图片编码配置对话框
///
/// 用于在编码图片为 Vibe 时配置参数
class VibeImageEncodeDialog extends StatefulWidget {
  /// 图片缩略图数据
  final Uint8List? thumbnail;

  /// 默认名称
  final String? defaultName;

  const VibeImageEncodeDialog({super.key, this.thumbnail, this.defaultName});

  /// 显示对话框的便捷方法
  static Future<VibeImageEncodeConfig?> show({
    required BuildContext context,
    required Uint8List imageBytes,
    required String fileName,
  }) {
    return showDialog<VibeImageEncodeConfig>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          VibeImageEncodeDialog(thumbnail: imageBytes, defaultName: fileName),
    );
  }

  @override
  State<VibeImageEncodeDialog> createState() => _VibeImageEncodeDialogState();
}

class _VibeImageEncodeDialogState extends State<VibeImageEncodeDialog> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _keyboardFocusNode;
  double _strength = 0.6;
  double _infoExtracted = 0.7;
  String? _errorText;

  @override
  void initState() {
    super.initState();

    // 生成默认名称：vibe_YYYYMMDD_HHMMSS
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyyMMdd_HHmmss').format(now);
    final initialName = widget.defaultName ?? 'vibe_$formattedDate';

    _nameController = TextEditingController(text: initialName);
    _nameFocusNode = FocusNode();
    _keyboardFocusNode = FocusNode();

    // 延迟聚焦和全选，确保渲染完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });

    AppLogger.d(
      'VibeImageEncodeDialog 初始化，默认名称: $initialName',
      'VibeImageEncodeDialog',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  /// 验证名称
  bool _validateName(String name) {
    if (name.trim().isEmpty) {
      setState(() => _errorText = context.l10n.vibe_nameRequired);
      return false;
    }
    setState(() => _errorText = null);
    return true;
  }

  /// 确认编码
  void _confirm() {
    final name = _nameController.text.trim();
    if (!_validateName(name)) {
      return;
    }

    AppLogger.i(
      'Vibe 编码确认: name=$name, strength=$_strength, infoExtracted=$_infoExtracted',
      'VibeImageEncodeDialog',
    );

    Navigator.of(context).pop(
      VibeImageEncodeConfig(
        name: name,
        strength: _strength,
        infoExtracted: _infoExtracted,
      ),
    );
  }

  /// 处理键盘事件
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      _confirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, minWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                _buildHeader(theme),
                const SizedBox(height: 24),

                // 缩略图预览
                _buildThumbnailPreview(theme),
                const SizedBox(height: 24),

                // 名称输入框
                _buildNameInput(theme),
                const SizedBox(height: 24),

                // Strength 滑块
                _buildStrengthSlider(theme),
                const SizedBox(height: 16),

                // Info Extracted 滑块
                _buildInfoExtractedSlider(theme),
                const SizedBox(height: 16),

                // Anlas 提示
                _buildAnlasHint(theme),
                const SizedBox(height: 24),

                // 底部按钮
                _buildFooter(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.image_search, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.l10n.vibe_encodeImageTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建缩略图预览
  Widget _buildThumbnailPreview(ThemeData theme) {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.thumbnail != null
            ? Image.memory(
                widget.thumbnail!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  AppLogger.w('缩略图加载失败: $error', 'VibeImageEncodeDialog');
                  return _buildErrorPlaceholder(theme);
                },
              )
            : _buildPlaceholder(theme),
      ),
    );
  }

  /// 构建占位图
  Widget _buildPlaceholder(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image, size: 48, color: theme.colorScheme.outline),
        const SizedBox(height: 8),
        Text(
          context.l10n.vibe_imagePreview,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  /// 构建错误占位图
  Widget _buildErrorPlaceholder(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image, size: 48, color: theme.colorScheme.outline),
        const SizedBox(height: 8),
        Text(
          context.l10n.vibe_previewLoadFailed,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  /// 构建名称输入框
  Widget _buildNameInput(ThemeData theme) {
    return TextField(
      controller: _nameController,
      focusNode: _nameFocusNode,
      decoration: InputDecoration(
        labelText: context.l10n.vibe_saveToLibrary_nameLabel,
        hintText: context.l10n.vibe_saveToLibrary_nameHint,
        errorText: _errorText,
        prefixIcon: const Icon(Icons.label_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _confirm(),
      onChanged: (value) {
        if (_errorText != null) {
          setState(() => _errorText = null);
        }
      },
    );
  }

  /// 构建 Strength 滑块
  Widget _buildStrengthSlider(ThemeData theme) {
    final sliderValue = _strength.clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.vibe_strength,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            EditableDoubleField(
              value: _strength,
              min: VibeReference.minStrength,
              max: 1.0,
              onChanged: (value) {
                setState(() => _strength = value);
              },
              textStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ThemedSlider(
          value: sliderValue,
          onChanged: (value) {
            setState(() => _strength = value);
          },
          min: 0.0,
          max: 1.0,
          divisions: 40,
        ),
      ],
    );
  }

  /// 构建 Info Extracted 滑块
  Widget _buildInfoExtractedSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.vibe_infoExtracted,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            EditableDoubleField(
              value: _infoExtracted,
              min: VibeReference.minInfoExtracted,
              max: 1.0,
              onChanged: (value) {
                setState(() => _infoExtracted = value);
              },
              textStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ThemedSlider(
          value: _infoExtracted,
          onChanged: (value) {
            setState(() => _infoExtracted = value);
          },
          min: VibeReference.minInfoExtracted,
          max: 1.0,
          divisions: 20,
        ),
      ],
    );
  }

  /// 构建 Anlas 提示
  Widget _buildAnlasHint(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.vibe_import_encodingCost,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部按钮
  Widget _buildFooter(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 取消按钮
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_cancel),
        ),
        const SizedBox(width: 8),
        // 开始编码按钮
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.play_arrow),
          label: Text(context.l10n.vibe_encodeStartButton),
        ),
      ],
    );
  }
}

/// Vibe 图片编码中对话框
class VibeImageEncodingDialog extends StatelessWidget {
  const VibeImageEncodingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const VibeImageEncodingDialog(),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.vibe_encodeImageInProgress,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.common_pleaseWait,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 编码错误处理结果
enum VibeEncodeErrorAction { skip, retry }

/// Vibe 图片编码错误对话框
class VibeImageEncodeErrorDialog extends StatelessWidget {
  final String fileName;
  final String errorMessage;

  const VibeImageEncodeErrorDialog({
    super.key,
    required this.fileName,
    required this.errorMessage,
  });

  static Future<VibeEncodeErrorAction?> show({
    required BuildContext context,
    required String fileName,
    required String errorMessage,
  }) {
    return showDialog<VibeEncodeErrorAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VibeImageEncodeErrorDialog(
        fileName: fileName,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AlertDialog(
      icon: Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
      title: Text(l10n.vibe_import_encodingFailed),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.vibe_encodeErrorImage(fileName)),
          const SizedBox(height: 8),
          Text(
            l10n.vibe_encodeErrorMessage(errorMessage),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(VibeEncodeErrorAction.skip),
          icon: const Icon(Icons.skip_next),
          label: Text(l10n.vibe_encodeSkipImage),
        ),
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(VibeEncodeErrorAction.retry),
          icon: const Icon(Icons.refresh),
          label: Text(l10n.common_retry),
        ),
      ],
    );
  }
}
