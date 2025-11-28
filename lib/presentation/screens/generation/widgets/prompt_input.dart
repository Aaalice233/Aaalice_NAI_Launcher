import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/prompt_formatter.dart';
import '../../../../core/utils/prompt_randomizer.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/prompt_config_provider.dart';
import '../../../router/app_router.dart';
import '../../../widgets/autocomplete/autocomplete.dart';
import '../../../widgets/common/themed_input.dart';
import '../../../widgets/common/themed_scaffold.dart';

/// Prompt 输入组件 (带自动补全)
class PromptInputWidget extends ConsumerStatefulWidget {
  final bool compact;

  const PromptInputWidget({super.key, this.compact = false});

  @override
  ConsumerState<PromptInputWidget> createState() => _PromptInputWidgetState();
}

class _PromptInputWidgetState extends ConsumerState<PromptInputWidget> {
  final _promptController = TextEditingController();
  final _negativeController = TextEditingController();
  final _promptFocusNode = FocusNode();
  final _negativeFocusNode = FocusNode();

  bool _showNegative = false;
  bool _isPromptFocused = false;
  bool _isNegativeFocused = false;

  @override
  void initState() {
    super.initState();
    final params = ref.read(generationParamsNotifierProvider);
    _promptController.text = params.prompt;
    _negativeController.text = params.negativePrompt;

    _promptFocusNode.addListener(_onPromptFocusChanged);
    _negativeFocusNode.addListener(_onNegativeFocusChanged);
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
    final prompt = ref.read(promptConfigNotifierProvider.notifier).generatePrompt();
    _promptController.text = prompt;
    ref.read(generationParamsNotifierProvider.notifier).updatePrompt(prompt);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已生成随机提示词'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// 格式化提示词
  void _formatPrompt() {
    final text = _promptController.text;
    if (text.isEmpty) return;

    // 验证语法
    final validation = PromptFormatter.validate(text);
    if (!validation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('语法错误: ${validation.errors.first}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 格式化
    final formatted = PromptFormatter.format(text);
    _promptController.text = formatted;
    ref.read(generationParamsNotifierProvider.notifier).updatePrompt(formatted);

    if (validation.hasWarnings) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已格式化，注意: ${validation.warnings.first}'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已格式化'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// 处理本地随机化
  void _processLocalRandom() {
    final text = _promptController.text;
    if (!PromptRandomizer.containsLocalRandom(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有找到本地随机化语法 {随机...随机}'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final processed = PromptRandomizer.process(text);
    _promptController.text = processed;
    ref.read(generationParamsNotifierProvider.notifier).updatePrompt(processed);

    final combinations = PromptRandomizer.estimateCombinations(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已随机化 (共 $combinations 种组合)'),
        duration: const Duration(seconds: 2),
      ),
    );
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
        // 正向提示词
        ConstrainedBox(
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
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 格式化按钮
                  IconButton(
                    icon: const Icon(Icons.auto_fix_high),
                    tooltip: '格式化提示词',
                    onPressed: _formatPrompt,
                  ),
                  // 本地随机化按钮
                  IconButton(
                    icon: const Icon(Icons.shuffle),
                    tooltip: '处理本地随机化 {随机...随机}',
                    onPressed: _processLocalRandom,
                  ),
                  // 随机提示词按钮
                  GestureDetector(
                    onLongPress: () => context.push(AppRoutes.promptConfig),
                    child: IconButton(
                      icon: const Icon(Icons.casino_outlined),
                      tooltip: '随机提示词 (长按配置)',
                      onPressed: _generateRandomPrompt,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    tooltip: '全屏编辑',
                    onPressed: _openFullScreenEditor,
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _promptController.clear();
                      ref.read(generationParamsNotifierProvider.notifier)
                          .updatePrompt('');
                    },
                  ),
                ],
              ),
            ),
            maxLines: null,
            minLines: _isPromptFocused ? 4 : 2,
            onChanged: (value) {
              ref.read(generationParamsNotifierProvider.notifier)
                  .updatePrompt(value);
            },
          ),
        ),

        const SizedBox(height: 8),

        // 展开/折叠负向提示词
        InkWell(
          onTap: () {
            setState(() {
              _showNegative = !_showNegative;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
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
              ],
            ),
          ),
        ),

        // 负向提示词 (可折叠)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _showNegative
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ConstrainedBox(
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
                  ref.read(generationParamsNotifierProvider.notifier)
                      .updateNegativePrompt(value);
                },
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
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
                onPressed: () {
                  _promptController.clear();
                  ref.read(generationParamsNotifierProvider.notifier)
                      .updatePrompt('');
                },
              ),
          ],
        ),
      ),
      maxLines: 2,
      minLines: 1,
      onChanged: (value) {
        ref.read(generationParamsNotifierProvider.notifier)
            .updatePrompt(value);
      },
    );
  }
}

class _FullScreenPromptEditor extends ConsumerWidget {
  const _FullScreenPromptEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ref.watch(generationParamsNotifierProvider);

    return ThemedScaffold(
      appBar: AppBar(
        title: const Text('编辑提示词'),
        actions: [
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
            Text('正向提示词', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            AutocompleteTextField(
              controller: TextEditingController(text: params.prompt),
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
                ref.read(generationParamsNotifierProvider.notifier).updatePrompt(value);
              },
            ),
            const SizedBox(height: 24),
            Text('负向提示词', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            AutocompleteTextField(
              controller: TextEditingController(text: params.negativePrompt),
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
                ref.read(generationParamsNotifierProvider.notifier).updateNegativePrompt(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
