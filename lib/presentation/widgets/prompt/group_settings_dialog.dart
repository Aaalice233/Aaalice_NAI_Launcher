import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/prompt/random_tag_group.dart';
import '../../../data/models/prompt/weighted_tag.dart';

/// 分组设置对话框
///
/// 配置单个标签分组的设置项：
/// - 选取概率
/// - 选择模式
/// - 词库标签编辑
class GroupSettingsDialog extends ConsumerStatefulWidget {
  final RandomTagGroup group;

  const GroupSettingsDialog({
    super.key,
    required this.group,
  });

  static Future<RandomTagGroup?> show(
    BuildContext context, {
    required RandomTagGroup group,
  }) {
    return showDialog<RandomTagGroup>(
      context: context,
      builder: (context) => GroupSettingsDialog(group: group),
    );
  }

  @override
  ConsumerState<GroupSettingsDialog> createState() =>
      _GroupSettingsDialogState();
}

class _GroupSettingsDialogState extends ConsumerState<GroupSettingsDialog> {
  late RandomTagGroup _group;
  late TextEditingController _nameController;
  late TextEditingController _multipleNumController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _nameController = TextEditingController(text: _group.name);
    _multipleNumController =
        TextEditingController(text: _group.multipleNum.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _multipleNumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_group.name} 设置',
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_group.isSyncable)
                          Text(
                            '来源: ${_group.sourceTypeDisplayName}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_group.isSyncable)
                    TextButton.icon(
                      onPressed: _syncFromSource,
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('同步'),
                    ),
                  TextButton(
                    onPressed: _resetGroup,
                    child: const Text('重置'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 基本设置
                    _buildSectionTitle('基本设置', theme),
                    const SizedBox(height: 8),
                    _buildBasicSettings(theme),

                    const SizedBox(height: 24),

                    // 词库编辑
                    _buildSectionTitle('词库编辑', theme),
                    const SizedBox(height: 8),
                    _TagListEditor(
                      tags: _group.tags,
                      onChanged: (newTags) {
                        setState(() {
                          _group = _group.copyWith(tags: newTags);
                          _hasChanges = true;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 底部按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _hasChanges ? _saveChanges : null,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBasicSettings(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 名称
            ListTile(
              title: const Text('名称'),
              trailing: SizedBox(
                width: 200,
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _group = _group.copyWith(name: value);
                    _hasChanges = true;
                  },
                ),
              ),
            ),

            const Divider(),

            // 选取概率
            ListTile(
              title: const Text('选取概率'),
              subtitle: Text('${(_group.probability * 100).round()}%'),
              trailing: SizedBox(
                width: 200,
                child: Slider(
                  value: _group.probability,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label: '${(_group.probability * 100).round()}%',
                  onChanged: (value) {
                    setState(() {
                      _group = _group.copyWith(probability: value);
                      _hasChanges = true;
                    });
                  },
                ),
              ),
            ),

            // 选择模式
            ListTile(
              title: const Text('选择模式'),
              trailing: SizedBox(
                width: 180,
                child: DropdownButtonFormField<SelectionMode>(
                  value: _group.selectionMode,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: SelectionMode.values.map((mode) {
                    return DropdownMenuItem(
                      value: mode,
                      child: Text(_getSelectionModeLabel(mode)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _group = _group.copyWith(selectionMode: value);
                        _hasChanges = true;
                      });
                    }
                  },
                ),
              ),
            ),

            // 多选数量（仅 multipleNum 模式显示）
            if (_group.selectionMode == SelectionMode.multipleNum)
              ListTile(
                title: const Text('选择数量'),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _multipleNumController,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final num = int.tryParse(value) ?? 1;
                      _group = _group.copyWith(multipleNum: num);
                      _hasChanges = true;
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getSelectionModeLabel(SelectionMode mode) {
    return switch (mode) {
      SelectionMode.single => '单选（加权随机）',
      SelectionMode.all => '全选',
      SelectionMode.multipleNum => '多选指定数量',
      SelectionMode.multipleProb => '概率独立判断',
      SelectionMode.sequential => '顺序轮替',
    };
  }

  void _resetGroup() {
    setState(() {
      _group = _group.copyWith(
        name: widget.group.name, // 恢复原始名称
        probability: 1.0,
        selectionMode: SelectionMode.single,
        multipleNum: 1,
        tags: [],
      );
      _nameController.text = widget.group.name;
      _multipleNumController.text = '1';
      _hasChanges = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已重置为默认配置')),
    );
  }

  Future<void> _syncFromSource() async {
    // TODO: 实现从 Danbooru 同步标签
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('同步功能开发中')),
    );
  }

  void _saveChanges() {
    Navigator.of(context).pop(_group);
  }
}

/// 标签列表编辑器
class _TagListEditor extends StatefulWidget {
  final List<WeightedTag> tags;
  final ValueChanged<List<WeightedTag>> onChanged;

  const _TagListEditor({
    required this.tags,
    required this.onChanged,
  });

  @override
  State<_TagListEditor> createState() => _TagListEditorState();
}

class _TagListEditorState extends State<_TagListEditor> {
  late List<WeightedTag> _tags;
  final _newTagController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.tags);
  }

  @override
  void didUpdateWidget(covariant _TagListEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果外部数据发生变化，同步更新内部状态
    if (oldWidget.tags != widget.tags) {
      _tags = List.from(widget.tags);
    }
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  List<WeightedTag> get _filteredTags {
    if (_searchQuery.isEmpty) return _tags;
    return _tags
        .where((t) => t.tag.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          // 工具栏
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 搜索框
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜索标签...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 添加按钮
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: _showAddTagDialog,
                  tooltip: '添加标签',
                ),
                IconButton(
                  icon: const Icon(Icons.content_paste),
                  onPressed: _importFromClipboard,
                  tooltip: '从剪贴板导入',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 表头
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '标签',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '权重',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // 删除按钮空间
              ],
            ),
          ),

          const Divider(height: 1),

          // 标签列表
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: _filteredTags.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _searchQuery.isEmpty ? '暂无标签，点击 + 添加' : '未找到匹配的标签',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredTags.length,
                    itemBuilder: (context, index) {
                      final tag = _filteredTags[index];
                      return _buildTagTile(tag, theme);
                    },
                  ),
          ),

          // 统计
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '共 ${_tags.length} 个标签',
                  style: theme.textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: _tags.isEmpty ? null : _clearAllTags,
                  child: const Text('清空全部'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagTile(WeightedTag tag, ThemeData theme) {
    return ListTile(
      dense: true,
      title: Text(tag.tag),
      subtitle: tag.translation != null ? Text(tag.translation!) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 权重
          SizedBox(
            width: 60,
            child: TextFormField(
              key: ValueKey('${tag.tag}_${tag.weight}'),
              initialValue: tag.weight.toString(),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onFieldSubmitted: (value) {
                final newWeight = int.tryParse(value) ?? 1;
                _updateTagWeight(tag, newWeight);
              },
            ),
          ),
          const SizedBox(width: 8),
          // 删除按钮
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _removeTag(tag),
          ),
        ],
      ),
    );
  }

  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: _newTagController,
          decoration: const InputDecoration(
            hintText: '输入标签名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (_) => _addNewTag(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _addNewTag,
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _addNewTag() {
    final tagName = _newTagController.text.trim();
    if (tagName.isEmpty) return;

    // 检查标签是否已存在
    if (_tags.any((t) => t.tag == tagName)) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('标签已存在: $tagName')),
      );
      return;
    }

    setState(() {
      _tags.add(WeightedTag(tag: tagName, weight: 1));
    });
    widget.onChanged(_tags);
    _newTagController.clear();
    Navigator.of(context).pop();
  }

  void _removeTag(WeightedTag tag) {
    setState(() {
      _tags.remove(tag);
    });
    widget.onChanged(_tags);
  }

  void _updateTagWeight(WeightedTag tag, int newWeight) {
    final index = _tags.indexOf(tag);
    if (index == -1) return;

    setState(() {
      _tags[index] = tag.copyWith(weight: newWeight);
    });
    widget.onChanged(_tags);
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;

    // 按逗号或换行分割
    final tags = data!.text!
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (tags.isEmpty) return;

    setState(() {
      for (final tagName in tags) {
        if (!_tags.any((t) => t.tag == tagName)) {
          _tags.add(WeightedTag(tag: tagName, weight: 1));
        }
      }
    });
    widget.onChanged(_tags);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${tags.length} 个标签')),
      );
    }
  }

  void _clearAllTags() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空全部标签'),
        content: const Text('确定要清空该分组下的所有标签吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _tags.clear());
              widget.onChanged(_tags);
              Navigator.of(context).pop();
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}
