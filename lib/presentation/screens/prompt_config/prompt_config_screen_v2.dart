import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/prompt/prompt_config.dart';
import '../../providers/prompt_config_provider.dart';
import '../../widgets/common/app_toast.dart';

/// 随机提示词配置页面 V2 - 分栏布局
class PromptConfigScreen extends ConsumerStatefulWidget {
  const PromptConfigScreen({super.key});

  @override
  ConsumerState<PromptConfigScreen> createState() => _PromptConfigScreenState();
}

class _PromptConfigScreenState extends ConsumerState<PromptConfigScreen> {
  String? _selectedPresetId;
  String? _selectedConfigId;
  bool _hasUnsavedChanges = false;

  // 编辑状态
  late TextEditingController _presetNameController;
  List<PromptConfig> _editingConfigs = [];

  @override
  void initState() {
    super.initState();
    _presetNameController = TextEditingController();
  }

  @override
  void dispose() {
    _presetNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(promptConfigNotifierProvider);
    final theme = Theme.of(context);

    // 初始化选中状态
    if (_selectedPresetId == null && state.presets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectPreset(state.selectedPresetId ?? state.presets.first.id);
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // 左侧预设列表
          _buildPresetPanel(state, theme),
          // 垂直分割线
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          // 中间配置组列表
          _buildConfigPanel(state, theme),
          // 垂直分割线
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          // 右侧详情编辑
          _buildDetailPanel(state, theme),
        ],
      ),
    );
  }

  // ==================== 左侧预设面板 ====================
  Widget _buildPresetPanel(PromptConfigState state, ThemeData theme) {
    return Container(
      width: 220,
      color: theme.colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '预设',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _buildPresetMenu(theme),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          // 预设列表
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.presets.isEmpty
                    ? _buildEmptyPresets(theme)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: state.presets.length,
                        itemBuilder: (context, index) {
                          final preset = state.presets[index];
                          return _buildPresetItem(preset, state, theme);
                        },
                      ),
          ),
          // 底部操作
          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: _createNewPreset,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建预设'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetMenu(ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      padding: EdgeInsets.zero,
      tooltip: '更多操作',
      onSelected: _handlePresetMenuAction,
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'import', child: Text('导入配置')),
        const PopupMenuItem(value: 'reset', child: Text('恢复默认')),
      ],
    );
  }

  Widget _buildEmptyPresets(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            '暂无预设',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => ref
                .read(promptConfigNotifierProvider.notifier)
                .resetToDefaults(),
            child: const Text('恢复默认'),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetItem(
    RandomPromptPreset preset,
    PromptConfigState state,
    ThemeData theme,
  ) {
    final isSelected = preset.id == _selectedPresetId;
    final isActive = preset.id == state.selectedPresetId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _selectPreset(preset.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 激活指示器
                if (isActive)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 16),
                // 预设名称
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${preset.configs.length} 个配置组',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                // 右键菜单
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (action) =>
                      _handlePresetItemAction(preset, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'activate',
                      enabled: !isActive,
                      child: const Text('设为当前'),
                    ),
                    const PopupMenuItem(value: 'duplicate', child: Text('复制')),
                    const PopupMenuItem(value: 'export', child: Text('导出')),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        '删除',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 中间配置组面板 ====================
  Widget _buildConfigPanel(PromptConfigState state, ThemeData theme) {
    final preset = _getSelectedPreset(state);

    return Container(
      width: 280,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.layers_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '配置组',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (preset != null)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: '添加配置组',
                    onPressed: _addConfig,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          // 预设名称编辑
          if (preset != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _presetNameController,
                decoration: InputDecoration(
                  labelText: '预设名称',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: theme.textTheme.bodyMedium,
                onChanged: (_) => _markChanged(),
              ),
            ),
          // 配置组列表
          Expanded(
            child: preset == null
                ? Center(
                    child: Text(
                      '选择一个预设',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  )
                : _editingConfigs.isEmpty
                    ? _buildEmptyConfigs(theme)
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        buildDefaultDragHandles: false,
                        itemCount: _editingConfigs.length,
                        onReorder: _reorderConfig,
                        itemBuilder: (context, index) {
                          final config = _editingConfigs[index];
                          return _buildConfigItem(config, index, theme);
                        },
                      ),
          ),
          // 保存按钮
          if (_hasUnsavedChanges && preset != null) ...[
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _savePreset,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('保存更改'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyConfigs(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            '还没有配置组',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addConfig,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加配置组'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(PromptConfig config, int index, ThemeData theme) {
    final isSelected = config.id == _selectedConfigId;

    return Padding(
      key: ValueKey(config.id),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _selectConfig(config.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 拖拽手柄
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(width: 8),
                // 启用开关
                SizedBox(
                  width: 36,
                  height: 20,
                  child: Switch(
                    value: config.enabled,
                    onChanged: (_) => _toggleConfigEnabled(index),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                // 配置信息
                Expanded(
                  child: Opacity(
                    opacity: config.enabled ? 1.0 : 0.5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getConfigSummary(config),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // 删除按钮
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.error.withOpacity(0.7),
                  ),
                  onPressed: () => _deleteConfig(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '删除',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 右侧详情面板 ====================
  Widget _buildDetailPanel(PromptConfigState state, ThemeData theme) {
    final config = _getSelectedConfig();

    return Expanded(
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: config == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 64,
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '选择一个配置组进行编辑',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              )
            : _ConfigDetailEditor(
                key: ValueKey(config.id),
                config: config,
                onChanged: (updated) => _updateConfig(updated),
              ),
      ),
    );
  }

  // ==================== 辅助方法 ====================
  RandomPromptPreset? _getSelectedPreset(PromptConfigState state) {
    if (_selectedPresetId == null) return null;
    try {
      return state.presets.firstWhere((p) => p.id == _selectedPresetId);
    } catch (_) {
      return null;
    }
  }

  PromptConfig? _getSelectedConfig() {
    if (_selectedConfigId == null) return null;
    try {
      return _editingConfigs.firstWhere((c) => c.id == _selectedConfigId);
    } catch (_) {
      return null;
    }
  }

  void _selectPreset(String presetId) {
    if (_hasUnsavedChanges) {
      _showUnsavedDialog(() => _doSelectPreset(presetId));
      return;
    }
    _doSelectPreset(presetId);
  }

  void _doSelectPreset(String presetId) {
    final state = ref.read(promptConfigNotifierProvider);
    final preset = state.presets.firstWhere((p) => p.id == presetId);
    setState(() {
      _selectedPresetId = presetId;
      _presetNameController.text = preset.name;
      _editingConfigs = List.from(preset.configs);
      // 默认选中第一个配置组
      _selectedConfigId =
          _editingConfigs.isNotEmpty ? _editingConfigs.first.id : null;
      _hasUnsavedChanges = false;
    });
  }

  void _selectConfig(String configId) {
    setState(() {
      _selectedConfigId = configId;
    });
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _createNewPreset() {
    if (_hasUnsavedChanges) {
      _showUnsavedDialog(_doCreateNewPreset);
      return;
    }
    _doCreateNewPreset();
  }

  void _doCreateNewPreset() async {
    final newPreset = RandomPromptPreset.create(name: '新预设');
    await ref.read(promptConfigNotifierProvider.notifier).addPreset(newPreset);
    _doSelectPreset(newPreset.id);
    AppToast.success(context, '已创建新预设');
  }

  void _addConfig() {
    final newConfig = PromptConfig.create(name: '新配置组');
    setState(() {
      _editingConfigs.add(newConfig);
      _selectedConfigId = newConfig.id;
      _hasUnsavedChanges = true;
    });
  }

  void _deleteConfig(int index) {
    setState(() {
      final removed = _editingConfigs.removeAt(index);
      if (_selectedConfigId == removed.id) {
        _selectedConfigId = null;
      }
      _hasUnsavedChanges = true;
    });
  }

  void _toggleConfigEnabled(int index) {
    setState(() {
      _editingConfigs[index] = _editingConfigs[index].copyWith(
        enabled: !_editingConfigs[index].enabled,
      );
      _hasUnsavedChanges = true;
    });
  }

  void _reorderConfig(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _editingConfigs.removeAt(oldIndex);
      _editingConfigs.insert(newIndex, item);
      _hasUnsavedChanges = true;
    });
  }

  void _updateConfig(PromptConfig updated) {
    final index = _editingConfigs.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      setState(() {
        _editingConfigs[index] = updated;
        _hasUnsavedChanges = true;
      });
    }
  }

  void _savePreset() async {
    if (_selectedPresetId == null) return;

    final state = ref.read(promptConfigNotifierProvider);
    final preset = state.presets.firstWhere((p) => p.id == _selectedPresetId);
    final updated = preset.copyWith(
      name: _presetNameController.text.trim(),
      configs: _editingConfigs,
      updatedAt: DateTime.now(),
    );

    await ref.read(promptConfigNotifierProvider.notifier).updatePreset(updated);
    setState(() => _hasUnsavedChanges = false);
    AppToast.success(context, '保存成功');
  }

  void _handlePresetMenuAction(String action) {
    switch (action) {
      case 'import':
        _showImportDialog();
        break;
      case 'reset':
        _showResetConfirmDialog();
        break;
    }
  }

  void _handlePresetItemAction(RandomPromptPreset preset, String action) {
    switch (action) {
      case 'activate':
        ref.read(promptConfigNotifierProvider.notifier).selectPreset(preset.id);
        AppToast.success(context, '已设为当前预设');
        break;
      case 'duplicate':
        ref
            .read(promptConfigNotifierProvider.notifier)
            .duplicatePreset(preset.id);
        AppToast.success(context, '已复制预设');
        break;
      case 'export':
        final json = ref
            .read(promptConfigNotifierProvider.notifier)
            .exportPreset(preset.id);
        Clipboard.setData(ClipboardData(text: json));
        AppToast.success(context, '已复制到剪贴板');
        break;
      case 'delete':
        _showDeletePresetDialog(preset);
        break;
    }
  }

  String _getConfigSummary(PromptConfig config) {
    final parts = <String>[];
    if (config.contentType == ContentType.string) {
      parts.add('${config.stringContents.length} 项');
    } else {
      parts.add('${config.nestedConfigs.length} 子配置');
    }
    parts.add(_getSelectionModeShort(config.selectionMode));
    return parts.join(' · ');
  }

  String _getSelectionModeShort(SelectionMode mode) {
    switch (mode) {
      case SelectionMode.singleRandom:
        return '随机';
      case SelectionMode.singleSequential:
        return '顺序';
      case SelectionMode.multipleCount:
        return '多选';
      case SelectionMode.multipleProbability:
        return '概率';
      case SelectionMode.all:
        return '全部';
    }
  }

  void _showUnsavedDialog(VoidCallback onDiscard) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的更改'),
        content: const Text('有未保存的更改，确定要放弃吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _hasUnsavedChanges = false);
              onDiscard();
            },
            child: const Text('放弃'),
          ),
        ],
      ),
    );
  }

  void _showDeletePresetDialog(RandomPromptPreset preset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除预设'),
        content: Text('确定要删除 "${preset.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(promptConfigNotifierProvider.notifier)
                  .deletePreset(preset.id);
              if (_selectedPresetId == preset.id) {
                setState(() {
                  _selectedPresetId = null;
                  _selectedConfigId = null;
                  _editingConfigs = [];
                });
              }
              AppToast.success(context, '已删除');
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入配置'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: '粘贴 JSON 配置...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(promptConfigNotifierProvider.notifier)
                    .importPreset(controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  AppToast.success(this.context, '导入成功');
                }
              } catch (e) {
                AppToast.error(this.context, '导入失败: $e');
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认'),
        content: const Text('确定要恢复默认预设吗？所有自定义配置将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(promptConfigNotifierProvider.notifier).resetToDefaults();
              setState(() {
                _selectedPresetId = null;
                _selectedConfigId = null;
                _editingConfigs = [];
                _hasUnsavedChanges = false;
              });
              AppToast.success(this.context, '已恢复默认');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

// ==================== 配置详情编辑器 ====================
class _ConfigDetailEditor extends StatefulWidget {
  final PromptConfig config;
  final ValueChanged<PromptConfig> onChanged;

  const _ConfigDetailEditor({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<_ConfigDetailEditor> createState() => _ConfigDetailEditorState();
}

class _ConfigDetailEditorState extends State<_ConfigDetailEditor> {
  late TextEditingController _nameController;
  late TextEditingController _contentsController;
  late SelectionMode _selectionMode;
  late int _selectCount;
  late double _selectProbability;
  late int _bracketMin;
  late int _bracketMax;
  late bool _shuffle;

  @override
  void initState() {
    super.initState();
    _initFromConfig();
  }

  @override
  void didUpdateWidget(_ConfigDetailEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.id != widget.config.id) {
      _initFromConfig();
    }
  }

  void _initFromConfig() {
    _nameController = TextEditingController(text: widget.config.name);
    _contentsController = TextEditingController(
      text: widget.config.stringContents.join('\n'),
    );
    _selectionMode = widget.config.selectionMode;
    _selectCount = widget.config.selectCount ?? 1;
    _selectProbability = widget.config.selectProbability ?? 0.5;
    _bracketMin = widget.config.bracketMin;
    _bracketMax = widget.config.bracketMax;
    _shuffle = widget.config.shuffle;
  }

  void _notifyChanged() {
    final stringContents = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    widget.onChanged(
      widget.config.copyWith(
        name: _nameController.text.trim(),
        selectionMode: _selectionMode,
        selectCount: _selectCount,
        selectProbability: _selectProbability,
        bracketMin: _bracketMin,
        bracketMax: _bracketMax,
        shuffle: _shuffle,
        stringContents: stringContents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(Icons.edit_note, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '编辑配置组',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 配置名称
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '配置名称',
              prefixIcon: const Icon(Icons.label_outline),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (_) => _notifyChanged(),
          ),
          const SizedBox(height: 24),

          // 选取方式 - 使用卡片式单选
          _buildSectionTitle(theme, '选取方式'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SelectionMode.values.map((mode) {
              final isSelected = _selectionMode == mode;
              return ChoiceChip(
                label: Text(_getSelectionModeName(mode)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectionMode = mode);
                    _notifyChanged();
                  }
                },
              );
            }).toList(),
          ),

          // 附加参数
          if (_selectionMode == SelectionMode.multipleCount) ...[
            const SizedBox(height: 16),
            _buildSliderRow(
              label: '选取数量',
              value: _selectCount.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              displayValue: '$_selectCount',
              onChanged: (v) {
                setState(() => _selectCount = v.toInt());
                _notifyChanged();
              },
            ),
          ],
          if (_selectionMode == SelectionMode.multipleProbability) ...[
            const SizedBox(height: 16),
            _buildSliderRow(
              label: '选取概率',
              value: _selectProbability,
              min: 0.05,
              max: 1.0,
              divisions: 19,
              displayValue: '${(_selectProbability * 100).toInt()}%',
              onChanged: (v) {
                setState(() => _selectProbability = v);
                _notifyChanged();
              },
            ),
          ],
          if (_selectionMode == SelectionMode.multipleProbability ||
              _selectionMode == SelectionMode.all) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('打乱顺序'),
              subtitle: const Text('随机排列选中的内容'),
              value: _shuffle,
              onChanged: (v) {
                setState(() => _shuffle = v);
                _notifyChanged();
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // 权重括号
          _buildSectionTitle(theme, '权重括号'),
          const SizedBox(height: 8),
          Text(
            '每层 {} 括号增加约 5% 权重',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSliderRow(
                  label: '最少',
                  value: _bracketMin.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  displayValue: '$_bracketMin',
                  onChanged: (v) {
                    setState(() {
                      _bracketMin = v.toInt();
                      if (_bracketMax < _bracketMin) _bracketMax = _bracketMin;
                    });
                    _notifyChanged();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSliderRow(
                  label: '最多',
                  value: _bracketMax.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  displayValue: '$_bracketMax',
                  onChanged: (v) {
                    setState(() {
                      _bracketMax = v.toInt();
                      if (_bracketMin > _bracketMax) _bracketMin = _bracketMax;
                    });
                    _notifyChanged();
                  },
                ),
              ),
            ],
          ),
          if (_bracketMin > 0 || _bracketMax > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.preview,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '预览: ${_getBracketPreview()}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // 标签内容
          _buildSectionTitle(theme, '标签内容'),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '每行一个标签，当前 ${_contentsController.text.split('\n').where((s) => s.trim().isNotEmpty).length} 项',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _formatContents,
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('格式化'),
                style:
                    TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              TextButton.icon(
                onPressed: _sortContents,
                icon: const Icon(Icons.sort_by_alpha, size: 16),
                label: const Text('排序'),
                style:
                    TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contentsController,
            maxLines: 15,
            minLines: 8,
            decoration: InputDecoration(
              hintText: '输入标签，每行一个...\n例如：\n1girl\nbeautiful eyes\nlong hair',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            onChanged: (_) {
              setState(() {});
              _notifyChanged();
            },
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(displayValue, textAlign: TextAlign.end),
        ),
      ],
    );
  }

  String _getSelectionModeName(SelectionMode mode) {
    switch (mode) {
      case SelectionMode.singleRandom:
        return '随机单选';
      case SelectionMode.singleSequential:
        return '顺序单选';
      case SelectionMode.multipleCount:
        return '指定数量';
      case SelectionMode.multipleProbability:
        return '按概率';
      case SelectionMode.all:
        return '全部';
    }
  }

  String _getBracketPreview() {
    final examples = <String>[];
    for (int i = _bracketMin; i <= _bracketMax; i++) {
      examples.add('${'{' * i}tag${'}' * i}');
    }
    return examples.join(' 或 ');
  }

  void _formatContents() {
    final lines = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _contentsController.text = lines.join('\n');
    _notifyChanged();
  }

  void _sortContents() {
    final lines = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();
    _contentsController.text = lines.join('\n');
    _notifyChanged();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentsController.dispose();
    super.dispose();
  }
}
