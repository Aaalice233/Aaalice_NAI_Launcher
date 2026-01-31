import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/nai_prompt_formatter.dart';
import '../../../../core/utils/sd_to_nai_converter.dart';
import '../../../../data/models/character/character_prompt.dart';
import '../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../data/models/prompt/prompt_preset_mode.dart';
import '../../../../data/services/alias_resolver_service.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/fixed_tags_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/prompt_maximize_provider.dart';
import '../../../providers/quality_preset_provider.dart';
import '../../../providers/queue_execution_provider.dart';
import '../../../providers/uc_preset_provider.dart';
import '../../../widgets/autocomplete/autocomplete.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/prompt/unified/unified_prompt_input.dart';
import '../../../widgets/prompt/unified/unified_prompt_config.dart';
import '../../../widgets/prompt/nai_syntax_controller.dart';
import '../../../widgets/prompt/quality_tags_selector.dart';
import '../../../widgets/prompt/random_mode_selector.dart';
import '../../../widgets/prompt/toolbar/toolbar.dart';
import '../../../widgets/prompt/uc_preset_selector.dart';
import '../../../widgets/character/character_prompt_button.dart';
import '../../../widgets/prompt/fixed_tags_button.dart';
import '../../../providers/pending_prompt_provider.dart';

/// Prompt 输入组件 (带自动补全)
class PromptInputWidget extends ConsumerStatefulWidget {
  final bool compact;
  final VoidCallback? onToggleMaximize;
  final bool isMaximized;

  const PromptInputWidget({
    super.key,
    this.compact = false,
    this.onToggleMaximize,
    this.isMaximized = false,
  });

  @override
  ConsumerState<PromptInputWidget> createState() => _PromptInputWidgetState();
}

class _PromptInputWidgetState extends ConsumerState<PromptInputWidget> {
  late final NaiSyntaxController _promptController;
  late final NaiSyntaxController _negativeController;
  final _promptFocusNode = FocusNode();
  final _negativeFocusNode = FocusNode();

  // 正面/负面切换
  bool _isNegativeMode = false;

