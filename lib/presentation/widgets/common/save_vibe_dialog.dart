import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'app_toast.dart';

/// 保存 Vibe 到库对话框
///
/// 用于将 Vibe 数据保存到 Vibe 库中
class SaveVibeDialog extends ConsumerStatefulWidget {
  /// 单个 Vibe
  final VibeReference vibe;

  /// 多个 Vibes（可选，用于保存组合）
  final List<VibeReference>? vibes;

  /// 默认名称
  final String? defaultName;

  const SaveVibeDialog({
    super.key,
    required this.vibe,
    this.vibes,
    this.defaultName,
  });

  /// 显示对话框
  static Future<bool> show(
    BuildContext context, {
    required VibeReference vibe,
    List<VibeReference>? vibes,
    String? defaultName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SaveVibeDialog(
        vibe: vibe,
        vibes: vibes,
        defaultName: defaultName,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<SaveVibeDialog> createState() => _SaveVibeDialogState();
}

class _SaveVibeDialogState extends ConsumerState<SaveVibeDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _tagController;
  String? _selectedCategoryId;
  final List<String> _tags = [];
  bool _isSaving = false;
  bool _saveAsBundle = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.defaultName ?? widget.vibe.displayName,
    );
    _tagController = TextEditingController();

    // 如果有多个 vibes，默认启用保存为组合
    if (widget.vibes != null && widget.vibes!.length > 1) {
      _saveAsBundle = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    if (_tags.contains(tag)) {
      AppToast.warning(context, '标签已存在');
      return;
    }
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToast.warning(context, '请输入名称');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(vibeLibraryNotifierProvider.notifier);
      final isBundle =
          widget.vibes != null && widget.vibes!.length > 1 && _saveAsBundle;

      if (isBundle) {
        // 保存为组合
        final result = await notifier.saveBundleEntry(
          widget.vibes!,
          name: name,
          categoryId: _selectedCategoryId,
          tags: _tags,
        );
        if (result == null) {
          throw Exception('保存组合失败');
        }
      } else {
        // 保存单个条目
        final entry = VibeLibraryEntry.fromVibeReference(
          name: name,
          vibeData: widget.vibe,
          categoryId: _selectedCategoryId,
          tags: _tags,
          thumbnail: widget.vibe.thumbnail,
        );
        final result = await notifier.saveEntry(entry);
        if (result == null) {
          throw Exception('保存条目失败');
        }
      }

      if (mounted) {
        AppToast.success(context, '已保存到 Vibe 库');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '保存失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    // 监听分类列表
    final categories = ref.watch(
      vibeLibraryNotifierProvider.select((s) => s.categories),
    );

    final hasMultipleVibes = widget.vibes != null && widget.vibes!.length > 1;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.style_outlined,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('保存到 Vibe 库'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 名称输入
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '输入 Vibe 名称',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                enabled: !_isSaving,
              ),
              const SizedBox(height: 16),

              // 分类选择
              if (categories.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('未分类'),
                    ),
                    ...categories.map((category) {
                      return DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(category.displayName),
                      );
                    }),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _selectedCategoryId = value;
                          });
                        },
                ),
              if (categories.isNotEmpty) const SizedBox(height: 16),

              // 保存为组合选项（仅当有多个 vibes 时显示）
              if (hasMultipleVibes)
                CheckboxListTile(
                  title: const Text('保存为组合'),
                  subtitle: Text('将 ${widget.vibes!.length} 个 Vibe 保存为一个组合'),
                  value: _saveAsBundle,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _saveAsBundle = value ?? false;
                          });
                        },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              if (hasMultipleVibes) const SizedBox(height: 16),

              // 标签输入
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      decoration: const InputDecoration(
                        labelText: '标签',
                        hintText: '输入标签后按添加',
                        prefixIcon: Icon(Icons.tag),
                      ),
                      enabled: !_isSaving,
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSaving ? null : _addTag,
                    icon: const Icon(Icons.add),
                    tooltip: '添加标签',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 标签列表
              if (_tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: _isSaving ? null : () => _removeTag(tag),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),

              // Vibe 信息预览
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vibe 信息',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      context,
                      label: '名称',
                      value: widget.vibe.displayName,
                    ),
                    _buildInfoRow(
                      context,
                      label: 'Strength',
                      value:
                          '${(widget.vibe.strength * 100).toStringAsFixed(0)}%',
                    ),
                    _buildInfoRow(
                      context,
                      label: 'Info',
                      value:
                          '${(widget.vibe.infoExtracted * 100).toStringAsFixed(0)}%',
                    ),
                    _buildInfoRow(
                      context,
                      label: '来源',
                      value: widget.vibe.sourceType.displayLabel,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
