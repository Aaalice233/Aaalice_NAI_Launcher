import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../widgets/common/themed_input.dart';
import '../widgets/settings_card.dart';

/// 构建标准输入框装饰
InputDecoration _buildSettingsInputDecoration(ThemeData theme,
    {String? labelText, String? hintText,}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
    ),
  );
}

/// 构建标准滑条主题
SliderThemeData _buildSettingsSliderTheme(BuildContext context) {
  return SliderTheme.of(context).copyWith(
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
  );
}

/// 队列设置板块
/// 
/// 包含重试次数、重试间隔和悬浮球背景图片设置
class QueueSettingsSection extends ConsumerStatefulWidget {
  const QueueSettingsSection({super.key});

  @override
  ConsumerState<QueueSettingsSection> createState() =>
      _QueueSettingsSectionState();
}

class _QueueSettingsSectionState extends ConsumerState<QueueSettingsSection> {
  late TextEditingController _retryCountController;
  late TextEditingController _retryIntervalController;
  String? _backgroundImagePath;

  @override
  void initState() {
    super.initState();
    _retryCountController = TextEditingController();
    _retryIntervalController = TextEditingController();
    _loadBackgroundImage();
  }

  void _loadBackgroundImage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final storage = ref.read(localStorageServiceProvider);
        setState(() {
          _backgroundImagePath = storage.getFloatingButtonBackgroundImage();
        });
      }
    });
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

  /// 选择背景图片
  Future<void> _selectBackgroundImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        final storage = ref.read(localStorageServiceProvider);
        await storage.setFloatingButtonBackgroundImage(path);
        setState(() {
          _backgroundImagePath = path;
        });
        ref.invalidate(localStorageServiceProvider);
      }
    }
  }

  /// 清除背景图片
  Future<void> _clearBackgroundImage() async {
    final storage = ref.read(localStorageServiceProvider);
    await storage.setFloatingButtonBackgroundImage(null);
    setState(() {
      _backgroundImagePath = null;
    });
    ref.invalidate(localStorageServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = ref.watch(localStorageServiceProvider);
    final retryCount = storage.getSetting<int>(
          StorageKeys.queueRetryCount,
          defaultValue: 10,
        ) ??
        10;
    final retryInterval = storage.getSetting<double>(
          StorageKeys.queueRetryInterval,
          defaultValue: 1.0,
        ) ??
        1.0;

    // 同步输入框文本（仅当未聚焦时更新，避免编辑中被覆盖）
    if (_retryCountController.text != '$retryCount') {
      _retryCountController.text = '$retryCount';
    }
    if (_retryIntervalController.text != retryInterval.toStringAsFixed(1)) {
      _retryIntervalController.text = retryInterval.toStringAsFixed(1);
    }

    return Column(
      children: [
        // 重试次数设置
        SettingsCard(
          title: '重试次数',
          icon: Icons.replay_outlined,
          child: Row(
            children: [
              // 标题区域
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('重试次数'),
                    Text(
                      '最多 $retryCount 次',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 减少按钮
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                visualDensity: VisualDensity.compact,
                onPressed: retryCount > 1
                    ? () => _updateRetryCount(retryCount - 1)
                    : null,
              ),
              // 滑条
              Expanded(
                child: SliderTheme(
                  data: _buildSettingsSliderTheme(context),
                  child: Slider(
                    value: retryCount.toDouble(),
                    min: 1,
                    max: 30,
                    onChanged: (value) => _updateRetryCount(value.round()),
                  ),
                ),
              ),
              // 增加按钮
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                visualDensity: VisualDensity.compact,
                onPressed: retryCount < 30
                    ? () => _updateRetryCount(retryCount + 1)
                    : null,
              ),
              const SizedBox(width: 4),
              // 数字输入框
              SizedBox(
                width: 56,
                child: ThemedInput(
                  controller: _retryCountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: _buildSettingsInputDecoration(theme),
                  onSubmitted: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) {
                      _updateRetryCount(parsed);
                    } else {
                      _retryCountController.text = '$retryCount';
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              const Text('次'),
            ],
          ),
        ),

        // 重试间隔设置
        SettingsCard(
          title: '重试间隔',
          icon: Icons.timer_outlined,
          child: Row(
            children: [
              // 标题区域
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('重试间隔'),
                    Text(
                      '${retryInterval.toStringAsFixed(1)} 秒',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 减少按钮
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                visualDensity: VisualDensity.compact,
                onPressed: retryInterval > 0.5
                    ? () => _updateRetryInterval(retryInterval - 0.5)
                    : null,
              ),
              // 滑条
              Expanded(
                child: SliderTheme(
                  data: _buildSettingsSliderTheme(context),
                  child: Slider(
                    value: retryInterval,
                    min: 0.5,
                    max: 10.0,
                    onChanged: (value) =>
                        _updateRetryInterval((value * 2).round() / 2),
                  ),
                ),
              ),
              // 增加按钮
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                visualDensity: VisualDensity.compact,
                onPressed: retryInterval < 10.0
                    ? () => _updateRetryInterval(retryInterval + 0.5)
                    : null,
              ),
              const SizedBox(width: 4),
              // 数字输入框
              SizedBox(
                width: 56,
                child: ThemedInput(
                  controller: _retryIntervalController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: _buildSettingsInputDecoration(theme),
                  onSubmitted: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed != null) {
                      _updateRetryInterval(parsed);
                    } else {
                      _retryIntervalController.text =
                          retryInterval.toStringAsFixed(1);
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              const Text('秒'),
            ],
          ),
        ),

        // 悬浮球背景图片设置
        SettingsCard(
          title: '悬浮球背景',
          icon: Icons.image_outlined,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _backgroundImagePath != null ? '已设置自定义背景' : '默认样式',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (_backgroundImagePath != null)
                      Text(
                        _backgroundImagePath!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 预览图
              if (_backgroundImagePath != null)
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: ClipOval(
                    child: Image.file(
                      File(_backgroundImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              // 清除按钮
              if (_backgroundImagePath != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: '清除背景',
                  onPressed: _clearBackgroundImage,
                ),
              // 选择按钮
              FilledButton.tonalIcon(
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('选择图片'),
                onPressed: _selectBackgroundImage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
