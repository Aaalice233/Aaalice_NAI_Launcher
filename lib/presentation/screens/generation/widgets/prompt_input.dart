import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/nai_prompt_parser.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/models/prompt/prompt_tag.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/prompt_config_provider.dart';
import '../../../providers/prompt_view_mode_provider.dart';
import '../../../widgets/autocomplete/autocomplete.dart';
import '../../../widgets/character/character_prompt_button.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_scaffold.dart';
import '../../../widgets/prompt/nai_syntax_controller.dart';
import '../../../widgets/prompt/quality_tags_hint.dart';
import '../../../widgets/prompt/random_mode_selector.dart';
import '../../../widgets/prompt/tag_view.dart';
import '../../../widgets/prompt/toolbar/toolbar.dart';
import '../../../widgets/prompt/uc_preset_selector.dart';
import '../../../widgets/prompt/unified/unified_prompt_config.dart'
    show PromptViewMode;

/// Prompt 输入组件 (带自动补全和标签视图)
class PromptInputWidget extends ConsumerStatefulWidget {
  final bool compact;

  const PromptInputWidget({super.key, this.compact = false});

  @override
  ConsumerState<PromptInputWidget> createState() => _PromptInputWidgetState();
}

class _PromptInputWidgetState extends ConsumerState<PromptInputWidget> {
  late final NaiSyntaxController _promptController;
  late final NaiSyntaxController _negativeController;
  final _promptFocusNode = FocusNode();
  final _negativeFocusNode = FocusNode();

  // 标签列表（视图模式从共享 Provider 读取）
  List<PromptTag> _promptTags = [];
  List<PromptTag> _negativeTags = [];

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

    // 初始化标签列表
    _promptTags = NaiPromptParser.parse(params.prompt);
    _negativeTags = NaiPromptParser.parse(params.negativePrompt);
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

  void _toggleViewMode() {
    final currentMode = ref.read(promptViewModeNotifierProvider);
    if (currentMode == PromptViewMode.text) {
      // 切换到标签视图，解析当前文本
      setState(() {
        _promptTags = NaiPromptParser.parse(_promptController.text);
        _negativeTags = NaiPromptParser.parse(_negativeController.text);
      });
      ref
          .read(promptViewModeNotifierProvider.notifier)
          .setViewMode(PromptViewMode.tags);
    } else {
      // 切换到文本视图，同步标签到文本
      final promptText = NaiPromptParser.toPromptString(_promptTags);
      final negativeText = NaiPromptParser.toPromptString(_negativeTags);
      _promptController.text = promptText;
      _negativeController.text = negativeText;
      ref
          .read(promptViewModeNotifierProvider.notifier)
          .setViewMode(PromptViewMode.text);
    }
  }

  void _onPromptTagsChanged(List<PromptTag> tags) {
    setState(() {
      _promptTags = tags;
    });
    // 同步到 provider
    final promptText = NaiPromptParser.toPromptString(tags);
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updatePrompt(promptText);
  }

  void _onNegativeTagsChanged(List<PromptTag> tags) {
    setState(() {
      _negativeTags = tags;
    });
    // 同步到 provider
    final negativeText = NaiPromptParser.toPromptString(tags);
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateNegativePrompt(negativeText);
  }

  /// 从 Provider 同步提示词到本地状态
  void _syncPromptFromProvider(String prompt) {
    // 避免循环触发：只在内容不同时更新
    if (_promptController.text != prompt) {
      _promptController.text = prompt;
    }
    final newTags = NaiPromptParser.parse(prompt);
    if (!_tagsEqual(_promptTags, newTags)) {
      setState(() => _promptTags = newTags);
    }
  }

  /// 从 Provider 同步负向提示词到本地状态
  void _syncNegativeFromProvider(String negativePrompt) {
    if (_negativeController.text != negativePrompt) {
      _negativeController.text = negativePrompt;
    }
    final newTags = NaiPromptParser.parse(negativePrompt);
    if (!_tagsEqual(_negativeTags, newTags)) {
      setState(() => _negativeTags = newTags);
    }
  }