  @override
  void initState() {
    super.initState();
    final params = ref.read(generationParamsNotifierProvider);

    // 使用 NAI 语法高亮控制器
    _promptController = NaiSyntaxController(text: params.prompt);
    _negativeController = NaiSyntaxController(text: params.negativePrompt);

    _promptFocusNode.addListener(_onPromptFocusChanged);
    _negativeFocusNode.addListener(_onNegativeFocusChanged);

    // 检查并消费待填充提示词（从画廊发送）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingPrompt();
    });
  }

  /// 消费待填充提示词（从画廊发送）
  void _consumePendingPrompt() {
    final pendingState = ref.read(pendingPromptNotifierProvider);
    if (pendingState.prompt != null || pendingState.negativePrompt != null) {
      // 消费待填充提示词
      final consumed =
          ref.read(pendingPromptNotifierProvider.notifier).consume();

      // 填充正向提示词
      if (consumed.prompt != null && consumed.prompt!.isNotEmpty) {
        // 自动进行语法转换（SD→NAI + 格式化）
        var prompt = consumed.prompt!;
        prompt = SdToNaiConverter.convert(prompt);
        prompt = NaiPromptFormatter.format(prompt);

        _promptController.text = prompt;
        ref
            .read(generationParamsNotifierProvider.notifier)
            .updatePrompt(prompt);
      }

      // 填充负向提示词
      if (consumed.negativePrompt != null &&
          consumed.negativePrompt!.isNotEmpty) {
        // 自动进行语法转换（SD→NAI + 格式化）
        var negativePrompt = consumed.negativePrompt!;
        negativePrompt = SdToNaiConverter.convert(negativePrompt);
        negativePrompt = NaiPromptFormatter.format(negativePrompt);

        _negativeController.text = negativePrompt;
        ref
            .read(generationParamsNotifierProvider.notifier)
            .updateNegativePrompt(negativePrompt);
      }

      // 触发 UI 更新
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _promptFocusNode.removeListener(_onPromptFocusChanged);
    _negativeFocusNode.removeListener(_onNegativeFocusChanged);
    _promptController.dispose();
    _negativeController.dispose();
    _promptFocusNode.dispose();
    _negativeFocusNode.dispose();
    super.dispose();
  }

  void _onPromptFocusChanged() {
    // Focus 状态变化时触发重建
    setState(() {});
  }

  void _onNegativeFocusChanged() {
    // Focus 状态变化时触发重建
    setState(() {});
  }

  /// 从 Provider 同步提示词到本地状态
  void _syncPromptFromProvider(String prompt) {
    // 避免循环触发：只在内容不同时更新
    if (_promptController.text != prompt) {
      _promptController.text = prompt;
    }
  }

  /// 从 Provider 同步负向提示词到本地状态
  void _syncNegativeFromProvider(String negativePrompt) {
    if (_negativeController.text != negativePrompt) {
      _negativeController.text = negativePrompt;
    }
  }

  /// 生成随机提示词
  Future<void> _generateRandomPrompt() async {
    try {
      // 使用统一的随机提示词生成并应用方法
      await ref
          .read(imageGenerationNotifierProvider.notifier)
          .generateAndApplyRandomPrompt();

      // 检查是否有角色被生成（用于 Toast 提示）
      final characterConfig = ref.read(characterPromptNotifierProvider);
      final hasCharacters = characterConfig.characters
          .any((c) => c.enabled && c.prompt.isNotEmpty);

      if (hasCharacters && mounted) {
        final count = characterConfig.characters
            .where((c) => c.enabled && c.prompt.isNotEmpty)
            .length;
        AppToast.success(
          context,
          context.l10n.tagLibrary_generatedCharacters(count.toString()),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.tagLibrary_generateFailed(e.toString()),
        );
      }
    }
  }

  /// 显示随机模式选择
  void _showRandomModeSelector() {
    RandomModeBottomSheet.show(context);
  }

  void _clearPrompt() {
    _promptController.clear();
    ref.read(generationParamsNotifierProvider.notifier).updatePrompt('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 监听 Provider 变化，自动同步到本地状态
    // 注意：队列运行时不同步，避免替换用户正在编辑的提示词
    ref.listen(generationParamsNotifierProvider, (previous, next) {
      // 检查队列执行状态，队列运行/就绪时跳过同步
      bool isQueueActive = false;
      try {
        final queueState = ref.read(queueExecutionNotifierProvider);
        isQueueActive = queueState.isRunning || queueState.isReady;
      } catch (e) {
        // Provider 未初始化
      }

      if (!isQueueActive) {
        if (previous?.prompt != next.prompt) {
          _syncPromptFromProvider(next.prompt);
        }
        if (previous?.negativePrompt != next.negativePrompt) {
          _syncNegativeFromProvider(next.negativePrompt);
        }
      }
    });

    // 监听待填充提示词变化（队列执行、画廊发送等）
    ref.listen(hasPendingPromptProvider, (previous, next) {
      if (next == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _consumePendingPrompt();
        });
      }
    });

    // 监听高亮设置变化，更新控制器
    final highlightEnabled = ref.watch(highlightEmphasisSettingsProvider);
    _promptController.highlightEnabled = highlightEnabled;
    _negativeController.highlightEnabled = highlightEnabled;

    if (widget.compact) {
      return _buildCompactLayout(theme);
    }

    return _buildFullLayout(theme);
  }

  Widget _buildFullLayout(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶栏：正面/负面切换 + 操作按钮
        _buildTopBar(theme),

        const SizedBox(height: 8),

        // 提示词编辑区域（始终为文本输入）
        Expanded(
          child: _isNegativeMode
              ? _buildTextNegativeInput(theme)
              : _buildTextPromptInput(theme),
        ),
      ],
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    final promptCount = _promptController.text
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .length;
    final negativeCount = _negativeController.text
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .length;

    // 获取模型
    final model = ref.watch(generationParamsNotifierProvider).model;

    return Wrap(
      spacing: 8, // 水平间距
      runSpacing: 8, // 换行后的垂直间距
      alignment: WrapAlignment.spaceBetween, // 两端对齐
      crossAxisAlignment: WrapCrossAlignment.center, // 垂直居中
      children: [
        // 正面/负面切换标签 - 左侧
        _buildPromptTypeSwitch(theme, promptCount, negativeCount),

        // 右侧工具按钮组（也用 Wrap 支持极端情况换行）
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // 固定词按钮
            const FixedTagsButton(),

            // 质量词选择器
            QualityTagsSelector(model: model),

            // UC 预设选择器
            UcPresetSelector(model: model),

            // 多人角色编辑器按钮
            const CharacterPromptButton(),

            // 工具栏（随机、全屏、清空、设置）
            PromptEditorToolbar(
              config: PromptEditorToolbarConfig.mainEditor,
              onRandomPressed: _generateRandomPrompt,
              onRandomLongPressed: _showRandomModeSelector,
              // 使用传入的回调或 Provider 切换最大化
              onFullscreenPressed: widget.onToggleMaximize ??
                  () => ref
                      .read(promptMaximizeNotifierProvider.notifier)
                      .toggle(),
              onClearPressed: _isNegativeMode ? _clearNegative : _clearPrompt,
              onSettingsPressed: () => _showSettingsMenu(context, theme),
            ),
          ],
        ),
      ],
    );
  }

  /// 显示设置菜单
  void _showSettingsMenu(BuildContext context, ThemeData theme) {
    final enableAutocomplete = ref.read(autocompleteSettingsProvider);
    final enableAutoFormat = ref.read(autoFormatPromptSettingsProvider);
    final enableHighlight = ref.read(highlightEmphasisSettingsProvider);
    final enableSdSyntaxAutoConvert =
        ref.read(sdSyntaxAutoConvertSettingsProvider);

    // 使用工具栏提供的按钮位置
    final position = PromptEditorToolbar.getSettingsButtonPosition(context);
    if (position == null) return;

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      items: [
        PopupMenuItem<String>(
          value: 'autocomplete',
          child: Row(
            children: [
              Icon(
                enableAutocomplete
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 20,
                color: enableAutocomplete ? theme.colorScheme.primary : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.prompt_smartAutocomplete),
                    Text(
                      context.l10n.prompt_smartAutocompleteSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'auto_format',
          child: Row(
            children: [
              Icon(
                enableAutoFormat
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 20,
                color: enableAutoFormat ? theme.colorScheme.primary : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.prompt_autoFormat),
                    Text(
                      context.l10n.prompt_autoFormatSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'highlight',
          child: Row(
            children: [
              Icon(
                enableHighlight
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 20,
                color: enableHighlight ? theme.colorScheme.primary : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.prompt_highlightEmphasis),
                    Text(
                      context.l10n.prompt_highlightEmphasisSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'sd_syntax_convert',
          child: Row(
            children: [
              Icon(
                enableSdSyntaxAutoConvert
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 20,
                color: enableSdSyntaxAutoConvert
                    ? theme.colorScheme.primary
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.prompt_sdSyntaxAutoConvert),
                    Text(
                      context.l10n.prompt_sdSyntaxAutoConvertSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'autocomplete') {
        ref.read(autocompleteSettingsProvider.notifier).toggle();
      } else if (value == 'auto_format') {
        ref.read(autoFormatPromptSettingsProvider.notifier).toggle();
      } else if (value == 'highlight') {
        ref.read(highlightEmphasisSettingsProvider.notifier).toggle();
      } else if (value == 'sd_syntax_convert') {
        ref.read(sdSyntaxAutoConvertSettingsProvider.notifier).toggle();
      }
    });
  }

  Widget _buildPromptTypeSwitch(
    ThemeData theme,
    int promptCount,
    int negativeCount,
  ) {
    // 获取固定词数据
    final fixedTagsState = ref.watch(fixedTagsNotifierProvider);
    final enabledPrefixes = fixedTagsState.enabledPrefixes;
    final enabledSuffixes = fixedTagsState.enabledSuffixes;

    // 获取质量词数据
    final qualityState = ref.watch(qualityPresetNotifierProvider);
    final params = ref.watch(generationParamsNotifierProvider);
    final qualityContent = ref
        .watch(qualityPresetNotifierProvider.notifier)
        .getEffectiveContent(params.model);

    // 获取负面词预设数据
    final ucState = ref.watch(ucPresetNotifierProvider);
    final ucPresetContent =
        UcPresets.getPresetContent(params.model, ucState.presetType);

    // 获取多角色数据
    final characterConfig = ref.watch(characterPromptNotifierProvider);

    // 预先获取别名解析器，避免在子组件 build 中访问 provider
    final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 正面提示词按钮
        _PromptTypeButton(
          icon: Icons.auto_awesome,
          label: context.l10n.prompt_positive,
          count: promptCount,
          isSelected: !_isNegativeMode,
          color: theme.colorScheme.primary,
          onTap: () => setState(() => _isNegativeMode = false),
          tooltipBuilder: (theme) => _PositivePromptTooltip(
            theme: theme,
            userPrompt: _promptController.text,
            prefixes: enabledPrefixes,
            suffixes: enabledSuffixes,
            qualityMode: qualityState.mode,
            qualityContent: qualityContent,
            characters: characterConfig.characters,
            globalAiChoice: characterConfig.globalAiChoice,
            l10n: context.l10n,
            aliasResolver: aliasResolver,
          ),
        ),
        const SizedBox(width: 8),
        // 负面提示词按钮
        _PromptTypeButton(
          icon: Icons.block,
          label: context.l10n.prompt_negative,
          count: negativeCount,
          isSelected: _isNegativeMode,
          color: theme.colorScheme.error,
          onTap: () => setState(() => _isNegativeMode = true),
          tooltipBuilder: (theme) => _NegativePromptTooltip(
            theme: theme,
            userNegativePrompt: _negativeController.text,
            ucPresetType: ucState.presetType,
            ucPresetContent: ucPresetContent,
            isCustom: ucState.isCustom,
            l10n: context.l10n,
            aliasResolver: aliasResolver,
          ),
        ),
      ],
    );
  }

  void _clearNegative() {
    _negativeController.clear();
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateNegativePrompt('');
  }

  Widget _buildTextPromptInput(ThemeData theme) {
    final enableAutocomplete = ref.watch(autocompleteSettingsProvider);
    final enableAutoFormat = ref.watch(autoFormatPromptSettingsProvider);
    final enableSdSyntaxAutoConvert =
        ref.watch(sdSyntaxAutoConvertSettingsProvider);
    return UnifiedPromptInput(
      controller: _promptController,
      focusNode: _promptFocusNode,
      config: UnifiedPromptConfig(
        enableSyntaxHighlight: true,
        enableAutocomplete: enableAutocomplete,
        enableAutoFormat: enableAutoFormat,
        enableSdSyntaxAutoConvert: enableSdSyntaxAutoConvert,
        enableComfyuiImport: true,
        autocompleteConfig: const AutocompleteConfig(
          maxSuggestions: 20,
          showTranslation: true,
          showCategory: true,
          showCount: true,
          autoInsertComma: true,
        ),
        hintText: enableAutocomplete
            ? context.l10n.prompt_describeImageWithHint
            : context.l10n.prompt_describeImage,
      ),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.all(12),
      ),
      maxLines: null,
      expands: true,
      onComfyuiImport: (globalPrompt, characters) {
        // 清空现有角色并替换
        ref.read(characterPromptNotifierProvider.notifier).clearAll();
        ref.read(characterPromptNotifierProvider.notifier).replaceAll(characters);
        // 更新全局提示词
        ref.read(generationParamsNotifierProvider.notifier).updatePrompt(globalPrompt);
        // 显示成功提示
        AppToast.success(context, '已导入 ${characters.length} 个角色');
      },
      onChanged: (value) {
        ref.read(generationParamsNotifierProvider.notifier).updatePrompt(value);
      },
    );
  }

  Widget _buildTextNegativeInput(ThemeData theme) {
    final enableAutocomplete = ref.watch(autocompleteSettingsProvider);
    final enableAutoFormat = ref.watch(autoFormatPromptSettingsProvider);
    final enableSdSyntaxAutoConvert =
        ref.watch(sdSyntaxAutoConvertSettingsProvider);
    return UnifiedPromptInput(
      controller: _negativeController,
      focusNode: _negativeFocusNode,
      config: UnifiedPromptConfig(
        enableSyntaxHighlight: true,
        enableAutocomplete: enableAutocomplete,
        enableAutoFormat: enableAutoFormat,
        enableSdSyntaxAutoConvert: enableSdSyntaxAutoConvert,
        enableComfyuiImport: false,
        autocompleteConfig: const AutocompleteConfig(
          maxSuggestions: 15,
          showTranslation: true,
          showCategory: false,
          autoInsertComma: true,
        ),
        hintText: context.l10n.prompt_unwantedContent,
      ),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.all(12),
      ),
      maxLines: null,
      expands: true,
      onChanged: (value) {
        ref
            .read(generationParamsNotifierProvider.notifier)
            .updateNegativePrompt(value);
      },
    );
  }

  Widget _buildCompactLayout(ThemeData theme) {
    return UnifiedPromptInput(
      controller: _promptController,
      focusNode: _promptFocusNode,
      config: UnifiedPromptConfig(
        enableSyntaxHighlight: true,
        enableAutocomplete: true,
        enableComfyuiImport: true,
        autocompleteConfig: const AutocompleteConfig(
          maxSuggestions: 15,
          showTranslation: true,
          autoInsertComma: true,
        ),
        hintText: context.l10n.prompt_inputPrompt,
      ),
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.fullscreen),
              tooltip: context.l10n.tooltip_fullscreenEdit,
              onPressed: widget.onToggleMaximize ??
                  () => ref
                      .read(promptMaximizeNotifierProvider.notifier)
                      .toggle(),
            ),
            if (_promptController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: _clearPrompt,
              ),
          ],
        ),
      ),
      maxLines: 2,
      minLines: 1,
      onComfyuiImport: (globalPrompt, characters) {
        ref.read(characterPromptNotifierProvider.notifier).clearAll();
        ref.read(characterPromptNotifierProvider.notifier).replaceAll(characters);
        ref.read(generationParamsNotifierProvider.notifier).updatePrompt(globalPrompt);
        AppToast.success(context, '已导入 ${characters.length} 个角色');
      },
      onChanged: (value) {
        ref.read(generationParamsNotifierProvider.notifier).updatePrompt(value);
      },
    );
  }
}

/// 正面提示词悬浮提示内容
class _PositivePromptTooltip extends StatelessWidget {
  final ThemeData theme;
  final String userPrompt;
  final List<FixedTagEntry> prefixes;
  final List<FixedTagEntry> suffixes;
  final PromptPresetMode qualityMode;
  final String? qualityContent;
  final List<CharacterPrompt> characters;
  final bool globalAiChoice;
  final dynamic l10n;
  final AliasResolverService aliasResolver;

  const _PositivePromptTooltip({
    required this.theme,
    required this.userPrompt,
    required this.prefixes,
    required this.suffixes,
    required this.qualityMode,
    required this.qualityContent,
    required this.characters,
    required this.globalAiChoice,
    required this.l10n,
    required this.aliasResolver,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final hasPrefixes = prefixes.isNotEmpty;
    final hasSuffixes = suffixes.isNotEmpty;
    final hasQuality = qualityContent != null && qualityContent!.isNotEmpty;
    final enabledCharacters =
        characters.where((c) => c.enabled && c.prompt.isNotEmpty).toList();
    final hasCharacters = enabledCharacters.isNotEmpty;

    // 构建最终生效的完整提示词
    final effectivePrompt = _buildEffectivePrompt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部统计标题
        _buildHeader(isDark),

        const SizedBox(height: 10),

        // 固定词（前缀）- 解析别名
        if (hasPrefixes) ...[
          _buildSection(
            icon: Icons.arrow_forward_rounded,
            label: l10n.fixedTags_prefix,
            color: theme.colorScheme.primary,
            content: prefixes
                .map((e) => aliasResolver.resolveAliases(e.content))
                .join(', '),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
        ],

        // 用户输入 - 解析别名
        if (userPrompt.trim().isNotEmpty) ...[
          _buildSection(
            icon: Icons.edit_rounded,
            label: l10n.prompt_mainPositive,
            color: theme.colorScheme.secondary,
            content: aliasResolver.resolveAliases(userPrompt.trim()),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
        ],

        // 质量词
        if (hasQuality) ...[
          _buildSection(
            icon: Icons.star_rounded,
            label: l10n.qualityTags_positive,
            color: Colors.amber,
            content: qualityContent!,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
        ],

        // 多角色提示词
        if (hasCharacters) ...[
          _buildCharacterSection(
            enabledCharacters,
            isDark,
          ),
          const SizedBox(height: 8),
        ],

        // 固定词（后缀）- 解析别名
        if (hasSuffixes) ...[
          _buildSection(
            icon: Icons.arrow_back_rounded,
            label: l10n.fixedTags_suffix,
            color: theme.colorScheme.tertiary,
            content: suffixes
                .map((e) => aliasResolver.resolveAliases(e.content))
                .join(', '),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
        ],

        // 分隔线
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                theme.colorScheme.outlineVariant.withOpacity(0.4),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // 最终生效提示词
        _buildFinalPromptSection(effectivePrompt, isDark),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1),
            theme.colorScheme.primary.withOpacity(isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.prompt_positivePrompt,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String label,
    required Color color,
    required String content,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh.withOpacity(0.4)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withOpacity(0.4)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbVisibility: WidgetStateProperty.all(true),
                thickness: WidgetStateProperty.all(4),
              ),
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalPromptSection(String prompt, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.4),
            theme.colorScheme.secondaryContainer
                .withOpacity(isDark ? 0.2 : 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.output_rounded,
                size: 12,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.prompt_finalPrompt,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              // 复制按钮
              _CopyIconButton(
                content: prompt,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbVisibility: WidgetStateProperty.all(true),
                thickness: WidgetStateProperty.all(4),
              ),
              child: SingleChildScrollView(
                child: Text(
                  prompt,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildEffectivePrompt() {
    final parts = <String>[];

    // 前缀
    for (final p in prefixes) {
      if (p.content.trim().isNotEmpty) {
        parts.add(aliasResolver.resolveAliases(p.content.trim()));
      }
    }

    // 用户输入（解析别名）
    if (userPrompt.trim().isNotEmpty) {
      parts.add(aliasResolver.resolveAliases(userPrompt.trim()));
    }

    // 质量词
    if (qualityContent != null && qualityContent!.isNotEmpty) {
      parts.add(qualityContent!);
    }

    // 多角色提示词
    final enabledCharacters =
        characters.where((c) => c.enabled && c.prompt.isNotEmpty);
    for (final character in enabledCharacters) {
      parts.add(character.toNaiPrompt(useAiPosition: globalAiChoice));
    }

    // 后缀
    for (final s in suffixes) {
      if (s.content.trim().isNotEmpty) {
        parts.add(aliasResolver.resolveAliases(s.content.trim()));
      }
    }

    return parts.join(', ');
  }

  Widget _buildCharacterSection(
    List<CharacterPrompt> enabledCharacters,
    bool isDark,
  ) {
    const color = Colors.teal;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh.withOpacity(0.4)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withOpacity(0.4)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.people_rounded, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                l10n.prompt_characterPrompts,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${enabledCharacters.length}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: enabledCharacters.map((character) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          character.gender == CharacterGender.female
                              ? Icons.female
                              : character.gender == CharacterGender.male
                                  ? Icons.male
                                  : Icons.person,
                          size: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${character.name}: ${character.toNaiPrompt(useAiPosition: globalAiChoice)}',
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 负面提示词悬浮提示内容
class _NegativePromptTooltip extends StatelessWidget {
  final ThemeData theme;
  final String userNegativePrompt;
  final UcPresetType ucPresetType;
  final String ucPresetContent;
  final bool isCustom;
  final dynamic l10n;
  final AliasResolverService aliasResolver;

  const _NegativePromptTooltip({
    required this.theme,
    required this.userNegativePrompt,
    required this.ucPresetType,
    required this.ucPresetContent,
    required this.isCustom,
    required this.l10n,
    required this.aliasResolver,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final hasUserInput = userNegativePrompt.trim().isNotEmpty;
    final hasPreset = ucPresetContent.isNotEmpty;

    // 构建最终生效的完整负面提示词
    final effectiveNegative = _buildEffectiveNegative();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部标题
        _buildHeader(isDark),

        const SizedBox(height: 10),

        // UC预设
        if (hasPreset) ...[
          _buildSection(
            icon: Icons.shield_rounded,
            label: l10n.qualityTags_negative,
            color: theme.colorScheme.error,
            content: ucPresetContent,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
        ],

        // 用户输入 - 解析别名
        if (hasUserInput) ...[
          _buildSection(
            icon: Icons.edit_rounded,
            label: l10n.prompt_mainNegative,
            color: theme.colorScheme.tertiary,
            content: aliasResolver.resolveAliases(userNegativePrompt.trim()),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
        ],

        // 分隔线
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                theme.colorScheme.outlineVariant.withOpacity(0.4),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // 最终生效负面提示词
        _buildFinalSection(effectiveNegative, isDark),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.error.withOpacity(isDark ? 0.2 : 0.1),
            theme.colorScheme.error.withOpacity(isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block,
            size: 14,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.prompt_negativePrompt,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String label,
    required Color color,
    required String content,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh.withOpacity(0.4)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withOpacity(0.4)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbVisibility: WidgetStateProperty.all(true),
                thickness: WidgetStateProperty.all(4),
              ),
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalSection(String prompt, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.errorContainer.withOpacity(isDark ? 0.3 : 0.4),
            theme.colorScheme.surfaceContainerHighest
                .withOpacity(isDark ? 0.2 : 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.output_rounded,
                size: 12,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.prompt_finalNegative,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.error,
                ),
              ),
              const Spacer(),
              // 复制按钮
              if (prompt.isNotEmpty)
                _CopyIconButton(
                  content: prompt,
                  color: theme.colorScheme.error,
                ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbVisibility: WidgetStateProperty.all(true),
                thickness: WidgetStateProperty.all(4),
              ),
              child: SingleChildScrollView(
                child: Text(
                  prompt.isEmpty ? '-' : prompt,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildEffectiveNegative() {
    final parts = <String>[];

    // UC预设
    if (ucPresetContent.isNotEmpty) {
      parts.add(ucPresetContent);
    }

    // 用户输入（解析别名）
    if (userNegativePrompt.trim().isNotEmpty) {
      parts.add(aliasResolver.resolveAliases(userNegativePrompt.trim()));
    }

    return parts.join(', ');
  }
}

/// 提示词类型切换按钮
class _PromptTypeButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final Widget Function(ThemeData theme)? tooltipBuilder;

  const _PromptTypeButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.tooltipBuilder,
  });

  @override
  State<_PromptTypeButton> createState() => _PromptTypeButtonState();
}

class _PromptTypeButtonState extends State<_PromptTypeButton>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _animController.forward(),
        onTapUp: (_) {
          _animController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _animController.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              // 选中时使用渐变背景
              gradient: widget.isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.color.withOpacity(0.2),
                        widget.color.withOpacity(0.1),
                      ],
                    )
                  : null,
              color: widget.isSelected
                  ? null
                  : (_isHovering
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.surfaceContainerHigh),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isSelected
                    ? widget.color.withOpacity(0.5)
                    : (_isHovering
                        ? theme.colorScheme.outline.withOpacity(0.3)
                        : Colors.transparent),
                width: widget.isSelected ? 1.5 : 1,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 图标
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? widget.color.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 16,
                    color: widget.isSelected
                        ? widget.color
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(width: 8),
                // 文字
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: widget.isSelected
                        ? widget.color
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                    letterSpacing: 0.3,
                  ),
                ),
                // 数量徽章
                if (widget.count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? widget.color.withOpacity(0.2)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.count.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.isSelected
                            ? widget.color
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // 如果有 tooltipBuilder，包裹 Tooltip
    if (widget.tooltipBuilder != null) {
      return Tooltip(
        richMessage: WidgetSpan(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: widget.tooltipBuilder!(theme),
          ),
        ),
        preferBelow: true,
        verticalOffset: 20,
        waitDuration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: button,
      );
    }

    return button;
  }
}

/// 复制图标按钮
class _CopyIconButton extends StatefulWidget {
  final String content;
  final Color color;

  const _CopyIconButton({
    required this.content,
    required this.color,
  });

  @override
  State<_CopyIconButton> createState() => _CopyIconButtonState();
}

class _CopyIconButtonState extends State<_CopyIconButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: widget.content));
          if (context.mounted) {
            AppToast.success(context, l10n.common_copied);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _isHovering
                ? widget.color.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.copy_rounded,
            size: 14,
            color: _isHovering
                ? widget.color
                : widget.color.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}
