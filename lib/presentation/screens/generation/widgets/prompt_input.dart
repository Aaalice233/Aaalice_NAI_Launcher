import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/nai_prompt_parser.dart';
import '../../../../data/models/prompt/prompt_tag.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/prompt_config_provider.dart';
import '../../../router/app_router.dart';
import '../../../widgets/autocomplete/autocomplete.dart';
import '../../../widgets/common/themed_scaffold.dart';
import '../../../widgets/prompt/nai_syntax_controller.dart';
import '../../../widgets/prompt/prompt_tag_view.dart';

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

  bool _showNegative = false;
  bool _isPromptFocused = false;
  bool _isNegativeFocused = false;

  // 视图模式
  PromptViewMode _viewMode = PromptViewMode.text;
  List<PromptTag> _promptTags = [];
  List<PromptTag> _negativeTags = [];

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
    ref.read(generationParamsNotifierProvider.notifier).updatePrompt(promptText);
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
    _promptController.text = prompt;
    _promptTags = NaiPromptParser.parse(prompt);
    ref.read(generationParamsNotifierProvider.notifier).updatePrompt(prompt);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已生成随机提示词'),
        duration: Duration(seconds: 1),
      ),
    );
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

    if (widget.compact) {
      return _buildCompactLayout(theme);
    }

    return _buildFullLayout(theme);
  }

  Widget _buildFullLayout(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 视图切换标签栏
        _buildViewModeToggle(theme),

        const SizedBox(height: 8),

        // 正向提示词区域
        _viewMode == PromptViewMode.text
            ? _buildTextPromptInput(theme)
            : _buildTagPromptView(theme),

        const SizedBox(height: 8),

        // 展开/折叠负向提示词 + 操作按钮
        _buildActionBar(theme),

        // 负向提示词 (可折叠)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState:
              _showNegative ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _viewMode == PromptViewMode.text
                ? _buildTextNegativeInput(theme)
                : _buildTagNegativeView(theme),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
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
                  label: '文本',
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
                  label: '标签',
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: _isPromptFocused ? 300 : 120,
      ),
      child: AutocompleteTextField(
        controller: _promptController,
        focusNode: _promptFocusNode,
        config: const AutocompleteConfig(
          maxSuggestions: 20,
          showTranslation: true,
          showCategory: true,
          showCount: true,
          autoInsertComma: true,
        ),
        decoration: InputDecoration(
          labelText: '提示词 (Prompt)',
          hintText: '描述你想要生成的图像... (输入2个字符后显示标签建议)',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        maxLines: null,
        minLines: _isPromptFocused ? 4 : 2,
        onChanged: (value) {
          ref.read(generationParamsNotifierProvider.notifier).updatePrompt(value);
        },
      ),
    );
  }

  Widget _buildTagPromptView(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 100,
        maxHeight: 220,
      ),
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
      child: PromptTagView(
        tags: _promptTags,
        onTagsChanged: _onPromptTagsChanged,
        emptyHint: '添加标签来描述你想要的画面',
        maxHeight: 220,
      ),
    );
  }

  Widget _buildTextNegativeInput(ThemeData theme) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: _isNegativeFocused ? 200 : 80,
      ),
      child: AutocompleteTextField(
        controller: _negativeController,
        focusNode: _negativeFocusNode,
        config: const AutocompleteConfig(
          maxSuggestions: 15,
          showTranslation: true,
          showCategory: false,
          autoInsertComma: true,
        ),
        decoration: InputDecoration(
          labelText: '负向提示词 (Undesired Content)',
          hintText: '不想出现在图像中的内容...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        maxLines: null,
        minLines: _isNegativeFocused ? 2 : 1,
        onChanged: (value) {
          ref
              .read(generationParamsNotifierProvider.notifier)
              .updateNegativePrompt(value);
        },
      ),
    );
  }

  Widget _buildTagNegativeView(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 60,
        maxHeight: 150,
      ),
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
      child: PromptTagView(
        tags: _negativeTags,
        onTagsChanged: _onNegativeTagsChanged,
        emptyHint: '添加不想出现的元素',
        maxHeight: 150,
        compact: true,
      ),
    );
  }

  Widget _buildActionBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // 左侧：负向提示词折叠按钮
          InkWell(
            onTap: () {
              setState(() {
                _showNegative = !_showNegative;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showNegative
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '负向提示词',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  if (_negativeTags.isNotEmpty || _negativeController.text.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _viewMode == PromptViewMode.tags
                            ? '${_negativeTags.length}'
                            : '${_negativeController.text.split(',').where((s) => s.trim().isNotEmpty).length}',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // 右侧：操作按钮
          // 显示标签数量
          if (_viewMode == PromptViewMode.tags && _promptTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${_promptTags.length} 个标签',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          GestureDetector(
            onLongPress: () => context.push(AppRoutes.promptConfig),
            child: IconButton(
              icon: Icon(
                Icons.casino_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              tooltip: '随机提示词 (长按配置)',
              onPressed: _generateRandomPrompt,
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.fullscreen,
              size: 20,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            tooltip: '全屏编辑',
            onPressed: _openFullScreenEditor,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(
              Icons.clear,
              size: 20,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            tooltip: '清空',
            onPressed: _clearPrompt,
            visualDensity: VisualDensity.compact,
          ),
        ],
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
        hintText: '输入提示词...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.fullscreen),
              tooltip: '全屏编辑',
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
        _negativeController.text = NaiPromptParser.toPromptString(_negativeTags);
        _viewMode = PromptViewMode.text;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ThemedScaffold(
      appBar: AppBar(
        title: const Text('编辑提示词'),
        actions: [
          // 视图切换按钮
          IconButton(
            icon: Icon(
              _viewMode == PromptViewMode.text
                  ? Icons.label_outline
                  : Icons.text_fields,
            ),
            tooltip: _viewMode == PromptViewMode.text ? '切换到标签视图' : '切换到文本视图',
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
                Text('正向提示词', style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                if (_viewMode == PromptViewMode.tags)
                  Text(
                    '${_promptTags.length} 个标签',
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
                      hintText: '输入提示词...',
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
                    child: PromptTagView(
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
                Text('负向提示词', style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                if (_viewMode == PromptViewMode.tags)
                  Text(
                    '${_negativeTags.length} 个标签',
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
                      hintText: '输入负向提示词...',
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
                    child: PromptTagView(
                      tags: _negativeTags,
                      onTagsChanged: (tags) {
                        setState(() => _negativeTags = tags);
                        ref
                            .read(generationParamsNotifierProvider.notifier)
                            .updateNegativePrompt(
                                NaiPromptParser.toPromptString(tags));
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
