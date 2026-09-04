import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/file_export_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/file_name_sanitizer.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_export_utils.dart';
import '../../../../data/models/vibe/vibe_library_category.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';

import '../../../adaptive/adaptive_presenter.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../providers/generation/generation_params_notifier.dart';
import '../../../widgets/common/app_toast.dart';

double _compactControlExtent(BuildContext context) =>
    context.interactionPolicy.shouldExposeTouchAlternatives ? 48 : 32;
VisualDensity _compactControlDensity(BuildContext context) =>
    context.interactionPolicy.shouldExposeTouchAlternatives
    ? VisualDensity.standard
    : VisualDensity.compact;

/// Vibe 导出格式枚举
enum VibeExportFormat {
  /// 单个 .naiv4vibe 文件
  single,

  /// 打包为 .naiv4vibebundle 文件
  bundle,

  /// 嵌入到 PNG 图片
  embeddedPng,
}

extension VibeExportFormatExtension on VibeExportFormat {
  String displayName(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case VibeExportFormat.single:
        return l10n.vibe_export_singleFile;
      case VibeExportFormat.bundle:
        return l10n.vibe_export_bundleFile;
      case VibeExportFormat.embeddedPng:
        return l10n.vibe_export_embedIntoPng;
    }
  }

  String get fileExtension {
    switch (this) {
      case VibeExportFormat.single:
        return 'naiv4vibe';
      case VibeExportFormat.bundle:
        return 'naiv4vibebundle';
      case VibeExportFormat.embeddedPng:
        return 'png';
    }
  }

  String description(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case VibeExportFormat.single:
        return l10n.vibe_export_singleFileDescription;
      case VibeExportFormat.bundle:
        return l10n.vibe_export_bundleFileDescription;
      case VibeExportFormat.embeddedPng:
        return l10n.vibe_export_embedIntoPngDescription;
    }
  }
}

/// Vibe 导出对话框
class VibeExportDialog extends ConsumerStatefulWidget {
  final List<VibeLibraryEntry> entries;
  final List<VibeLibraryCategory> categories;

  const VibeExportDialog({
    super.key,
    required this.entries,
    required this.categories,
  });

  static Future<void> show(
    BuildContext context, {
    required List<VibeLibraryEntry> entries,
    required List<VibeLibraryCategory> categories,
  }) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            Icons.waves_outlined,
            color: Theme.of(panelContext).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              panelContext.l10n.vibe_export_title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                panelContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      width: 650,
      builder: (_, __) =>
          VibeExportDialog(entries: entries, categories: categories),
    );
  }

  @override
  ConsumerState<VibeExportDialog> createState() => _VibeExportDialogState();
}

class _VibeExportDialogState extends ConsumerState<VibeExportDialog> {
  VibeExportFormat _exportFormat = VibeExportFormat.single;
  bool _includeThumbnails = true;
  bool _isExporting = false;
  double _progress = 0;
  String _progressMessage = '';

  String get _defaultModel => ref.read(generationParamsNotifierProvider).model;
  String? _selectedCarrierImageId;
  Uint8List? _selectedExternalCarrierImageBytes;
  String? _selectedExternalCarrierImagePath;
  String? _carrierImageErrorMessage;

  // 选中的条目和分类
  final Set<String> _selectedEntryIds = {};
  final Set<String> _selectedCategoryIds = {};

