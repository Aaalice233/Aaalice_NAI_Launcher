import 'package:nai_launcher/presentation/widgets/common/horizontal_action_strip.dart';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../providers/generation/generation_params_notifier.dart';
import '../../../providers/generation/generation_settings_notifiers.dart';
import '../../../providers/notification_settings_provider.dart';
import '../../../themes/core/input_surface_style.dart';
import '../../../utils/single_line_text_width.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/labeled_control_rows.dart';
import '../../../widgets/common/themed_input.dart';
import '../../../widgets/common/themed_slider.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_page_layout.dart';

/// 构建标准输入框装饰（自原队列设置迁入）
InputDecoration _buildSettingsInputDecoration(
  ThemeData theme, {
  String? labelText,
  String? hintText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    isDense: true,
    filled: true,
    fillColor: inputSurfaceFillColor(theme.colorScheme),
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    border: inputSurfaceBorder(theme.colorScheme, BorderRadius.circular(8)),
    enabledBorder: inputSurfaceBorder(
      theme.colorScheme,
      BorderRadius.circular(8),
    ),
    focusedBorder: inputSurfaceBorder(
      theme.colorScheme,
      BorderRadius.circular(8),
      focused: true,
    ),
  );
}

/// 构建标准滑条主题（自原队列设置迁入）
SliderThemeData _buildSettingsSliderTheme(BuildContext context) {
  return SliderTheme.of(context).copyWith(
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
  );
}

/// 生成设置板块
///
/// 按生成任务流组织：输入行为 → 图像输出 → 失败重试 → 完成提醒。
class GenerationSettingsSection extends ConsumerStatefulWidget {
  const GenerationSettingsSection({super.key});

  @override
  ConsumerState<GenerationSettingsSection> createState() =>
      _GenerationSettingsSectionState();
}

