import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import 'character_list_item.dart';

/// 角色列表面板组件
///
/// 显示所有角色的可滚动列表，支持添加、选择、排序和删除操作。
///
/// Requirements: 1.2, 4.1, 4.3
class CharacterListPanel extends ConsumerWidget {
  /// 当前选中的角色ID
  final String? selectedCharacterId;

  /// 选择角色回调
  final ValueChanged<String?>? onCharacterSelected;

  /// 是否显示操作按钮（上移/下移/删除）
  final bool showActions;

  const CharacterListPanel({
    super.key,
    this.selectedCharacterId,
    this.onCharacterSelected,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(characterListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 添加角色按钮
        _AddCharacterButton(
          onPressed: () => _addCharacter(ref),
        ),
        const SizedBox(height: 8),

        // 角色列表
        Expanded(
          child: characters.isEmpty
              ? _EmptyState()
              : _CharacterList(
                  characters: characters,
                  selectedCharacterId: selectedCharacterId,
                  onCharacterSelected: onCharacterSelected,
                  showActions: showActions,
                  onMoveUp: (index) => _moveCharacterUp(ref, index),
                  onMoveDown: (index) => _moveCharacterDown(ref, index),
                  onDelete: (id) => _deleteCharacter(context, ref, id),
                  onReorder: (oldIndex, newIndex) =>
                      _reorderCharacters(ref, oldIndex, newIndex),
                ),
        ),
      ],
    );
  }

  /// 添加新角色
  void _addCharacter(WidgetRef ref) {
    final notifier = ref.read(characterPromptNotifierProvider.notifier);
    notifier.addCharacter();

    // 自动选中新添加的角色
    final characters = ref.read(characterListProvider);
    if (characters.isNotEmpty) {
      final newCharacterId = characters.last.id;
      onCharacterSelected?.call(newCharacterId);
    }
  }

  /// 上移角色
  void _moveCharacterUp(WidgetRef ref, int index) {
    ref.read(characterPromptNotifierProvider.notifier).moveCharacterUp(index);
  }

  /// 下移角色
  void _moveCharacterDown(WidgetRef ref, int index) {
    ref.read(characterPromptNotifierProvider.notifier).moveCharacterDown(index);
  }

  /// 删除角色
  Future<void> _deleteCharacter(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirmed = await _showDeleteConfirmDialog(context);
    if (confirmed == true) {
      ref.read(characterPromptNotifierProvider.notifier).removeCharacter(id);

      // 如果删除的是当前选中的角色，清除选择
      if (selectedCharacterId == id) {
        onCharacterSelected?.call(null);
      }
    }
  }

  /// 重新排序角色
  void _reorderCharacters(WidgetRef ref, int oldIndex, int newIndex) {
    ref
        .read(characterPromptNotifierProvider.notifier)
        .reorderCharacters(oldIndex, newIndex);
  }

  /// 显示删除确认对话框
  Future<bool?> _showDeleteConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除角色'),
        content: const Text('确定要删除这个角色吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}


/// 添加角色按钮
class _AddCharacterButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddCharacterButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.5),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: colorScheme.primary.withOpacity(0.05),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '添加角色',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 空状态提示
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无角色',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '点击上方按钮添加角色',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 角色列表组件（支持拖拽排序）
class _CharacterList extends StatelessWidget {
  final List<CharacterPrompt> characters;
  final String? selectedCharacterId;
  final ValueChanged<String?>? onCharacterSelected;
  final bool showActions;
  final ValueChanged<int> onMoveUp;
  final ValueChanged<int> onMoveDown;
  final ValueChanged<String> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _CharacterList({
    required this.characters,
    this.selectedCharacterId,
    this.onCharacterSelected,
    required this.showActions,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: characters.length,
      onReorder: onReorder,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final elevation = Tween<double>(begin: 0, end: 4).evaluate(animation);
            return Material(
              elevation: elevation,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final character = characters[index];
        final isSelected = character.id == selectedCharacterId;
        final canMoveUp = index > 0;
        final canMoveDown = index < characters.length - 1;

        return ReorderableDragStartListener(
          key: ValueKey(character.id),
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CharacterListItem(
              character: character,
              isSelected: isSelected,
              onTap: () => onCharacterSelected?.call(character.id),
              showActions: showActions && isSelected,
              canMoveUp: canMoveUp,
              canMoveDown: canMoveDown,
              onMoveUp: () => onMoveUp(index),
              onMoveDown: () => onMoveDown(index),
              onDelete: () => onDelete(character.id),
            ),
          ),
        );
      },
    );
  }
}
