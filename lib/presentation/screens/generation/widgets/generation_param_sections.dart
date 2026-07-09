import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_dropdown.dart';
import '../../../widgets/common/themed_input.dart';
import '../../../widgets/common/themed_slider.dart';
import 'size_selector.dart';

/// 生成参数分节控件集
///
/// 从 ParameterPanel 拆出的可组合单元：经典布局的参数面板与
/// 官网式布局的一体滚动列/参数抽屉共用同一份控件，避免双份维护。

/// 参数分节标题
class ParamSectionTitle extends StatelessWidget {
  final String title;

  const ParamSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

/// 模型选择分节（标题 + 下拉框）
class ModelSection extends ConsumerWidget {
  const ModelSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(
      generationParamsNotifierProvider.select((params) => params.model),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamSectionTitle(context.l10n.generation_model),
        const SizedBox(height: 8),
        ThemedDropdown<String>(
          value: model,
          items: ImageModels.allModels.map((model) {
            return DropdownMenuItem(
              value: model,
              child: Text(
                ImageModels.modelDisplayNames[model] ?? model,
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .updateModel(value);
            }
          },
        ),
      ],
    );
  }
}

/// 尺寸设置分节（标题 + 尺寸选择器）
class SizeSection extends ConsumerWidget {
  const SizeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => (width: params.width, height: params.height),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamSectionTitle(context.l10n.generation_imageSize),
        const SizedBox(height: 8),
        SizeSelector(
          width: size.width,
          height: size.height,
          onChanged: (width, height) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .updateSize(width, height);
          },
        ),
      ],
    );
  }
}

/// 采样器分节
class SamplerSection extends ConsumerWidget {
  const SamplerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sampler = ref.watch(
      generationParamsNotifierProvider.select((params) => params.sampler),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamSectionTitle(context.l10n.generation_sampler),
        const SizedBox(height: 8),
        ThemedDropdown<String>(
          value: sampler,
          items: Samplers.allSamplers.map((sampler) {
            return DropdownMenuItem(
              value: sampler,
              child: Text(
                Samplers.samplerDisplayNames[sampler] ?? sampler,
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .updateSampler(value);
            }
          },
        ),
      ],
    );
  }
}

/// 噪声调度分节
class NoiseScheduleSection extends ConsumerWidget {
  const NoiseScheduleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => (
          noiseSchedule: params.noiseSchedule,
          isV4Model: params.isV4Model,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamSectionTitle(context.l10n.generation_noiseSchedule),
        const SizedBox(height: 8),
        ThemedDropdown<String>(
          // V4/V4.5 模型不支持 native，如果当前值是 native 则显示 karras
          value: data.isV4Model && data.noiseSchedule == 'native'
              ? 'karras'
              : data.noiseSchedule,
          items: [
            // V3 模型多一个 Native 选项
            if (!data.isV4Model)
              DropdownMenuItem(
                value: 'native',
                child: Text(
                  NoiseSchedules.displayNames['native'] ?? 'Native',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ...['karras', 'exponential', 'polyexponential'].map((schedule) {
              return DropdownMenuItem(
                value: schedule,
                child: Text(
                  NoiseSchedules.displayNames[schedule] ?? schedule,
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }),
          ],
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .updateNoiseSchedule(value);
            }
          },
        ),
      ],
    );
  }
}

/// 步数分节（标题含当前值 + 滑杆）
class StepsSection extends ConsumerWidget {
  const StepsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = ref.watch(
      generationParamsNotifierProvider.select((params) => params.steps),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamSectionTitle(context.l10n.generation_steps(steps.toString())),
        ThemedSlider(
          value: steps.toDouble(),
          min: 1,
          max: 50,
          divisions: 49,
          onChanged: (value) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .updateSteps(value.round());
          },
        ),
      ],
    );
  }
}

/// CFG Scale 分节（标题含当前值 + Decrisp/Variety+ 开关 + 滑杆）
class CfgScaleSection extends ConsumerWidget {
  const CfgScaleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => (
          scale: params.scale,
          decrisp: params.decrisp,
          varietyPlus: params.varietyPlus,
          isV3Model: params.isV3Model,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ParamSectionTitle(
              context.l10n.generation_cfgScale(data.scale.toStringAsFixed(1)),
            ),
            const Spacer(),
            // Decrisp (仅 V3 模型)
            if (data.isV3Model) ...[
              _ToggleButton(
                label: 'Decrisp',
                isEnabled: data.decrisp,
                onChanged: (value) {
                  ref
                      .read(generationParamsNotifierProvider.notifier)
                      .updateDecrisp(value);
                },
              ),
              const SizedBox(width: 8),
            ],
            // Variety+ (所有模型)
            _ToggleButton(
              label: 'Variety+',
              isEnabled: data.varietyPlus,
              onChanged: (value) {
                ref
                    .read(generationParamsNotifierProvider.notifier)
                    .updateVarietyPlus(value);
              },
            ),
          ],
        ),
        ThemedSlider(
          value: data.scale,
          min: 1,
          max: 20,
          divisions: 190,
          onChanged: (value) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .updateScale(value);
          },
        ),
      ],
    );
  }
}