class _GenerationSettingsSectionState
    extends ConsumerState<GenerationSettingsSection> {
  late final TextEditingController _retryCountController;
  late final TextEditingController _retryIntervalController;

  @override
  void initState() {
    super.initState();
    _retryCountController = TextEditingController();
    _retryIntervalController = TextEditingController();
  }

  @override
  void dispose() {
    _retryCountController.dispose();
    _retryIntervalController.dispose();
    super.dispose();
  }

  void _updateRetryCount(int value) async {
    final storage = ref.read(localStorageServiceProvider);
    final clampedValue = value.clamp(1, 30);
    await storage.setSetting(StorageKeys.queueRetryCount, clampedValue);
    ref.invalidate(localStorageServiceProvider);
  }

  void _updateRetryInterval(double value) async {
    final storage = ref.read(localStorageServiceProvider);
    final clampedValue = value.clamp(0.5, 10.0);
    await storage.setSetting(StorageKeys.queueRetryInterval, clampedValue);
    ref.invalidate(localStorageServiceProvider);
  }

  Future<void> _selectCustomSound(NotificationSettingsNotifier notifier) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
      );
      final selectedPath = result?.files.single.path;
      if (selectedPath != null) {
        await notifier.setCustomSoundPath(selectedPath);
      }
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to import custom notification sound',
        error,
        stackTrace,
        'GenerationSettings',
      );
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.settings_notificationSoundImportFailed,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);
    final promptWeightScrollEnabled = ref.watch(
      promptWeightScrollSettingsProvider,
    );
    final straightAlpha = ref.watch(
      generationParamsNotifierProvider.select((params) => params.straightAlpha),
    );
    final streamPreviewEnabled = ref.watch(
      generationStreamPreviewSettingsProvider,
    );
    final storage = ref.watch(localStorageServiceProvider);
    final notificationSettings = ref.watch(
      notificationSettingsNotifierProvider,
    );
    final notificationNotifier = ref.read(
      notificationSettingsNotifierProvider.notifier,
    );

    final retryCount =
        storage.getSetting<int>(
          StorageKeys.queueRetryCount,
          defaultValue: 10,
        ) ??
        10;
    final retryInterval =
        storage.getSetting<double>(
          StorageKeys.queueRetryInterval,
          defaultValue: 1.0,
        ) ??
        1.0;

    if (_retryCountController.text != '$retryCount') {
      _retryCountController.text = '$retryCount';
    }
    if (_retryIntervalController.text != retryInterval.toStringAsFixed(1)) {
      _retryIntervalController.text = retryInterval.toStringAsFixed(1);
    }

    return SettingsPageLayout(
      title: l10n.settings_generation,
      children: [
        SettingsCard(
          title: l10n.settings_generationInputSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.casino_outlined),
                title: Text(l10n.settings_showRandomPromptTools),
                subtitle: Text(l10n.settings_showRandomPromptToolsSubtitle),
                value: showRandomTools,
                onChanged: (value) {
                  ref
                      .read(randomPromptToolsVisibilityProvider.notifier)
                      .set(value);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.mouse_outlined),
                title: Text(l10n.settings_enablePromptWeightScroll),
                subtitle: Text(l10n.settings_enablePromptWeightScrollSubtitle),
                value: promptWeightScrollEnabled,
                onChanged: (value) async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  try {
                    await ref
                        .read(promptWeightScrollSettingsProvider.notifier)
                        .set(value);
                  } catch (error) {
                    messenger?.showSnackBar(
                      SnackBar(
                        content: Text(l10n.globalSettings_saveFailed('$error')),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        SettingsCard(
          title: l10n.settings_generationOutputSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.preview_outlined),
                title: Text(l10n.settings_generationStreamPreview),
                subtitle: Text(l10n.settings_generationStreamPreviewSubtitle),
                value: streamPreviewEnabled,
                onChanged: (value) async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  try {
                    await ref
                        .read(generationStreamPreviewSettingsProvider.notifier)
                        .set(value);
                  } catch (error) {
                    messenger?.showSnackBar(
                      SnackBar(
                        content: Text(l10n.globalSettings_saveFailed('$error')),
                      ),
                    );
                  }
                },
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final selector = SegmentedButton<bool>(
                    key: const Key('settings-alpha-mode-selector'),
                    segments: [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(l10n.settings_alphaModeStraight),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(l10n.settings_alphaModePremultiplied),
                      ),
                    ],
                    selected: {straightAlpha},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      ref
                          .read(generationParamsNotifierProvider.notifier)
                          .updateStraightAlpha(selection.single);
                    },
                  );
                  final showInline =
                      constraints.maxWidth >= 680 &&
                      MediaQuery.textScalerOf(context).scale(1) <= 1.6;
                  final tile = ListTile(
                    leading: const Icon(Icons.layers_outlined),
                    title: Text(l10n.settings_alphaModeTitle),
                    subtitle: Text(
                      straightAlpha
                          ? l10n.settings_alphaModeStraightDescription
                          : l10n.settings_alphaModePremultipliedDescription,
                    ),
                    trailing: showInline ? selector : null,
                  );

                  if (showInline) {
                    return tile;
                  }
                  return Column(
                    children: [
                      tile,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: HorizontalActionStrip(child: selector),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        SettingsCard(
          title: l10n.settings_generationRetrySection,
          child: _buildRetryRows(theme, [
            _RetrySlider(
              label: l10n.settings_queueRetryCount,
              valueText: (value) =>
                  l10n.settings_queueRetryCountMax('${value.round()}'),
              value: retryCount.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              unit: l10n.unit_times,
              inputText: (value) => '${value.round()}',
              controller: _retryCountController,
              onDecrease: retryCount > 1
                  ? () => _updateRetryCount(retryCount - 1)
                  : null,
              onIncrease: retryCount < 30
                  ? () => _updateRetryCount(retryCount + 1)
                  : null,
              onSliderChanged: (value) => _updateRetryCount(value.round()),
              onSubmitted: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  _updateRetryCount(parsed);
                } else {
                  _retryCountController.text = '$retryCount';
                }
              },
            ),
            _RetrySlider(
              label: l10n.settings_queueRetryInterval,
              valueText: (value) => l10n.settings_queueRetryIntervalValue(
                value.toStringAsFixed(1),
              ),
              value: retryInterval,
              min: 0.5,
              max: 10.0,
              divisions: 19,
              unit: l10n.unit_seconds,
              inputText: (value) => value.toStringAsFixed(1),
              controller: _retryIntervalController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onDecrease: retryInterval > 0.5
                  ? () => _updateRetryInterval(retryInterval - 0.5)
                  : null,
              onIncrease: retryInterval < 10.0
                  ? () => _updateRetryInterval(retryInterval + 0.5)
                  : null,
              onSliderChanged: (value) =>
                  _updateRetryInterval((value * 2).round() / 2),
              onSubmitted: (value) {
                final parsed = double.tryParse(value);
                if (parsed != null) {
                  _updateRetryInterval(parsed);
                } else {
                  _retryIntervalController.text = retryInterval.toStringAsFixed(
                    1,
                  );
                }
              },
            ),
          ]),
        ),
        SettingsCard(
          title: l10n.settings_generationFeedbackSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: Text(l10n.settings_notificationSound),
                subtitle: Text(l10n.settings_notificationSoundSubtitle),
                value: notificationSettings.soundEnabled,
                onChanged: (value) =>
                    notificationNotifier.setSoundEnabled(value),
              ),
              if (notificationSettings.soundEnabled)
                ListTile(
                  leading: const Icon(Icons.audiotrack_outlined),
                  title: Text(l10n.settings_notificationCustomSound),
                  subtitle: Text(
                    notificationSettings.customSoundPath != null
                        ? Uri.file(
                            notificationSettings.customSoundPath!,
                          ).pathSegments.last
                        : l10n.settings_notificationSelectSound,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (notificationSettings.customSoundPath != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: l10n.settings_notificationResetSound,
                          onPressed: () =>
                              notificationNotifier.setCustomSoundPath(null),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _selectCustomSound(notificationNotifier),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRetryRows(ThemeData theme, List<_RetrySlider> sliders) {
    final descriptionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.outline,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    const unitGap = 8.0;
    // 内容区左右内边距、输入框容器两侧 1px 描边、光标 2px 宽度与其后 1px
    final inputChrome =
        _buildSettingsInputDecoration(theme).contentPadding!.horizontal + 5;
    double widest(Iterable<String> texts, TextStyle? style) => texts.fold(
      0.0,
      (width, text) =>
          math.max(width, singleLineTextWidth(context, text, style)),
    );
    final inputWidth = math.max(
      64.0,
      widest([
            for (final slider in sliders) ...[
              slider.inputText(slider.min),
              slider.inputText(slider.max),
            ],
          ], theme.textTheme.bodyLarge) +
          inputChrome,
    );

    return LabeledControlRows(
      descriptionStyle: descriptionStyle,
      // 读数随拖动变化，按区间两端定宽，滑块不会跟着挪动
      minLabelWidth: widest([
        for (final slider in sliders) ...[
          slider.valueText(slider.min),
          slider.valueText(slider.max),
        ],
      ], descriptionStyle),
      trailingWidth:
          inputWidth + unitGap + widest(sliders.map((s) => s.unit), null),
      rowPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // 两个增减按钮之外还要留出可拖动的轨道
      minControlWidth: 200,
      columnGap: 8,
      rows: [
        for (final slider in sliders)
          _buildRetryRow(
            theme,
            slider,
            inputWidth: inputWidth,
            unitGap: unitGap,
          ),
      ],
    );
  }

  LabeledControlRow _buildRetryRow(
    ThemeData theme,
    _RetrySlider slider, {
    required double inputWidth,
    required double unitGap,
  }) {
    final label = slider.label;
    return LabeledControlRow(
      label: label,
      description: slider.valueText(slider.value),
      control: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: context.l10n.settings_decreaseValue(label),
            visualDensity: VisualDensity.compact,
            onPressed: slider.onDecrease,
          ),
          Expanded(
            child: SliderTheme(
              data: _buildSettingsSliderTheme(context),
              child: NamedSlider(
                label: label,
                valueText: slider.valueText,
                value: slider.value,
                min: slider.min,
                max: slider.max,
                divisions: slider.divisions,
                onChanged: slider.onSliderChanged,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: context.l10n.settings_increaseValue(label),
            visualDensity: VisualDensity.compact,
            onPressed: slider.onIncrease,
          ),
        ],
      ),
      trailing: Row(
        children: [
          SizedBox(
            width: inputWidth,
            child: ThemedInput(
              controller: slider.controller,
              semanticLabel: label,
              keyboardType: slider.keyboardType,
              textAlign: TextAlign.center,
              decoration: _buildSettingsInputDecoration(theme),
              onSubmitted: slider.onSubmitted,
            ),
          ),
          SizedBox(width: unitGap),
          Flexible(child: Text(slider.unit)),
        ],
      ),
    );
  }
}

class _RetrySlider {
  const _RetrySlider({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.inputText,
    required this.controller,
    this.keyboardType = TextInputType.number,
    required this.onDecrease,
    required this.onIncrease,
    required this.onSliderChanged,
    required this.onSubmitted,
  });

  final String label;
  final String Function(double value) valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final String Function(double value) inputText;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<String> onSubmitted;
}
