import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/nai_prompt_parser.dart';
import '../../../../data/models/prompt/prompt_tag.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/prompt_config_provider.dart';
import '../../../router/app_router.dart';
import '../../../widgets/autocomplete/autocomplete.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_scaffold.dart';
import '../../../widgets/prompt/nai_syntax_controller.dart';
import '../../../widgets/prompt/quality_tags_hint.dart';
import '../../../widgets/prompt/tag_view.dart';
import '../../../widgets/prompt/uc_preset_selector.dart';

/// 视图模式
enum PromptViewMode {
  text,
  tags,
}

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

  bool _isPromptFocused = false;
  bool _isNegativeFocused = false;

  // 视图模式
  PromptViewMode _viewMode = PromptViewMode.text;
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
    setState(() {
      _isPromptFocused = _promptFocusNode.hasFocus;
    });
  }

  void _onNegativeFocusChanged() {
    setState(() {
      _isNegativeFocused = _negativeFocusNode.hasFocus;
    });
  }

  void _toggleViewMode() {
    setState(() {
      if (_viewMode == PromptViewMode.text) {
        // 切换到标签视图，解析当前文本
        _promptTags = NaiPromptParser.parse(_promptController.text);
        _negativeTags = NaiPromptParser.parse(_negativeController.text);
        _viewMode = PromptViewMode.tags;
      } else {
        // 切换到文本视图，同步标签到文本
        final promptText = NaiPromptParser.toPromptString(_promptTags);
        final negativeText = NaiPromptParser.toPromptString(_negativeTags);
        _promptController.text = promptText;
        _negativeController.text = negativeText;
        _viewMode = PromptViewMode.text;
      }
    });
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
  void _generateRandomPrompt() {
    final prompt =
        ref.read(promptConfigNotifierProvider.notifier).generatePrompt();
    // 只更新 Provider，ref.listen 会自动同步到本地状态
    ref.read(generationParamsNotifierProvider.notifier).updatePrompt(prompt);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶栏：正面/负面切换 + 操作按钮
        _buildTopBar(theme),

        const SizedBox(height: 8),

        // 提示词编辑区域
        Expanded(
          child: _isNegativeMode
              ? (_viewMode == PromptViewMode.text
                  ? _buildTextNegativeInput(theme)
                  : _buildTagNegativeView(theme))
              : (_viewMode == PromptViewMode.text
                  ? _buildTextPromptInput(theme)
                  : _buildTagPromptView(theme)),
        ),
      ],
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    final promptCount = _viewMode == PromptViewMode.tags
        ? _promptTags.length
        : _promptController.text
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .length;
    final negativeCount = _viewMode == PromptViewMode.tags
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

        // 视图模式切换
        _buildViewModeSwitch(theme),

        // 随机按钮
        GestureDetector(
          onLongPress: () => context.push(AppRoutes.promptConfig),
          child: IconButton(
            icon: Icon(
              Icons.casino_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            tooltip: context.l10n.tooltip_randomPrompt,
            onPressed: _generateRandomPrompt,
            visualDensity: VisualDensity.compact,
          ),
        ),

        // 全屏按钮
        IconButton(
          icon: Icon(
            Icons.fullscreen,
            size: 20,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          tooltip: context.l10n.tooltip_fullscreenEdit,
          onPressed: _openFullScreenEditor,
          visualDensity: VisualDensity.compact,
        ),

        // 清空按钮（带确认）
        PopupMenuButton<bool>(
          icon: Icon(
            Icons.clear,
            size: 20,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          tooltip: context.l10n.tooltip_clear,
          offset: const Offset(40, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          itemBuilder: (context) => [
            PopupMenuItem<bool>(
              value: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.prompt_clearConfirm(_isNegativeMode ? context.l10n.prompt_negativePrompt : context.l10n.prompt_positivePrompt),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value) {
              if (_isNegativeMode) {
                _clearNegative();
              } else {
                _clearPrompt();
              }
            }
          },
        ),

        // 设置按钮
        _buildSettingsButton(theme),
      ],
    );
  }

  Widget _buildSettingsButton(ThemeData theme) {
    final enableAutocomplete = ref.watch(autocompleteSettingsProvider);
    final enableAutoFormat = ref.watch(autoFormatPromptSettingsProvider);
    final enableHighlight = ref.watch(highlightEmphasisSettingsProvider);

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.settings,
        size: 20,
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
      tooltip: context.l10n.tooltip_promptSettings,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
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
      ],
      onSelected: (value) {
        if (value == 'autocomplete') {
          ref.read(autocompleteSettingsProvider.notifier).toggle();
        } else if (value == 'auto_format') {
          ref.read(autoFormatPromptSettingsProvider.notifier).toggle();
        } else if (value == 'highlight') {
          ref.read(highlightEmphasisSettingsProvider.notifier).toggle();
        }
      },
    );
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

  Widget _buildPromptTypeTab(
    ThemeData theme, {
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    bool isNegative = false,
  }) {
    final color =
        isNegative ? theme.colorScheme.error : theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: color.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? color
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.2)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? color
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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

  Widget _buildViewModeToggle(ThemeData theme) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Stack(
        children: [
          // 滑动指示器
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: _viewMode == PromptViewMode.text
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 按钮
          Row(
            children: [
              Expanded(
                child: _buildViewModeButton(
                  theme,
                  icon: Icons.text_fields_rounded,
                  label: context.l10n.prompt_textMode,
                  isSelected: _viewMode == PromptViewMode.text,
                  onTap: () {
                    if (_viewMode != PromptViewMode.text) _toggleViewMode();
                  },
                ),
              ),
              Expanded(
                child: _buildViewModeButton(
                  theme,
                  icon: Icons.auto_awesome_rounded,
                  label: context.l10n.prompt_tagMode,
                  isSelected: _viewMode == PromptViewMode.tags,
                  onTap: () {
                    if (_viewMode != PromptViewMode.tags) _toggleViewMode();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextPromptInput(ThemeData theme) {
    final enableAutocomplete = ref.watch(autocompleteSettingsProvider);
    final enableAutoFormat = ref.watch(autoFormatPromptSettingsProvider);
    return AutocompleteTextField(
      controller: _promptController,
      focusNode: _promptFocusNode,
      enableAutocomplete: enableAutocomplete,
      enableAutoFormat: enableAutoFormat,
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
    return AutocompleteTextField(
      controller: _negativeController,
      focusNode: _negativeFocusNode,
      enableAutocomplete: enableAutocomplete,
      enableAutoFormat: enableAutoFormat,
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

  /// 小巧的视图模式切换开关
  Widget _buildViewModeSwitch(ThemeData theme) {
    final isTagMode = _viewMode == PromptViewMode.tags;

    return Tooltip(
      message: isTagMode ? context.l10n.prompt_switchToTextView : context.l10n.prompt_switchToTagView,
      child: GestureDetector(
        onTap: _toggleViewMode,
        child: Container(
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 文本模式图标
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: !isTagMode
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.text_fields_rounded,
                  size: 14,
                  color: !isTagMode
                      ? Colors.white
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 2),
              // 标签模式图标
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isTagMode
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: isTagMode
                      ? Colors.white
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
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
            tooltip: _viewMode == PromptViewMode.text ? context.l10n.prompt_switchToTagView : context.l10n.prompt_switchToTextView,
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
                Text(context.l10n.prompt_positivePrompt, style: theme.textTheme.titleMedium),
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
                Text(context.l10n.prompt_negativePrompt, style: theme.textTheme.titleMedium),
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
