import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../providers/generation/generation_settings_notifiers.dart';
import '../../../providers/notification_settings_provider.dart';
import '../../../widgets/common/themed_input.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_section_label.dart';

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
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: theme.colorScheme.outline.withValues(alpha: 0.3),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
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
/// 按生成任务流组织：输入行为 → 失败重试 → 完成提醒。
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
    );
    if (result != null && result.files.single.path != null) {
      await notifier.setCustomSoundPath(result.files.single.path);
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

    return SettingsCard(
      title: l10n.settings_generation,
      icon: Icons.tune_outlined,
      child: Column(
        children: [
          SettingsSectionLabel(l10n.settings_generationInputSection),
          SwitchListTile(
            secondary: const Icon(Icons.casino_outlined),
            title: Text(l10n.settings_showRandomPromptTools),
            subtitle: Text(l10n.settings_showRandomPromptToolsSubtitle),
            value: showRandomTools,
            onChanged: (value) {
              ref.read(randomPromptToolsVisibilityProvider.notifier).set(value);
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
          SettingsSectionLabel(l10n.settings_generationRetrySection),
          _buildRetrySliderRow(
            theme: theme,
            label: l10n.settings_queueRetryCount,
            valueLabel: l10n.settings_queueRetryCountMax(retryCount.toString()),
            value: retryCount.toDouble(),
            min: 1,
            max: 30,
            unit: l10n.unit_times,
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
          _buildRetrySliderRow(
            theme: theme,
            label: l10n.settings_queueRetryInterval,
            valueLabel: l10n.settings_queueRetryIntervalValue(
              retryInterval.toStringAsFixed(1),
            ),
            value: retryInterval,
            min: 0.5,
            max: 10.0,
            unit: l10n.unit_seconds,
            controller: _retryIntervalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          SettingsSectionLabel(l10n.settings_generationFeedbackSection),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(l10n.settings_notificationSound),
            subtitle: Text(l10n.settings_notificationSoundSubtitle),
            value: notificationSettings.soundEnabled,
            onChanged: (value) => notificationNotifier.setSoundEnabled(value),
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
    );
  }

  Widget _buildRetrySliderRow({
    required ThemeData theme,
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required String unit,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.number,
    VoidCallback? onDecrease,
    VoidCallback? onIncrease,
    required ValueChanged<double> onSliderChanged,
    required ValueChanged<String> onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                Text(
                  valueLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            visualDensity: VisualDensity.compact,
            onPressed: onDecrease,
          ),
          Expanded(
            child: SliderTheme(
              data: _buildSettingsSliderTheme(context),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onSliderChanged,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            visualDensity: VisualDensity.compact,
            onPressed: onIncrease,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 56,
            child: ThemedInput(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.center,
              decoration: _buildSettingsInputDecoration(theme),
              onSubmitted: onSubmitted,
            ),
          ),
          const SizedBox(width: 4),
          Text(unit),
        ],
      ),
    );
  }
}
