import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/image/image_params.dart';
import '../../../providers/image_generation_provider.dart';

/// 多角色面板组件 (仅 V4 模型支持)
class CharacterPanel extends ConsumerStatefulWidget {
  const CharacterPanel({super.key});

  @override
  ConsumerState<CharacterPanel> createState() => _CharacterPanelState();
}

class _CharacterPanelState extends ConsumerState<CharacterPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = ref.watch(generationParamsNotifierProvider);
    final hasCharacters = params.characters.isNotEmpty;
    final isV4Model = params.isV4Model;

    // 非 V4 模型不显示此面板
    if (!isV4Model) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 20,
                    color: hasCharacters
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '多角色 (V4 专属)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: hasCharacters ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ),
                  if (hasCharacters)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${params.characters.length}/6',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // 展开内容
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),

                  // 说明文字
                  Text(
                    '为每个角色定义独立的提示词和位置（最多6个角色）',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 角色列表
                  if (hasCharacters) ...[
                    ...List.generate(params.characters.length, (index) {
                      return _CharacterItem(
                        index: index,
                        character: params.characters[index],
                        onUpdate: (char) => _updateCharacter(index, char),
                        onRemove: () => _removeCharacter(index),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],

                  // 添加按钮
                  if (params.characters.length < 6)
                    OutlinedButton.icon(
                      onPressed: _addCharacter,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('添加角色'),
                    ),

                  // 清除全部按钮
                  if (hasCharacters) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _clearAllCharacters,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('清除全部角色'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _addCharacter() {
    ref.read(generationParamsNotifierProvider.notifier).addCharacter(
      const CharacterPrompt(prompt: ''),
    );
  }

  void _removeCharacter(int index) {
    ref.read(generationParamsNotifierProvider.notifier).removeCharacter(index);
  }

  void _updateCharacter(int index, CharacterPrompt character) {
    ref.read(generationParamsNotifierProvider.notifier)
        .updateCharacter(index, character);
  }

  void _clearAllCharacters() {
    ref.read(generationParamsNotifierProvider.notifier).clearCharacters();
  }
}

/// 单个角色编辑项
class _CharacterItem extends StatefulWidget {
  final int index;
  final CharacterPrompt character;
  final ValueChanged<CharacterPrompt> onUpdate;
  final VoidCallback onRemove;

  const _CharacterItem({
    required this.index,
    required this.character,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_CharacterItem> createState() => _CharacterItemState();
}

class _CharacterItemState extends State<_CharacterItem> {
  late TextEditingController _promptController;
  late TextEditingController _negativeController;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.character.prompt);
    _negativeController = TextEditingController(
      text: widget.character.negativePrompt,
    );
  }

  @override
  void didUpdateWidget(_CharacterItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character.prompt != widget.character.prompt) {
      _promptController.text = widget.character.prompt;
    }
    if (oldWidget.character.negativePrompt != widget.character.negativePrompt) {
      _negativeController.text = widget.character.negativePrompt;
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '角色 ${widget.index + 1}',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _showAdvanced
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                  tooltip: '高级选项',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: widget.onRemove,
                  tooltip: '移除角色',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),

          // 内容区域
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 角色提示词
                TextField(
                  controller: _promptController,
                  decoration: const InputDecoration(
                    labelText: '角色描述',
                    hintText: '描述这个角色的特征...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  style: theme.textTheme.bodySmall,
                  onChanged: (value) {
                    widget.onUpdate(CharacterPrompt(
                      prompt: value,
                      negativePrompt: widget.character.negativePrompt,
                      positionX: widget.character.positionX,
                      positionY: widget.character.positionY,
                    ));
                  },
                ),

                // 高级选项
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 150),
                  crossFadeState: _showAdvanced
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 角色负向提示词
                        TextField(
                          controller: _negativeController,
                          decoration: InputDecoration(
                            labelText: '负向提示词 (可选)',
                            hintText: '不想出现在这个角色上的特征...',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                          ),
                          maxLines: 2,
                          minLines: 1,
                          style: theme.textTheme.bodySmall,
                          onChanged: (value) {
                            widget.onUpdate(CharacterPrompt(
                              prompt: widget.character.prompt,
                              negativePrompt: value,
                              positionX: widget.character.positionX,
                              positionY: widget.character.positionY,
                            ));
                          },
                        ),

                        const SizedBox(height: 12),

                        // 位置设置
                        Text(
                          '角色位置 (可选)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Expanded(
                              child: _PositionSlider(
                                label: 'X',
                                value: widget.character.positionX,
                                onChanged: (value) {
                                  widget.onUpdate(CharacterPrompt(
                                    prompt: widget.character.prompt,
                                    negativePrompt: widget.character.negativePrompt,
                                    positionX: value,
                                    positionY: widget.character.positionY,
                                  ));
                                },
                                onClear: () {
                                  widget.onUpdate(CharacterPrompt(
                                    prompt: widget.character.prompt,
                                    negativePrompt: widget.character.negativePrompt,
                                    positionX: null,
                                    positionY: widget.character.positionY,
                                  ));
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _PositionSlider(
                                label: 'Y',
                                value: widget.character.positionY,
                                onChanged: (value) {
                                  widget.onUpdate(CharacterPrompt(
                                    prompt: widget.character.prompt,
                                    negativePrompt: widget.character.negativePrompt,
                                    positionX: widget.character.positionX,
                                    positionY: value,
                                  ));
                                },
                                onClear: () {
                                  widget.onUpdate(CharacterPrompt(
                                    prompt: widget.character.prompt,
                                    negativePrompt: widget.character.negativePrompt,
                                    positionX: widget.character.positionX,
                                    positionY: null,
                                  ));
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        Text(
                          '位置坐标 (0-1)，用于指定角色在画面中的大致位置',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 位置滑块组件
class _PositionSlider extends StatelessWidget {
  final String label;
  final double? value;
  final ValueChanged<double> onChanged;
  final VoidCallback onClear;

  const _PositionSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium,
            ),
            const Spacer(),
            if (hasValue)
              Text(
                value!.toStringAsFixed(2),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              )
            else
              Text(
                '自动',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value ?? 0.5,
                min: 0.0,
                max: 1.0,
                divisions: 100,
                onChanged: onChanged,
              ),
            ),
            if (hasValue)
              IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: onClear,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: '清除位置',
              ),
          ],
        ),
      ],
    );
  }
}
