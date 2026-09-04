import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/input_surface_style.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../widgets/common/adaptive_dialog_frame.dart';
import '../../../widgets/common/editable_double_field.dart';
import '../../../widgets/common/themed_slider.dart';

/// Vibe 图片编码配置
class VibeImageEncodeConfig {
  /// Vibe 名称
  final String name;

  /// Strength 参数（数值输入不设前端上下限）
  final double strength;

  /// Info Extracted 参数（0.01-1.0）
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

  /// 是否需要调用 V4+ 预编码接口。
  final bool encodeImage;
  final bool _presented;
  final ScrollController? _scrollController;

  const VibeImageEncodeDialog({
    super.key,
    this.thumbnail,
    this.defaultName,
    this.encodeImage = true,
  }) : _presented = false,
       _scrollController = null;

  const VibeImageEncodeDialog._presented({
    required this.thumbnail,
    required this.defaultName,
    required this.encodeImage,
    required ScrollController scrollController,
  }) : _presented = true,
       _scrollController = scrollController;

  /// 显示对话框的便捷方法
  static Future<VibeImageEncodeConfig?> show({
    required BuildContext context,
    required Uint8List imageBytes,
    required String fileName,
    bool encodeImage = true,
  }) {
    return AdaptivePresenter.showForm<VibeImageEncodeConfig>(
      context: context,
      barrierDismissible: false,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            Icons.image_search,
            color: Theme.of(panelContext).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              encodeImage
                  ? panelContext.l10n.vibe_encodeImageTitle
                  : panelContext.l10n.vibe_saveToLibrary_title,
              style: Theme.of(panelContext).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      width: 400,
      builder: (panelContext, scrollController) =>
          VibeImageEncodeDialog._presented(
            thumbnail: imageBytes,
            defaultName: fileName,
            encodeImage: encodeImage,
            scrollController: scrollController,
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

    final content = KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final padding = compact ? 16.0 : 24.0;
          return SingleChildScrollView(
            key: const Key('vibe-image-encode-frame'),
            controller: widget._scrollController,
            padding: EdgeInsets.all(padding),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: _buildFormContent(
              theme,
              compact: compact,
              includeHeader: !widget._presented,
            ),
          );
        },
      ),
    );

    if (widget._presented) {
      return content;
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: AdaptiveDialogFrame(
        maxWidth: 400,
        maxHeight: 720,
        reservedVerticalSpace: 0,
        horizontalMargin: 0,
        child: SafeArea(child: content),
      ),
    );
  }

  Widget _buildFormContent(
    ThemeData theme, {
    required bool compact,
    required bool includeHeader,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (includeHeader) ...[
          _buildHeader(theme),
          SizedBox(height: compact ? 16 : 24),
        ],
        _buildThumbnailPreview(theme, compact: compact),
        SizedBox(height: compact ? 16 : 24),
        _buildNameInput(theme),
        SizedBox(height: compact ? 16 : 24),
        _buildStrengthSlider(theme),
        const SizedBox(height: 16),
        _buildInfoExtractedSlider(theme),
        if (widget.encodeImage) ...[
          const SizedBox(height: 16),
          _buildAnlasHint(theme),
        ],
        SizedBox(height: compact ? 16 : 24),
        _buildFooter(theme),
      ],
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
            widget.encodeImage
                ? context.l10n.vibe_encodeImageTitle
                : context.l10n.vibe_saveToLibrary_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建缩略图预览
  Widget _buildThumbnailPreview(ThemeData theme, {required bool compact}) {
    final extent = compact ? 160.0 : 200.0;
    return Center(
      child: Container(
        width: extent,
        height: extent,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest,
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
        fillColor: inputSurfaceFillColor(theme.colorScheme),
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
    final sliderValue = _strength
        .clamp(VibeReference.minSliderStrength, VibeReference.maxSliderStrength)
        .toDouble();

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
          min: VibeReference.minSliderStrength,
          max: VibeReference.maxSliderStrength,
          divisions: 99,
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
          max: VibeReference.maxInfoExtracted,
          divisions: 99,
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
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        // 取消按钮
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_cancel),
        ),
        // 开始编码按钮
        FilledButton.icon(
          onPressed: _confirm,
          icon: Icon(
            widget.encodeImage ? Icons.play_arrow : Icons.save_outlined,
          ),
          label: Text(
            widget.encodeImage
                ? context.l10n.vibe_encodeStartButton
                : context.l10n.common_save,
          ),
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
  final ScrollController? scrollController;

  const VibeImageEncodeErrorDialog({
    super.key,
    required this.fileName,
    required this.errorMessage,
    this.scrollController,
  });

  static Future<VibeEncodeErrorAction?> show({
    required BuildContext context,
    required String fileName,
    required String errorMessage,
  }) {
    return AdaptivePresenter.showForm<VibeEncodeErrorAction>(
      context: context,
      barrierDismissible: false,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(panelContext).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              panelContext.l10n.vibe_import_encodingFailed,
              style: Theme.of(panelContext).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      width: 440,
      builder: (panelContext, scrollController) => VibeImageEncodeErrorDialog(
        fileName: fileName,
        errorMessage: errorMessage,
        scrollController: scrollController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return ListView(
      key: const Key('vibe-image-encode-error-content'),
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(l10n.vibe_encodeErrorImage(fileName)),
        const SizedBox(height: 8),
        SelectableText(
          l10n.vibe_encodeErrorMessage(errorMessage),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
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
        ),
      ],
    );
  }
}