  /// 比较两个标签列表是否相等
  bool _tagsEqual(List<PromptTag> a, List<PromptTag> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].text != b[i].text || a[i].weight != b[i].weight) return false;
    }
    return true;
  }

  void _openFullScreenEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const _FullScreenPromptEditor(),
      ),
    );
  }

  /// 生成随机提示词
  Future<void> _generateRandomPrompt() async {
    try {
      // 检查当前模型是否支持多角色
      final params = ref.read(generationParamsNotifierProvider);
      final isV4Model = params.isV4Model;

      // 使用统一的生成入口
      final result = await ref
          .read(promptConfigNotifierProvider.notifier)
          .generateRandomPrompt(isV4Model: isV4Model);

      // 设置主提示词
      ref
          .read(generationParamsNotifierProvider.notifier)
          .updatePrompt(result.mainPrompt);

      // 如果有角色提示词，同步到角色管理器
      if (result.hasCharacters && isV4Model) {
        final characterPrompts = result.toCharacterPrompts();
        ref
            .read(characterPromptNotifierProvider.notifier)
            .replaceAll(characterPrompts);

        // 提示用户角色已生成
        if (mounted) {
          AppToast.success(context, context.l10n.tagLibrary_generatedCharacters(result.characterCount.toString()));
        }
      } else if (result.noHumans) {
        // 无人物场景，清空角色
        ref.read(characterPromptNotifierProvider.notifier).clearAll();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.tagLibrary_generateFailed(e.toString()));
      }
    }
  }

  /// 显示随机模式选择
  void _showRandomModeSelector() {
    RandomModeBottomSheet.show(context);
  }

  void _clearPrompt() {
    _promptController.clear();
    setState(() {
      _promptTags = [];
    });
    ref.read(generationParamsNotifierProvider.notifier).updatePrompt('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 监听 Provider 变化，自动同步到本地状态
    ref.listen(generationParamsNotifierProvider, (previous, next) {
      if (previous?.prompt != next.prompt) {
        _syncPromptFromProvider(next.prompt);
      }
      if (previous?.negativePrompt != next.negativePrompt) {
        _syncNegativeFromProvider(next.negativePrompt);
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
    // 从共享 Provider 读取视图模式
    final viewMode = ref.watch(promptViewModeNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶栏：正面/负面切换 + 操作按钮
        _buildTopBar(theme, viewMode),

        const SizedBox(height: 8),

        // 提示词编辑区域
        Expanded(
          child: _isNegativeMode
              ? (viewMode == PromptViewMode.text
                  ? _buildTextNegativeInput(theme)
                  : _buildTagNegativeView(theme))
              : (viewMode == PromptViewMode.text
                  ? _buildTextPromptInput(theme)
                  : _buildTagPromptView(theme)),
        ),
      ],
    );
  }

  Widget _buildTopBar(ThemeData theme, PromptViewMode viewMode) {
    final promptCount = viewMode == PromptViewMode.tags
        ? _promptTags.length
        : _promptController.text
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .length;
    final negativeCount = viewMode == PromptViewMode.tags
        ? _negativeTags.length
        : _negativeController.text
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .length;

    // 获取质量词设置和模型
    final addQualityTags = ref.watch(qualityTagsSettingsProvider);
    final model = ref.watch(generationParamsNotifierProvider).model;

    return Row(
      children: [
        // 正面/负面切换标签
        _buildPromptTypeSwitch(theme, promptCount, negativeCount),

        // 使用 Expanded 填充剩余空间
        const Expanded(child: SizedBox()),

        // 多人角色提示词按钮
        const CharacterPromptButton(),

        const SizedBox(width: 8),

        // 质量词提示
        QualityTagsHint(
          enabled: addQualityTags,
          model: model,
          onTap: () {
            ref.read(qualityTagsSettingsProvider.notifier).toggle();
          },
        ),

        const SizedBox(width: 6),

        // UC 预设选择器
        UcPresetSelector(model: model),

        const SizedBox(width: 8),

        // 使用共享的工具栏组件
        PromptEditorToolbar(
          config: PromptEditorToolbarConfig.mainEditor,
          viewMode: viewMode,
          onViewModeChanged: (mode) {
            if (mode != viewMode) _toggleViewMode();
          },
          onRandomPressed: _generateRandomPrompt,
          onRandomLongPressed: _showRandomModeSelector,
          onFullscreenPressed: _openFullScreenEditor,
          onClearPressed: _isNegativeMode ? _clearNegative : _clearPrompt,
          onSettingsPressed: () => _showSettingsMenu(context, theme),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        ),
      ],
    );
  }

  void _clearNegative() {
    _negativeController.clear();
    setState(() {
      _negativeTags = [];
    });
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateNegativePrompt('');
  }

  Widget _buildTextPromptInput(ThemeData theme) {
    final enableAutocomplete = ref.watch(autocompleteSettingsProvider);
    final enableAutoFormat = ref.watch(autoFormatPromptSettingsProvider);
    final enableSdSyntaxAutoConvert =
        ref.watch(sdSyntaxAutoConvertSettingsProvider);
    return AutocompleteTextField(
      controller: _promptController,
      focusNode: _promptFocusNode,
      enableAutocomplete: enableAutocomplete,
      enableAutoFormat: enableAutoFormat,
      enableSdSyntaxAutoConvert: enableSdSyntaxAutoConvert,
      config: const AutocompleteConfig(
        maxSuggestions: 20,
        showTranslation: true,
        showCategory: true,
        showCount: true,
        autoInsertComma: true,
      ),
      decoration: InputDecoration(
        hintText: enableAutocomplete
            ? context.l10n.prompt_describeImageWithHint
            : context.l10n.prompt_describeImage,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      maxLines: null,
      expands: true,
      onChanged: (value) {
        ref.read(generationParamsNotifierProvider.notifier).updatePrompt(value);
      },
    );
  }

  Widget _buildTagPromptView(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: TagView(
        tags: _promptTags,
        onTagsChanged: _onPromptTagsChanged,
        emptyHint: context.l10n.prompt_addTagsHint,
      ),
    );
  }

  Widget _buildTextNegativeInput(ThemeData theme) {
    final enableAutocomplete = ref.watch(autocompleteSettingsProvider);
    final enableAutoFormat = ref.watch(autoFormatPromptSettingsProvider);
    final enableSdSyntaxAutoConvert =
        ref.watch(sdSyntaxAutoConvertSettingsProvider);
    return AutocompleteTextField(
      controller: _negativeController,
      focusNode: _negativeFocusNode,
      enableAutocomplete: enableAutocomplete,
      enableAutoFormat: enableAutoFormat,
      enableSdSyntaxAutoConvert: enableSdSyntaxAutoConvert,
      config: const AutocompleteConfig(
        maxSuggestions: 15,
        showTranslation: true,
        showCategory: false,
        autoInsertComma: true,
      ),
      decoration: InputDecoration(
        hintText: context.l10n.prompt_unwantedContent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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

  Widget _buildTagNegativeView(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.errorContainer.withOpacity(0.15),
            theme.colorScheme.errorContainer.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.1),
        ),
      ),
      child: TagView(
        tags: _negativeTags,
        onTagsChanged: _onNegativeTagsChanged,
        emptyHint: context.l10n.prompt_addUnwantedHint,
        compact: true,
      ),
    );
  }

  Widget _buildCompactLayout(ThemeData theme) {
    return AutocompleteTextField(
      controller: _promptController,
      focusNode: _promptFocusNode,
      config: const AutocompleteConfig(
        maxSuggestions: 15,
        showTranslation: true,
        autoInsertComma: true,
      ),
      decoration: InputDecoration(
        hintText: context.l10n.prompt_inputPrompt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.fullscreen),
              tooltip: context.l10n.tooltip_fullscreenEdit,
              onPressed: _openFullScreenEditor,
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
      onChanged: (value) {
        ref.read(generationParamsNotifierProvider.notifier).updatePrompt(value);
      },
    );
  }
}

class _FullScreenPromptEditor extends ConsumerStatefulWidget {
  const _FullScreenPromptEditor();

  @override
  ConsumerState<_FullScreenPromptEditor> createState() =>
      _FullScreenPromptEditorState();
}

class _FullScreenPromptEditorState
    extends ConsumerState<_FullScreenPromptEditor> {
  PromptViewMode _viewMode = PromptViewMode.text;
  late List<PromptTag> _promptTags;
  late List<PromptTag> _negativeTags;
  late NaiSyntaxController _promptController;
  late NaiSyntaxController _negativeController;

  @override
  void initState() {
    super.initState();
    final params = ref.read(generationParamsNotifierProvider);
    _promptController = NaiSyntaxController(text: params.prompt);
    _negativeController = NaiSyntaxController(text: params.negativePrompt);
    _promptTags = NaiPromptParser.parse(params.prompt);
    _negativeTags = NaiPromptParser.parse(params.negativePrompt);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  void _toggleViewMode() {
    setState(() {
      if (_viewMode == PromptViewMode.text) {
        _promptTags = NaiPromptParser.parse(_promptController.text);
        _negativeTags = NaiPromptParser.parse(_negativeController.text);
        _viewMode = PromptViewMode.tags;
      } else {
        _promptController.text = NaiPromptParser.toPromptString(_promptTags);
        _negativeController.text =
            NaiPromptParser.toPromptString(_negativeTags);
        _viewMode = PromptViewMode.text;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 监听高亮设置变化，更新控制器
    final highlightEnabled = ref.watch(highlightEmphasisSettingsProvider);
    _promptController.highlightEnabled = highlightEnabled;
    _negativeController.highlightEnabled = highlightEnabled;

    return ThemedScaffold(
      appBar: AppBar(
        title: Text(context.l10n.prompt_editPrompt),
        actions: [
          // 视图切换按钮
          IconButton(
            icon: Icon(
              _viewMode == PromptViewMode.text
                  ? Icons.label_outline
                  : Icons.text_fields,
            ),
            tooltip: _viewMode == PromptViewMode.text
                ? context.l10n.prompt_switchToTagView
                : context.l10n.prompt_switchToTextView,
            onPressed: _toggleViewMode,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 正向提示词
            Row(
              children: [
                Text(
                  context.l10n.prompt_positivePrompt,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                if (_viewMode == PromptViewMode.tags)
                  Text(
                    context.l10n.prompt_tags(_promptTags.length.toString()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _viewMode == PromptViewMode.text
                ? AutocompleteTextField(
                    controller: _promptController,
                    maxLines: 10,
                    minLines: 5,
                    enableSdSyntaxAutoConvert:
                        ref.watch(sdSyntaxAutoConvertSettingsProvider),
                    config: const AutocompleteConfig(
                      showTranslation: true,
                      showCategory: true,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: context.l10n.prompt_inputPrompt,
                    ),
                    onChanged: (value) {
                      ref
                          .read(generationParamsNotifierProvider.notifier)
                          .updatePrompt(value);
                    },
                  )
                : Container(
                    constraints: const BoxConstraints(minHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TagView(
                      tags: _promptTags,
                      onTagsChanged: (tags) {
                        setState(() => _promptTags = tags);
                        ref
                            .read(generationParamsNotifierProvider.notifier)
                            .updatePrompt(NaiPromptParser.toPromptString(tags));
                      },
                    ),
                  ),

            const SizedBox(height: 24),

            // 负向提示词
            Row(
              children: [
                Text(
                  context.l10n.prompt_negativePrompt,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                if (_viewMode == PromptViewMode.tags)
                  Text(
                    context.l10n.prompt_tags(_negativeTags.length.toString()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _viewMode == PromptViewMode.text
                ? AutocompleteTextField(
                    controller: _negativeController,
                    maxLines: 5,
                    minLines: 3,
                    enableSdSyntaxAutoConvert:
                        ref.watch(sdSyntaxAutoConvertSettingsProvider),
                    config: const AutocompleteConfig(
                      showTranslation: true,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: context.l10n.prompt_inputNegativePrompt,
                    ),
                    onChanged: (value) {
                      ref
                          .read(generationParamsNotifierProvider.notifier)
                          .updateNegativePrompt(value);
                    },
                  )
                : Container(
                    constraints: const BoxConstraints(minHeight: 120),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TagView(
                      tags: _negativeTags,
                      onTagsChanged: (tags) {
                        setState(() => _negativeTags = tags);
                        ref
                            .read(generationParamsNotifierProvider.notifier)
                            .updateNegativePrompt(
                              NaiPromptParser.toPromptString(tags),
                            );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
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

  const _PromptTypeButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.color,
    required this.onTap,
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

    return MouseRegion(
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
  }
}