/// 种子分节（标题 + 输入框 + 复制/清空/锁定）
class SeedSection extends ConsumerStatefulWidget {
  const SeedSection({super.key});

  @override
  ConsumerState<SeedSection> createState() => _SeedSectionState();
}

class _SeedSectionState extends ConsumerState<SeedSection> {
  late final TextEditingController _seedController;
  late final FocusNode _seedFocusNode;

  @override
  void initState() {
    super.initState();
    _seedController = TextEditingController();
    _seedFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _seedController.dispose();
    _seedFocusNode.dispose();
    super.dispose();
  }

  void _syncSeedController(int seed) {
    final nextText = resolveSeedFieldSyncText(
      currentText: _seedController.text,
      seed: seed,
      hasFocus: _seedFocusNode.hasFocus,
    );
    if (nextText == null) {
      return;
    }

    _seedController.value = _seedController.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seed = ref.watch(
      generationParamsNotifierProvider.select((params) => params.seed),
    );

    _syncSeedController(seed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamSectionTitle(context.l10n.generation_seed),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ThemedInput(
                controller: _seedController,
                focusNode: _seedFocusNode,
                hintText: context.l10n.generation_seedRandom,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  // 清空输入框时自动变成随机 (-1)
                  final newSeed =
                      value.isEmpty ? -1 : (int.tryParse(value) ?? -1);
                  if (newSeed != seed) {
                    ref
                        .read(generationParamsNotifierProvider.notifier)
                        .updateSeed(newSeed);
                  }
                },
                suffixIcon: seed == -1
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 复制按钮
                          _SeedIconButton(
                            icon: Icons.copy_rounded,
                            tooltip: context.l10n.common_copy,
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: seed.toString()),
                              );
                              AppToast.success(
                                context,
                                context.l10n.common_copied,
                              );
                            },
                          ),
                          // 清空按钮
                          _SeedIconButton(
                            icon: Icons.clear_rounded,
                            tooltip: context.l10n.common_clear,
                            onPressed: () {
                              _seedController.clear();
                              ref
                                  .read(
                                    generationParamsNotifierProvider.notifier,
                                  )
                                  .updateSeed(-1);
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 8),
            // 种子锁定按钮
            IconButton(
              icon: Icon(
                ref
                        .watch(generationParamsNotifierProvider.notifier)
                        .isSeedLocked
                    ? Icons.lock
                    : Icons.lock_open,
                size: 20,
              ),
              onPressed: () {
                // 先同步输入框的值到 state（防止用户输入后 state 未更新）
                final inputText = _seedController.text.trim();
                final inputSeed =
                    inputText.isEmpty ? -1 : (int.tryParse(inputText) ?? -1);
                if (inputSeed !=
                    ref.read(generationParamsNotifierProvider).seed) {
                  ref
                      .read(generationParamsNotifierProvider.notifier)
                      .updateSeed(inputSeed);
                }

                ref
                    .read(generationParamsNotifierProvider.notifier)
                    .toggleSeedLock();
                // 更新输入框显示
                final newSeed = ref.read(generationParamsNotifierProvider).seed;
                _seedController.text = newSeed == -1 ? '' : newSeed.toString();
                // 锁定状态存于 notifier 而非 state，同值种子不会触发
                // select 重建，需手动刷新图标/背景
                setState(() {});
              },
              tooltip: ref
                      .watch(generationParamsNotifierProvider.notifier)
                      .isSeedLocked
                  ? context.l10n.generation_seedUnlock
                  : context.l10n.generation_seedLock,
              style: IconButton.styleFrom(
                backgroundColor: ref
                        .watch(generationParamsNotifierProvider.notifier)
                        .isSeedLocked
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 高级采样选项内容（V3: SMEA；V4: CFG Rescale），不含折叠容器
///
/// 经典布局包在「高级选项」ExpansionTile 里；
/// 官网式布局在参数抽屉内平铺展示。
class AdvancedSamplingOptions extends ConsumerWidget {
  const AdvancedSamplingOptions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => (
          isV3Model: params.isV3Model,
          isV4Model: params.isV4Model,
          sampler: params.sampler,
          smeaAuto: params.smeaAuto,
          smea: params.smea,
          smeaDyn: params.smeaDyn,
          cfgRescale: params.cfgRescale,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // V3 模型: SMEA 选项 (非 DDIM 采样器时显示)
        if (data.isV3Model && !data.sampler.contains('ddim')) ...[
          // 标题和说明
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              children: [
                Text(
                  'SMEA',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '高分辨率采样优化',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 选项行
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                _SmeaAutoButton(
                  isAuto: data.smeaAuto,
                  onChanged: (value) {
                    ref
                        .read(generationParamsNotifierProvider.notifier)
                        .updateSmeaAuto(value);
                  },
                ),
                const SizedBox(width: 16),
                _SmeaOptions(
                  smea: data.smea,
                  smeaDyn: data.smeaDyn,
                  isAutoEnabled: data.smeaAuto,
                  onSmeaChanged: (value) {
                    ref
                        .read(generationParamsNotifierProvider.notifier)
                        .updateSmea(value);
                  },
                  onSmeaDynChanged: (value) {
                    ref
                        .read(generationParamsNotifierProvider.notifier)
                        .updateSmeaDyn(value);
                  },
                ),
              ],
            ),
          ),
          // Auto 模式说明 (仅 Auto 开启时显示)
          if (data.smeaAuto)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                context.l10n.generation_smeaDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
        // V4 模型: CFG Rescale
        if (data.isV4Model)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.l10n.generation_cfgRescale(
                data.cfgRescale.toStringAsFixed(2),
              ),
            ),
            subtitle: ThemedSlider(
              value: data.cfgRescale,
              min: 0,
              max: 1,
              divisions: 100,
              onChanged: (value) {
                ref
                    .read(generationParamsNotifierProvider.notifier)
                    .updateCfgRescale(value);
              },
            ),
          ),
      ],
    );
  }
}

