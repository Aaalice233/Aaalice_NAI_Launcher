import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../widgets/common/themed_slider.dart';

/// Vibe 图片编码配置
class VibeImageEncodeConfig {
  /// Vibe 名称
  final String name;

  /// Strength 参数（0.0-1.0）
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

  const VibeImageEncodeDialog({
    super.key,
    this.thumbnail,
    this.defaultName,
  });

  /// 显示对话框的便捷方法
  static Future<VibeImageEncodeConfig?> show({
    required BuildContext context,
    required Uint8List imageBytes,
    required String fileName,
  }) {
    return showDialog<VibeImageEncodeConfig>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VibeImageEncodeDialog(
        thumbnail: imageBytes,
        defaultName: fileName,
      ),
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
      setState(() => _errorText = '名称不能为空');
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 400,
            minWidth: 320,
          ),
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
        Icon(
          Icons.image_search,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '编码图片为 Vibe',
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
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.thumbnail != null
            ? Image.memory(
                widget.thumbnail!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  AppLogger.w(
                    '缩略图加载失败: $error',
                    'VibeImageEncodeDialog',
                  );
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
        Icon(
          Icons.image,
          size: 48,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 8),
        Text(
          '图片预览',
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
        Icon(
          Icons.broken_image,
          size: 48,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 8),
        Text(
          '预览加载失败',
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
        labelText: '名称',
        hintText: '输入 Vibe 名称',
        errorText: _errorText,
        prefixIcon: const Icon(Icons.label_outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.tune,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Strength',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              _strength.toStringAsFixed(2),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ThemedSlider(
          value: _strength,
          onChanged: (value) {
            setState(() => _strength = value);
          },
          min: 0.0,
          max: 1.0,
          divisions: 20,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Text(
              '1.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
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
                'Info Extracted',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              _infoExtracted.toStringAsFixed(2),
              style: theme.textTheme.bodyMedium?.copyWith(
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
          min: 0.0,
          max: 1.0,
          divisions: 20,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Text(
              '1.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
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
              '编码将消耗 2 Anlas',
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
          child: const Text('取消'),
        ),
        const SizedBox(width: 8),
        // 开始编码按钮
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始编码'),
        ),
      ],
    );
  }
}