  // 展开的分类
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    // 默认全选所有条目和分类
    _selectedEntryIds.addAll(
      widget.entries.where((e) => _canExportEntry(e)).map((e) => e.id),
    );
    _selectedCategoryIds.addAll(widget.categories.map((c) => c.id));
    // 默认展开所有有子项的分类
    for (final category in widget.categories) {
      if (category.parentId == null) {
        _expandedCategories.add(category.id);
      }
    }
    // 如果有未分类的条目，默认展开未分类
    final hasUncategorized = widget.entries.any(
      (e) => e.categoryId == null && _canExportEntry(e),
    );
    if (hasUncategorized) {
      _expandedCategories.add('__uncategorized__');
    }
    _ensureDefaultCarrierSelection();
  }

  bool get _supportsEmbeddedPng => widget.entries.length == 1;

  VibeLibraryEntry? get _singleExportEntry =>
      _supportsEmbeddedPng ? widget.entries.first : null;

  List<VibeExportImageCandidate> get _carrierImageOptions {
    final entry = _singleExportEntry;
    if (entry == null) {
      return const <VibeExportImageCandidate>[];
    }
    return VibeExportUtils.collectImageCandidates(entry)
        .where((candidate) => _isPngBytes(candidate.bytes))
        .toList(growable: false);
  }

  List<VibeExportFormat> get _availableFormats {
    return VibeExportFormat.values
        .where(
          (format) =>
              format != VibeExportFormat.embeddedPng || _supportsEmbeddedPng,
        )
        .toList(growable: false);
  }

  void _ensureDefaultCarrierSelection() {
    final options = _carrierImageOptions;
    if (options.isEmpty) {
      _selectedCarrierImageId = null;
      return;
    }
    if (_selectedCarrierImageId == null ||
        !options.any((option) => option.id == _selectedCarrierImageId)) {
      _selectedCarrierImageId = options.first.id;
    }
  }

  /// 检查条目是否可以导出（是否有可导出的数据）
  bool _canExportEntry(VibeLibraryEntry entry) {
    return entry.vibeEncoding.isNotEmpty ||
        (entry.rawImageData != null && entry.rawImageData!.isNotEmpty) ||
        (entry.vibeThumbnail != null && entry.vibeThumbnail!.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        key: const Key('vibe-export-dialog-frame'),
        padding: EdgeInsets.all(constraints.maxWidth < 380 ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isExporting) ...[
              // 导出进度
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 12),
              Text(
                _progressMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ] else ...[
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 统计信息
                      _buildStatsBar(theme),

                      const SizedBox(height: 16),

                      // 导出格式选择
                      _buildFormatSelection(theme),

                      const SizedBox(height: 16),

                      // 全选/全不选按钮
                      _buildSelectionActions(theme),

                      const SizedBox(height: 8),

                      // 选择列表与其余选项共用滚动视口，避免 IME 压缩时溢出。
                      _buildSelectionList(theme),

                      const Divider(height: 24),

                      if (_exportFormat != VibeExportFormat.embeddedPng) ...[
                        CheckboxListTile(
                          title: Text(
                            context.l10n.vibe_export_include_thumbnails,
                          ),
                          subtitle: Text(
                            context
                                .l10n
                                .vibe_export_include_thumbnails_subtitle,
                          ),
                          value: _includeThumbnails,
                          onChanged: (value) {
                            setState(() => _includeThumbnails = value ?? true);
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                        const SizedBox(height: 16),
                      ],

                      _buildDialogActions(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDialogActions() {
    final cancel = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text(context.l10n.common_cancel),
    );
    final export = FilledButton.icon(
      onPressed: _selectedEntryIds.isEmpty ? null : _export,
      icon: const Icon(Icons.file_download),
      label: Text(
        context.l10n.vibe_export_exportSelected(_selectedEntryIds.length),
        textAlign: TextAlign.center,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            key: const Key('vibe-export-compact-actions'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [cancel, const SizedBox(height: 8), export],
          );
        }
        return Row(
          key: const Key('vibe-export-actions'),
          mainAxisAlignment: MainAxisAlignment.end,
          children: [cancel, const SizedBox(width: 8), export],
        );
      },
    );
  }

  /// 构建统计信息栏
  Widget _buildStatsBar(ThemeData theme) {
    final exportableCount = widget.entries
        .where((e) => _canExportEntry(e))
        .length;
    final unexportableCount = widget.entries.length - exportableCount;

    final exportable = _StatItem(
      label: context.l10n.vibe_export_exportable,
      value: '${_selectedEntryIds.length}/$exportableCount',
      icon: Icons.check_circle_outline,
      color: theme.colorScheme.primary,
    );
    final unexportable = _StatItem(
      label: context.l10n.vibe_export_notExportable,
      value: '$unexportableCount',
      icon: Icons.error_outline,
      color: theme.colorScheme.error,
    );
    final categories = _StatItem(
      label: context.l10n.common_category,
      value: '${_selectedCategoryIds.length}/${widget.categories.length}',
      icon: Icons.folder_outlined,
      color: theme.colorScheme.outline,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                exportable,
                if (unexportableCount > 0) unexportable,
                categories,
              ],
            );
          }
          return Row(
            children: [
              exportable,
              const SizedBox(width: 24),
              if (unexportableCount > 0) unexportable,
              const Spacer(),
              categories,
            ],
          );
        },
      ),
    );
  }

  /// 构建格式选择区域
  Widget _buildFormatSelection(ThemeData theme) {
    final formats = _availableFormats;

    return RadioGroup<VibeExportFormat>(
      groupValue: _exportFormat,
      onChanged: (value) {
        if (value != null) {
          _setExportFormat(value);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.vibe_export_format,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...formats.map((format) {
            final isSelected = _exportFormat == format;
            return InkWell(
              onTap: () => _setExportFormat(format),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected
                      ? theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        )
                      : theme.colorScheme.surfaceContainer,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Radio<VibeExportFormat>(value: format),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                format.displayName(context),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                format.description(context),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isSelected &&
                        format == VibeExportFormat.embeddedPng) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      _buildEmbeddedPngOptions(theme),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmbeddedPngOptions(ThemeData theme) {
    final options = _carrierImageOptions;
    final selectedId =
        options.any((option) => option.id == _selectedCarrierImageId)
        ? _selectedCarrierImageId
        : (options.isNotEmpty ? options.first.id : null);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (options.isNotEmpty) ...[
          Text(
            context.l10n.vibe_export_pngCarrierImage,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selectedId,
            items: options
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option.id,
                    child: Text(option.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              setState(() {
                _selectedCarrierImageId = value;
                _selectedExternalCarrierImageBytes = null;
                _selectedExternalCarrierImagePath = null;
                _carrierImageErrorMessage = null;
              });
            },
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Text(
            context.l10n.vibe_export_noUsablePngCarrier,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _pickCarrierImage,
              icon: const Icon(Icons.image_search_outlined),
              label: Text(
                _selectedExternalCarrierImagePath == null
                    ? context.l10n.vibe_export_selectExternalPngImage
                    : context.l10n.vibe_export_changeExternalPngImage,
              ),
            ),
            if (_selectedExternalCarrierImagePath != null && options.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedExternalCarrierImageBytes = null;
                    _selectedExternalCarrierImagePath = null;
                    _carrierImageErrorMessage = null;
                  });
                },
                child: Text(context.l10n.vibe_export_useVibeImageInstead),
              ),
          ],
        ),
        if (_selectedExternalCarrierImagePath != null) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.vibe_export_usingExternalPng(
              _fileNameFromPath(_selectedExternalCarrierImagePath!),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (_carrierImageErrorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _carrierImageErrorMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  void _setExportFormat(VibeExportFormat format) {
    setState(() {
      _exportFormat = format;
      if (format == VibeExportFormat.embeddedPng) {
        _ensureDefaultCarrierSelection();
      }
    });
  }

  Future<void> _pickCarrierImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png'],
        dialogTitle: context.l10n.vibe_export_selectPngImage,
        withData: true,
      );

      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final bytes =
          file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);

      if (bytes == null || !_isPngBytes(bytes)) {
        setState(() {
          _selectedExternalCarrierImageBytes = null;
          _selectedExternalCarrierImagePath = null;
          _carrierImageErrorMessage = context.l10n.vibe_export_invalidPngImage;
        });
        return;
      }

      setState(() {
        _selectedExternalCarrierImageBytes = bytes;
        _selectedExternalCarrierImagePath = file.path ?? file.name;
        _carrierImageErrorMessage = null;
      });
    } catch (e, stack) {
      AppLogger.e('选择 PNG 载体图失败', e, stack, 'VibeExportDialog');
      if (mounted) {
        setState(
          () => _carrierImageErrorMessage = context.l10n
              .vibe_export_selectPngImageFailed(e.toString()),
        );
      }
    }
  }

  Uint8List? _currentCarrierImageBytes(VibeLibraryEntry entry) {
    if (_selectedExternalCarrierImageBytes != null) {
      return _selectedExternalCarrierImageBytes;
    }

    final options = VibeExportUtils.collectImageCandidates(entry);
    if (options.isEmpty) {
      return null;
    }

    final selectedId = _selectedCarrierImageId;
    if (selectedId != null) {
      for (final option in options) {
        if (option.id == selectedId) {
          return option.bytes;
        }
      }
    }

    return options.first.bytes;
  }

  bool _isPngBytes(Uint8List bytes) {
    const pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < pngSignature.length) {
      return false;
    }
    for (var i = 0; i < pngSignature.length; i++) {
      if (bytes[i] != pngSignature[i]) {
        return false;
      }
    }
    return true;
  }

  String _fileNameFromPath(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isEmpty ? path : segments.last;
  }

  String _embeddedPngFileName(VibeLibraryEntry entry) {
    final baseName = entry.displayName.trim().isEmpty
        ? 'vibe'
        : entry.displayName.trim();
    final safeBaseName = FileNameSanitizer.sanitize(baseName, fallback: 'vibe');
    return '${safeBaseName}_vibe.png';
  }

  /// 构建选择操作按钮
  Widget _buildSelectionActions(ThemeData theme) {
    final exportableEntries = widget.entries
        .where((e) => _canExportEntry(e))
        .toList();
    final allEntriesSelected =
        _selectedEntryIds.length == exportableEntries.length;
    final allCategoriesSelected =
        _selectedCategoryIds.length == widget.categories.length;
    final allSelected = allEntriesSelected && allCategoriesSelected;

    List<Widget> buildButtons({required bool compact}) {
      if (compact) {
        return [
          IconButton(
            tooltip: context.l10n.common_selectAll,
            onPressed: allSelected ? null : _selectAll,
            icon: const Icon(Icons.select_all, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: context.l10n.common_deselectAll,
            onPressed: _selectedEntryIds.isEmpty && _selectedCategoryIds.isEmpty
                ? null
                : _selectNone,
            icon: const Icon(Icons.deselect, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ];
      }

      return [
        TextButton.icon(
          onPressed: allSelected ? null : _selectAll,
          icon: const Icon(Icons.select_all, size: 18),
          label: Text(context.l10n.common_selectAll),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        TextButton.icon(
          onPressed: _selectedEntryIds.isEmpty && _selectedCategoryIds.isEmpty
              ? null
              : _selectNone,
          icon: const Icon(Icons.deselect, size: 18),
          label: Text(context.l10n.common_deselectAll),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final title = Text(
          context.l10n.vibe_export_selectVibesToExport,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        );

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: buildButtons(compact: compact),
            ),
          ],
        );
      },
    );
  }

  /// 构建选择列表
  Widget _buildSelectionList(ThemeData theme) {
    // 构建分类树结构
    final rootCategories = widget.categories
        .where((c) => c.parentId == null)
        .toList();

    // 获取无分类的条目（且可导出）
    final uncategorizedEntries = widget.entries
        .where((e) => e.categoryId == null && _canExportEntry(e))
        .toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount:
          rootCategories.length + (uncategorizedEntries.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // 先显示有分类的
        if (index < rootCategories.length) {
          final category = rootCategories[index];
          return _buildCategoryTile(category, 0);
        }

        // 最后显示未分类
        return _buildUncategorizedSection(theme, uncategorizedEntries);
      },
    );
  }

  /// 构建未分类部分
  Widget _buildUncategorizedSection(
    ThemeData theme,
    List<VibeLibraryEntry> entries,
  ) {
    final isExpanded = _expandedCategories.contains('__uncategorized__');
    final selectedCount = entries
        .where((e) => _selectedEntryIds.contains(e.id))
        .length;

    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (selectedCount == entries.length) {
                for (final entry in entries) {
                  _selectedEntryIds.remove(entry.id);
                }
              } else {
                for (final entry in entries) {
                  _selectedEntryIds.add(entry.id);
                }
              }
            });
          },
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedCategories.remove('__uncategorized__');
                    } else {
                      _expandedCategories.add('__uncategorized__');
                    }
                  });
                },
                padding: EdgeInsets.zero,
                visualDensity: _compactControlDensity(context),
                constraints: BoxConstraints.tightFor(
                  width: _compactControlExtent(context),
                  height: _compactControlExtent(context),
                ),
              ),
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: selectedCount == 0
                      ? false
                      : selectedCount == entries.length
                      ? true
                      : null,
                  tristate: true,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        for (final entry in entries) {
                          _selectedEntryIds.add(entry.id);
                        }
                      } else {
                        for (final entry in entries) {
                          _selectedEntryIds.remove(entry.id);
                        }
                      }
                    });
                  },
                ),
              ),
              Icon(
                Icons.folder_open_outlined,
                size: 20,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.vibeLibrary_uncategorized,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              Text(
                '$selectedCount/${entries.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        if (isExpanded) ...entries.map((entry) => _buildEntryTile(entry, 1)),
      ],
    );
  }

  /// 构建分类项（递归）
  Widget _buildCategoryTile(VibeLibraryCategory category, int depth) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategoryIds.contains(category.id);
    final isExpanded = _expandedCategories.contains(category.id);

    // 获取子分类
    final childCategories = widget.categories
        .where((c) => c.parentId == category.id)
        .toList();

    // 获取该分类下的条目（且可导出）
    final categoryEntries = widget.entries
        .where((e) => e.categoryId == category.id && _canExportEntry(e))
        .toList();

    if (categoryEntries.isEmpty && childCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    // 计算选中状态（用于indeterminate状态）
    final childSelectedCount = childCategories
        .where((c) => _selectedCategoryIds.contains(c.id))
        .length;
    final entrySelectedCount = categoryEntries
        .where((e) => _selectedEntryIds.contains(e.id))
        .length;
    final totalChildren = childCategories.length + categoryEntries.length;
    final totalSelected = childSelectedCount + entrySelectedCount;

    final bool? checkboxValue = totalSelected == 0
        ? false
        : totalSelected == totalChildren && isSelected
        ? true
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedCategoryIds.remove(category.id);
                // 取消选择时同时取消子分类和条目
                for (final child in childCategories) {
                  _selectedCategoryIds.remove(child.id);
                }
                for (final entry in categoryEntries) {
                  _selectedEntryIds.remove(entry.id);
                }
              } else {
                _selectedCategoryIds.add(category.id);
                // 选择时同时选择子分类和条目
                for (final child in childCategories) {
                  _selectedCategoryIds.add(child.id);
                }
                for (final entry in categoryEntries) {
                  _selectedEntryIds.add(entry.id);
                }
              }
            });
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: (depth * 16.0).clamp(0.0, 64.0).toDouble(),
            ),
            child: Row(
              children: [
                // 展开/折叠按钮
                if (childCategories.isNotEmpty || categoryEntries.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedCategories.remove(category.id);
                        } else {
                          _expandedCategories.add(category.id);
                        }
                      });
                    },
                    padding: EdgeInsets.zero,
                    visualDensity: _compactControlDensity(context),
                    constraints: BoxConstraints.tightFor(
                      width: _compactControlExtent(context),
                      height: _compactControlExtent(context),
                    ),
                  )
                else
                  SizedBox(width: _compactControlExtent(context)),

                // 复选框
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: checkboxValue,
                    tristate: true,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedCategoryIds.add(category.id);
                          for (final child in childCategories) {
                            _selectedCategoryIds.add(child.id);
                          }
                          for (final entry in categoryEntries) {
                            _selectedEntryIds.add(entry.id);
                          }
                        } else {
                          _selectedCategoryIds.remove(category.id);
                          for (final child in childCategories) {
                            _selectedCategoryIds.remove(child.id);
                          }
                          for (final entry in categoryEntries) {
                            _selectedEntryIds.remove(entry.id);
                          }
                        }
                      });
                    },
                  ),
                ),

                // 图标
                Icon(
                  isExpanded ? Icons.folder_open : Icons.folder,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),

                // 名称
                Expanded(
                  child: Text(
                    category.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // 数量
                if (totalChildren > 0)
                  Text(
                    '$totalSelected/$totalChildren',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 子项
        if (isExpanded) ...[
          // 子分类
          ...childCategories.map(
            (child) => _buildCategoryTile(child, depth + 1),
          ),

          // 条目
          ...categoryEntries.map((entry) => _buildEntryTile(entry, depth + 1)),
        ],
      ],
    );
  }

  /// 构建条目项
  Widget _buildEntryTile(VibeLibraryEntry entry, int depth) {
    final theme = Theme.of(context);
    final isSelected = _selectedEntryIds.contains(entry.id);

    // 获取缩略图数据
    final Uint8List? thumbnailData =
        entry.vibeThumbnail ?? entry.thumbnail ?? entry.rawImageData;

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedEntryIds.remove(entry.id);
          } else {
            _selectedEntryIds.add(entry.id);
          }
        });
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: (depth * 16.0).clamp(0.0, 64.0).toDouble(),
        ),
        child: Row(
          children: [
            const SizedBox(width: 32),
            SizedBox(
              width: 40,
              child: Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedEntryIds.add(entry.id);
                    } else {
                      _selectedEntryIds.remove(entry.id);
                    }
                  });
                },
              ),
            ),

            // 缩略图
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              clipBehavior: Clip.antiAlias,
              child: thumbnailData != null
                  ? Image.memory(
                      thumbnailData,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image_not_supported,
                          size: 20,
                          color: theme.colorScheme.outline,
                        );
                      },
                    )
                  : Icon(
                      Icons.image,
                      size: 20,
                      color: theme.colorScheme.outline,
                    ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.displayName,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isFavorite)
                        const Icon(
                          Icons.favorite,
                          size: 14,
                          color: Colors.pink,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _SourceTypeBadge(sourceType: entry.sourceType),
                      Text(
                        context.l10n.vibe_export_strengthPercent(
                          (entry.strength * 100).toInt(),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAll() {
    setState(() {
      _selectedEntryIds.addAll(
        widget.entries.where((e) => _canExportEntry(e)).map((e) => e.id),
      );
      _selectedCategoryIds.addAll(widget.categories.map((c) => c.id));
    });
  }

  void _selectNone() {
    setState(() {
      _selectedEntryIds.clear();
      _selectedCategoryIds.clear();
    });
  }

  Future<void> _export() async {
    // 过滤选中的条目
    final selectedEntries = widget.entries
        .where((e) => _selectedEntryIds.contains(e.id))
        .toList();

    if (selectedEntries.isEmpty) {
      AppToast.warning(context, context.l10n.toast_selectVibeToExport);
      return;
    }

    setState(() {
      _isExporting = true;
      _progress = 0;
      _progressMessage = context.l10n.vibe_export_preparingExport;
    });

    try {
      final bool exported;
      if (_exportFormat == VibeExportFormat.bundle) {
        exported = await _exportAsBundle(selectedEntries);
      } else if (_exportFormat == VibeExportFormat.embeddedPng) {
        exported = await _exportAsEmbeddedPng(selectedEntries);
      } else {
        exported = await _exportAsSingleFiles(selectedEntries);
      }

      if (!exported) return;

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, context.l10n.toast_exportSuccess);
      }
    } catch (e, stack) {
      AppLogger.e('导出 Vibe 失败', e, stack, 'VibeExportDialog');
      if (mounted) {
        setState(() => _isExporting = false);
        AppToast.error(context, context.l10n.toast_exportFailed(e.toString()));
      }
    }
  }

  /// 导出为单独文件
  Future<bool> _exportAsSingleFiles(List<VibeLibraryEntry> entries) async {
    if (entries.length == 1) {
      final entry = entries.first;
      setState(() {
        _progress = 0.5;
        _progressMessage = context.l10n.vibe_export_exportingName(
          entry.displayName,
        );
      });

      final exportedPath = await VibeExportUtils.exportToNaiv4Vibe(
        entry.toVibeReference(),
        name: entry.displayName,
        defaultModel: _defaultModel,
      );

      if (exportedPath == null) {
        setState(() => _isExporting = false);
        return false;
      }

      setState(() {
        _progress = 1.0;
        _progressMessage = context.l10n.vibe_export_exportCompletePath(
          exportedPath,
        );
      });
      return true;
    }

    // 选择保存目录
    final result = await FileExportService.pickExportDirectory(
      dialogTitle: context.l10n.vibe_export_selectExportFolder,
    );

    if (result == null) {
      setState(() => _isExporting = false);
      return false;
    }

    final total = entries.length;
    int successCount = 0;
    int failCount = 0;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      setState(() {
        _progress = i / total;
        _progressMessage = context.l10n.vibe_export_exportingName(
          entry.displayName,
        );
      });

      final vibeRef = entry.toVibeReference();

      // 导出单个 vibe
      final exportedPath = await VibeExportUtils.exportToNaiv4Vibe(
        vibeRef,
        name: entry.displayName,
        defaultModel: _defaultModel,
        outputDirectory: result,
      );

      if (exportedPath != null) {
        successCount++;
      } else {
        failCount++;
        AppLogger.w('导出失败: ${entry.displayName}', 'VibeExportDialog');
      }
    }

    setState(() {
      _progress = 1.0;
      _progressMessage = context.l10n.vibe_export_exportCompleteCounts(
        successCount,
        failCount,
      );
    });
    return successCount > 0;
  }

  /// 导出为嵌入 Vibe 元数据的 PNG
  Future<bool> _exportAsEmbeddedPng(List<VibeLibraryEntry> entries) async {
    if (entries.length != 1) {
      setState(() => _isExporting = false);
      if (mounted) {
        AppToast.warning(context, context.l10n.toast_embedPngSingleVibeOnly);
      }
      return false;
    }

    final entry = entries.first;
    final carrierImageBytes = _currentCarrierImageBytes(entry);
    if (carrierImageBytes == null) {
      setState(() => _isExporting = false);
      if (mounted) {
        AppToast.warning(context, context.l10n.toast_selectPngCarrier);
      }
      return false;
    }

    setState(() {
      _progress = 0.5;
      _progressMessage = context.l10n.vibe_export_embeddingPng(
        entry.displayName,
      );
    });

    final exportedPath = await VibeExportUtils.exportToEmbeddedPng(
      [entry.toVibeReference()],
      carrierImageBytes: carrierImageBytes,
      fileName: _embeddedPngFileName(entry),
      defaultModel: _defaultModel,
    );

    if (exportedPath == null) {
      setState(() => _isExporting = false);
      return false;
    }

    setState(() {
      _progress = 1.0;
      _progressMessage = context.l10n.vibe_export_exportCompletePath(
        exportedPath,
      );
    });
    return true;
  }

  /// 导出为 bundle 文件
  Future<bool> _exportAsBundle(List<VibeLibraryEntry> entries) async {
    setState(() {
      _progress = 0.3;
      _progressMessage = context.l10n.vibe_export_packingVibes(entries.length);
    });

    // 转换为 VibeReference 列表
    final vibes = entries.map((e) => e.toVibeReference()).toList();

    setState(() {
      _progress = 0.6;
      _progressMessage = context.l10n.vibe_export_generatingBundleFile;
    });

    // 导出 bundle
    final bundleName = 'vibe_bundle_${entries.length}';
    final exportedPath = await VibeExportUtils.exportToNaiv4VibeBundle(
      vibes,
      bundleName,
      defaultModel: _defaultModel,
    );

    if (exportedPath == null) {
      setState(() => _isExporting = false);
      return false;
    }

    setState(() {
      _progress = 1.0;
      _progressMessage = context.l10n.vibe_export_exportCompletePath(
        exportedPath,
      );
    });
    return true;
  }
}

/// 统计项组件
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 数据来源类型标签
class _SourceTypeBadge extends StatelessWidget {
  final VibeSourceType sourceType;

  const _SourceTypeBadge({required this.sourceType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color textColor;
    String label;

    switch (sourceType) {
      case VibeSourceType.png:
        backgroundColor = Colors.green.withValues(alpha: 0.15);
        textColor = Colors.green;
        label = context.l10n.vibe_sourceType_png;
      case VibeSourceType.naiv4vibe:
        backgroundColor = Colors.blue.withValues(alpha: 0.15);
        textColor = Colors.blue;
        label = context.l10n.vibe_sourceType_v4vibe;
      case VibeSourceType.naiv4vibebundle:
        backgroundColor = Colors.purple.withValues(alpha: 0.15);
        textColor = Colors.purple;
        label = context.l10n.vibe_sourceType_bundle;
      case VibeSourceType.rawImage:
        backgroundColor = Colors.orange.withValues(alpha: 0.15);
        textColor = Colors.orange;
        label = context.l10n.vibe_sourceType_image;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