@visibleForTesting
String? resolveSeedFieldSyncText({
  required String currentText,
  required int seed,
  required bool hasFocus,
}) {
  if (hasFocus) {
    return null;
  }

  final nextText = seed == -1 ? '' : seed.toString();
  if (currentText == nextText) {
    return null;
  }

  return nextText;
}

/// SMEA Auto 按钮 (V3 模型)
class _SmeaAutoButton extends StatelessWidget {
  final bool isAuto;
  final ValueChanged<bool> onChanged;

  const _SmeaAutoButton({
    required this.isAuto,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isAuto
          ? theme.colorScheme.primary.withValues(alpha: 0.15)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onChanged(!isAuto),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isAuto
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAuto ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: isAuto
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                'Auto',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isAuto
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// SMEA 选项复选框 (V3 模型)
class _SmeaOptions extends StatelessWidget {
  final bool smea;
  final bool smeaDyn;
  final bool isAutoEnabled;
  final ValueChanged<bool> onSmeaChanged;
  final ValueChanged<bool> onSmeaDynChanged;

  const _SmeaOptions({
    required this.smea,
    required this.smeaDyn,
    required this.isAutoEnabled,
    required this.onSmeaChanged,
    required this.onSmeaDynChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = isAutoEnabled;

    return Row(
      children: [
        // SMEA 复选框
        _buildCheckbox(
          context: context,
          label: 'SMEA',
          value: smea,
          isDisabled: isDisabled,
          onChanged: onSmeaChanged,
          theme: theme,
        ),
        const SizedBox(width: 16),
        // DYN 复选框
        _buildCheckbox(
          context: context,
          label: 'DYN',
          value: smeaDyn,
          isDisabled: isDisabled,
          onChanged: onSmeaDynChanged,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required BuildContext context,
    required String label,
    required bool value,
    required bool isDisabled,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    final color = isDisabled
        ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
        : (value
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.7));

    return InkWell(
      onTap: isDisabled ? null : () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value ? Icons.check_box : Icons.check_box_outline_blank,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用切换按钮 (用于 Variety+, Decrisp 等)
class _ToggleButton extends StatefulWidget {
  final String label;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const _ToggleButton({
    required this.label,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 计算背景色
    Color backgroundColor;
    if (widget.isEnabled) {
      backgroundColor = _isHovered
          ? theme.colorScheme.primary.withValues(alpha: 0.85)
          : theme.colorScheme.primary;
    } else {
      final baseColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05);
      backgroundColor = _isHovered
          ? (isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.1))
          : baseColor;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.isEnabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isEnabled
                  ? theme.colorScheme.primary
                  : (_isHovered
                      ? theme.colorScheme.outline.withValues(alpha: 0.4)
                      : theme.colorScheme.outline.withValues(alpha: 0.2)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isEnabled) ...[
                Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: theme.colorScheme.onPrimary,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.isEnabled
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface
                          .withValues(alpha: _isHovered ? 0.8 : 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 种子输入框内的图标按钮
class _SeedIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _SeedIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_SeedIconButton> createState() => _SeedIconButtonState();
}

class _SeedIconButtonState extends State<_SeedIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              widget.icon,
              size: 18,
              color: _isHovered
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
