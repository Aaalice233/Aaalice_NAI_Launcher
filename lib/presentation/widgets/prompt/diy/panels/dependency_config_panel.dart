import 'package:flutter/material.dart';

import '../../../../../data/models/prompt/dependency_config.dart';

/// 依赖配置面板
///
/// 用于配置标签选择的依赖关系
class DependencyConfigPanel extends StatefulWidget {
  /// 当前配置
  final DependencyConfig? config;

  /// 配置变更回调
  final ValueChanged<DependencyConfig?> onConfigChanged;

  /// 可选的源类别列表
  final List<String> availableCategories;

  /// 是否只读
  final bool readOnly;

  const DependencyConfigPanel({
    super.key,
    this.config,
    required this.onConfigChanged,
    this.availableCategories = const [],
    this.readOnly = false,
  });

  @override
  State<DependencyConfigPanel> createState() => _DependencyConfigPanelState();
}

class _DependencyConfigPanelState extends State<DependencyConfigPanel> {
  late DependencyConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config ??
        const DependencyConfig(sourceCategoryId: '');
  }

  @override
  void didUpdateWidget(DependencyConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _config = widget.config ??
          const DependencyConfig(sourceCategoryId: '');
    }
  }

  void _updateConfig(DependencyConfig newConfig) {
    setState(() {
      _config = newConfig;
    });
    widget.onConfigChanged(newConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildTypeSelector(),
        const SizedBox(height: 16),
        _buildSourceCategorySelector(),
        const SizedBox(height: 16),
        _buildMappingRulesEditor(),
        const SizedBox(height: 16),
        _buildDefaultValueField(),
        const SizedBox(height: 16),
        _buildEnabledSwitch(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.link),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '依赖配置',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (widget.config != null && !widget.readOnly)
          TextButton.icon(
            onPressed: () => widget.onConfigChanged(null),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('清除'),
          ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '依赖类型',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: DependencyType.values.map((type) {
                return ChoiceChip(
                  label: Text(_getDependencyTypeLabel(type)),
                  selected: _config.type == type,
                  onSelected: widget.readOnly
                      ? null
                      : (selected) {
                          if (selected) {
                            _updateConfig(_config.copyWith(type: type));
                          }
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              _getDependencyTypeDescription(_config.type),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCategorySelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '源类别',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (widget.availableCategories.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _config.sourceCategoryId.isNotEmpty
                    ? _config.sourceCategoryId
                    : null,
                decoration: const InputDecoration(
                  hintText: '选择源类别',
                  border: OutlineInputBorder(),
                ),
                items: widget.availableCategories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: widget.readOnly
                    ? null
                    : (value) {
                        if (value != null) {
                          _updateConfig(
                            _config.copyWith(sourceCategoryId: value),
                          );
                        }
                      },
              )
            else
              TextFormField(
                initialValue: _config.sourceCategoryId,
                decoration: const InputDecoration(
                  labelText: '源类别 ID',
                  hintText: '输入类别 ID',
                  border: OutlineInputBorder(),
                ),
                readOnly: widget.readOnly,
                onChanged: (value) {
                  _updateConfig(_config.copyWith(sourceCategoryId: value));
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMappingRulesEditor() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '映射规则',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (!widget.readOnly)
                  TextButton.icon(
                    onPressed: _addMappingRule,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_config.mappingRules.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '暂无映射规则',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _config.mappingRules.length,
                itemBuilder: (context, index) {
                  final entry = _config.mappingRules.entries.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text('${entry.key} → ${entry.value}'),
                    trailing: widget.readOnly
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _removeMappingRule(entry.key),
                          ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultValueField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          initialValue: _config.defaultValue ?? '',
          decoration: const InputDecoration(
            labelText: '默认值',
            hintText: '当没有匹配规则时使用',
            border: OutlineInputBorder(),
          ),
          readOnly: widget.readOnly,
          onChanged: (value) {
            _updateConfig(_config.copyWith(
              defaultValue: value.isEmpty ? null : value,
            ));
          },
        ),
      ),
    );
  }

  Widget _buildEnabledSwitch() {
    return Card(
      child: SwitchListTile(
        title: const Text('启用依赖配置'),
        subtitle: const Text('禁用后此配置不会生效'),
        value: _config.enabled,
        onChanged: widget.readOnly
            ? null
            : (value) {
                _updateConfig(_config.copyWith(enabled: value));
              },
      ),
    );
  }

  void _addMappingRule() {
    showDialog(
      context: context,
      builder: (context) {
        String key = '';
        String value = '';

        return AlertDialog(
          title: const Text('添加映射规则'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: '源值',
                  hintText: '例如: 1, 2, 3',
                ),
                onChanged: (v) => key = v,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: '结果值',
                  hintText: '例如: 0-3, 0-2, 0-1',
                ),
                onChanged: (v) => value = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (key.isNotEmpty && value.isNotEmpty) {
                  final newRules = Map<String, String>.from(_config.mappingRules);
                  newRules[key] = value;
                  _updateConfig(_config.copyWith(mappingRules: newRules));
                }
                Navigator.pop(context);
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  void _removeMappingRule(String key) {
    final newRules = Map<String, String>.from(_config.mappingRules);
    newRules.remove(key);
    _updateConfig(_config.copyWith(mappingRules: newRules));
  }

  String _getDependencyTypeLabel(DependencyType type) {
    switch (type) {
      case DependencyType.count:
        return '数量依赖';
      case DependencyType.exists:
        return '存在依赖';
      case DependencyType.value:
        return '值依赖';
      case DependencyType.excludes:
        return '排斥依赖';
    }
  }

  String _getDependencyTypeDescription(DependencyType type) {
    switch (type) {
      case DependencyType.count:
        return '选择数量依赖源类别的结果数量';
      case DependencyType.exists:
        return '只有当源类别有选中标签时才生效';
      case DependencyType.value:
        return '依赖源类别的特定标签值';
      case DependencyType.excludes:
        return '当源类别有选中标签时不生效';
    }
  }
}
