import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/vibe_encoding_utils.dart';
import '../../../../core/utils/vibe_export_utils.dart';
import '../../../../core/utils/vibe_image_embedder.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/services/vibe_file_storage_service.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../widgets/common/app_toast.dart';

/// Vibe 导出对话框（高级版）
/// 支持导出单个 vibe、批量导出，以及从 bundle 中导出单个 vibe
class VibeExportDialogAdvanced extends ConsumerStatefulWidget {
  final List<VibeLibraryEntry> entries;

  const VibeExportDialogAdvanced({super.key, required this.entries});

  @override
  ConsumerState<VibeExportDialogAdvanced> createState() =>
      _VibeExportDialogAdvancedState();
}

/// 导出验证结果
class _ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const _ValidationResult({required this.isValid, this.errorMessage});
}

class _VibeExportDialogAdvancedState
    extends ConsumerState<VibeExportDialogAdvanced> {
  // 导出选项状态
  bool _exportBundle = true;
  bool _embedIntoImage = false;
  bool _exportEncoding = false;
  bool _exportZip = false;

  // Bundle 选项
  bool _bundleIncludeThumbnail = true;
  bool _bundleCompress = false;

  // Bundle 导出模式 (仅当单选 bundle 时有效)
  bool _exportWholeBundle = true; // true=导出整个 bundle, false=导出内部单个 vibe
  final List<bool> _selectedInternalVibes = []; // 选中的内部 vibe 索引

  // Embed 选项
  String? _selectedImagePath;
  Uint8List? _selectedImagePreview;
  List<_CarrierImageOption> _carrierImageOptions = const [];
  String? _selectedCarrierImageId;
  bool _isValidatingImage = false;

  // Encoding 选项
  bool _encodingAsJson = true; // true=JSON, false=Base64

  // 导出状态
  bool _isExporting = false;
  double _progress = 0.0;
  String _statusMessage = '';

  // 错误信息
  String? _errorMessage;

  List<VibeLibraryEntry>? _resolvedEntries;

  /// 是否为单选 bundle
  bool get _isSingleBundle {
    return widget.entries.length == 1 && widget.entries.first.isBundle;
  }

  bool get _hasInternalVibeSelectionError {
    return _isSingleBundle &&
        !_exportWholeBundle &&
        _exportBundle &&
        !_selectedInternalVibes.any((v) => v);
  }

  /// 获取对话框标题
  String _getDialogTitle() {
    if (_isSingleBundle) {
      final entry = widget.entries.first;
      return context.l10n.vibe_export_bundleTitle(entry.displayName);
    }
    return context.l10n.vibe_export_vibesTitle(widget.entries.length);
  }

  @override
  void initState() {
    super.initState();
    _syncInternalVibeSelections();
    _rebuildCarrierImageOptions();
  }

  @override
  void didUpdateWidget(covariant VibeExportDialogAdvanced oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries) {
      _resolvedEntries = null;
      _syncInternalVibeSelections();
      _rebuildCarrierImageOptions();
    }
  }

  void _syncInternalVibeSelections() {
    if (!_isSingleBundle) {
      _selectedInternalVibes.clear();
      return;
    }

    final count = widget.entries.first.bundledVibeCount;
    if (_selectedInternalVibes.length == count) {
      return;
    }

    _selectedInternalVibes
      ..clear()
      ..addAll(List<bool>.filled(count, true));
  }

  void _rebuildCarrierImageOptions([List<VibeLibraryEntry>? sourceEntries]) {
    final entries = sourceEntries ?? widget.entries;
    if (entries.length != 1) {
      _carrierImageOptions = const [];
      _selectedCarrierImageId = null;
      return;
    }

    final options = <_CarrierImageOption>[];
    for (final entry in entries) {
      for (final candidate in VibeExportUtils.collectImageCandidates(entry)) {
        final label = entries.length == 1
            ? candidate.label
            : '${entry.displayName} - ${candidate.label}';
        options.add(
          _CarrierImageOption(
            id: '${entry.id}:${candidate.id}',
            label: label,
            bytes: candidate.bytes,
          ),
        );
      }
    }

    _carrierImageOptions = options;
    if (_carrierImageOptions.any(
      (option) => option.id == _selectedCarrierImageId,
    )) {
      return;
    }
    _selectedCarrierImageId = _carrierImageOptions.isNotEmpty
        ? _carrierImageOptions.first.id
        : null;
  }

  Uint8List? _currentCarrierImageBytes() {
    if (_selectedImagePreview != null && _selectedImagePreview!.isNotEmpty) {
      return _selectedImagePreview;
    }

    final selectedId = _selectedCarrierImageId;
    if (selectedId == null) {
      return null;
    }

    for (final option in _carrierImageOptions) {
      if (option.id == selectedId) {
        return option.bytes;
      }
    }
    return null;
  }

  String _displayExportError(Object error) {
    return error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^Bad state:\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSingleBundle = _isSingleBundle;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.file_upload_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getDialogTitle(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!_isExporting)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              if (_isExporting) ...[
                // 导出进度
                _buildProgressView(theme),
              ] else ...[
                // 导出选项
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bundle 导出选项（如果不是单选 bundle，或选择了导出整个 bundle）
                        if (!isSingleBundle || _exportWholeBundle) ...[
                          _buildExportBundleOption(theme),
                          const SizedBox(height: 16),
                          _buildExportZipOption(theme),
                          const SizedBox(height: 16),
                        ],

                        // 单选 bundle 时的导出模式选择
                        if (isSingleBundle) ...[
                          _buildBundleExportModeOption(theme),
                          const SizedBox(height: 16),
                        ],

                        // 内部 vibe 选择列表（仅当单选 bundle 且选择导出单个 vibe 时显示）
                        if (isSingleBundle && !_exportWholeBundle) ...[
                          _buildInternalVibeSelection(theme),
                          const SizedBox(height: 16),
                        ],

                        if (widget.entries.length == 1) ...[
                          _buildEmbedIntoImageOption(theme),
                          const SizedBox(height: 16),
                        ],
                        _buildExportEncodingOption(theme),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 错误提示
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.l10n.common_cancel),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _validateExportOptions().isValid
                          ? _export
                          : null,
                      icon: const Icon(Icons.file_upload),
                      label: Text(context.l10n.common_export),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建 Bundle 导出模式选项（仅单选 bundle 时显示）
  Widget _buildBundleExportModeOption(ThemeData theme) {
    final entry = widget.entries.first;
    final count = entry.bundledVibeCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_zip_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.vibe_export_method,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: true,
                label: Text(context.l10n.vibe_export_wholeBundle),
                icon: const Icon(Icons.folder_zip),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text(context.l10n.vibe_export_internalVibe),
                icon: const Icon(Icons.layers),
              ),
            ],
            selected: {_exportWholeBundle},
            onSelectionChanged: (value) {
              setState(() {
                _exportWholeBundle = value.first;
                _errorMessage = _validateExportOptions().errorMessage;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            _exportWholeBundle
                ? context.l10n.vibe_export_wholeBundleDescription(count)
                : context.l10n.vibe_export_internalVibeDescription(count),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建内部 vibe 选择列表
  Widget _buildInternalVibeSelection(ThemeData theme) {
    final entry = widget.entries.first;
    final names = entry.bundledVibeNames ?? [];
    final previews = entry.bundledVibePreviews ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.vibe_export_selectVibesToExport,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    final allSelected = _selectedInternalVibes.every((v) => v);
                    for (var i = 0; i < _selectedInternalVibes.length; i++) {
                      _selectedInternalVibes[i] = !allSelected;
                    }
                    _errorMessage = _validateExportOptions().errorMessage;
                  });
                },
                child: Text(
                  _selectedInternalVibes.every((v) => v)
                      ? context.l10n.common_deselectAll
                      : context.l10n.common_selectAll,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: names.length,
              itemBuilder: (context, index) {
                final name = names[index];
                final preview = index < previews.length
                    ? previews[index]
                    : null;
                final isSelected = _selectedInternalVibes[index];

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      _selectedInternalVibes[index] = value ?? false;
                      _errorMessage = _validateExportOptions().errorMessage;
                    });
                  },
                  title: Row(
                    children: [
                      if (preview != null) ...[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.memory(
                            preview,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image,
                                size: 20,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          if (_errorMessage != null && _hasInternalVibeSelectionError) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建导出 Bundle 选项
  Widget _buildExportBundleOption(ThemeData theme) {
    final isDisabled = _embedIntoImage;
    final isBundle = _isSingleBundle && _exportWholeBundle;

    return _OptionCard(
      isSelected: _exportBundle,
      isDisabled: isDisabled,
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _exportBundle = !_exportBundle;
                _errorMessage = _validateExportOptions().errorMessage;
              });
            },
      icon: Icons.folder_zip_outlined,
      title: isBundle
          ? context.l10n.vibe_export_exportBundle
          : context.l10n.vibe_export_exportAsFiles,
      subtitle: isBundle
          ? context.l10n.vibe_export_exportBundleDescription
          : context.l10n.vibe_export_exportAsFilesDescription,
      child: _exportBundle
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Bundle 选项
                _buildCheckbox(
                  value: _bundleIncludeThumbnail,
                  onChanged: (value) {
                    setState(() => _bundleIncludeThumbnail = value ?? true);
                  },
                  title: context.l10n.vibe_export_include_thumbnails,
                  subtitle:
                      context.l10n.vibe_export_include_thumbnails_subtitle,
                ),
                const SizedBox(height: 8),
                _buildCheckbox(
                  value: _bundleCompress,
                  onChanged: (value) {
                    setState(() => _bundleCompress = value ?? false);
                  },
                  title: context.l10n.vibe_export_compressData,
                  subtitle: context.l10n.vibe_export_compressDataDescription,
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildExportZipOption(ThemeData theme) {
    return _OptionCard(
      isSelected: _exportZip,
      onTap: () {
        setState(() {
          _exportZip = !_exportZip;
          _errorMessage = _validateExportOptions().errorMessage;
        });
      },
      icon: Icons.archive_outlined,
      title: context.l10n.vibe_export_exportAsZip,
      subtitle: context.l10n.vibe_export_exportAsZipDescription,
      child: _exportZip
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildCheckbox(
                  value: _bundleIncludeThumbnail,
                  onChanged: (value) {
                    setState(() => _bundleIncludeThumbnail = value ?? true);
                  },
                  title: context.l10n.vibe_export_include_thumbnails,
                  subtitle:
                      context.l10n.vibe_export_include_thumbnails_subtitle,
                ),
                const SizedBox(height: 8),
                _buildCheckbox(
                  value: _bundleCompress,
                  onChanged: (value) {
                    setState(() => _bundleCompress = value ?? false);
                  },
                  title: context.l10n.vibe_export_compressData,
                  subtitle: context.l10n.vibe_export_zipCompressDescription,
                ),
              ],
            )
          : null,
    );
  }

  /// 构建嵌入图片选项
  Widget _buildEmbedIntoImageOption(ThemeData theme) {
    final isBundleInternalExport = _isSingleBundle && !_exportWholeBundle;
    final isBatchPngExport = widget.entries.length > 1;

    // 从 bundle 导出内部单个 vibe 时暂不支持嵌入图片
    final isDisabled = isBundleInternalExport;

    return _OptionCard(
      isSelected: _embedIntoImage,
      isDisabled: isDisabled,
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _embedIntoImage = !_embedIntoImage;
                if (_embedIntoImage) {
                  _exportBundle = false;
                }
                _errorMessage = _validateExportOptions().errorMessage;
              });
            },
      icon: Icons.image_outlined,
      title: context.l10n.vibe_export_exportAsPng,
      subtitle: isBundleInternalExport
          ? context.l10n.vibe_export_pngInternalBundleUnsupported
          : context.l10n.vibe_export_embedVibeDataIntoPng,
      child: _embedIntoImage
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                if (isBatchPngExport) ...[
                  Text(
                    context.l10n.vibe_export_batchPngUsesFirstImage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else if (_carrierImageOptions.isNotEmpty) ...[
                  Text(
                    context.l10n.vibe_export_exportCarrierImage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                      _selectedImagePath == null
                          ? _selectedCarrierImageId
                          : null,
                    ),
                    initialValue: _selectedImagePath == null
                        ? _selectedCarrierImageId
                        : null,
                    items: _carrierImageOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option.id,
                            child: Text(
                              option.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      setState(() {
                        _selectedCarrierImageId = value;
                        _selectedImagePath = null;
                        _selectedImagePreview = null;
                        _errorMessage = _validateExportOptions().errorMessage;
                      });
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // 图片选择
                if (!isBatchPngExport && _selectedImagePath == null) ...[
                  OutlinedButton.icon(
                    onPressed: _isValidatingImage ? null : _pickImage,
                    icon: _isValidatingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open),
                    label: Text(
                      context.l10n.vibe_export_selectExternalPngImage,
                    ),
                  ),
                ] else if (!isBatchPngExport) ...[
                  Row(
                    children: [
                      // 图片预览
                      if (_selectedImagePreview != null)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.memory(
                            _selectedImagePreview!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedImagePath!
                                  .split(Platform.pathSeparator)
                                  .last,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: _isValidatingImage ? null : _pickImage,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: Text(context.l10n.common_change),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_selectedImagePath != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.vibe_export_usingExternalCarrierImage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            )
          : null,
    );
  }

  /// 构建导出编码选项
  Widget _buildExportEncodingOption(ThemeData theme) {
    return _OptionCard(
      isSelected: _exportEncoding,
      onTap: () {
        setState(() {
          _exportEncoding = !_exportEncoding;
          _errorMessage = _validateExportOptions().errorMessage;
        });
      },
      icon: Icons.code,
      title: context.l10n.vibe_export_exportAsEncodings,
      subtitle: context.l10n.vibe_export_exportAsEncodingsDescription,
      child: _exportEncoding
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // 编码格式选择
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('JSON'),
                      icon: Icon(Icons.data_object),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Base64'),
                      icon: Icon(Icons.text_fields),
                    ),
                  ],
                  selected: {_encodingAsJson},
                  onSelectionChanged: (value) {
                    setState(() => _encodingAsJson = value.first);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _encodingAsJson
                      ? context.l10n.vibe_export_jsonDescription
                      : context.l10n.vibe_export_base64Description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            )
          : null,
    );
  }

  /// 构建复选框
  Widget _buildCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
    String? subtitle,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建进度视图
  Widget _buildProgressView(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: _progress > 0 ? _progress : null,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (_progress > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toInt()}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 验证导出选项
  /// 返回验证结果，包含是否有效和错误信息
  _ValidationResult _validateExportOptions() {
    // 检查是否正在导出
    if (_isExporting) {
      return const _ValidationResult(isValid: false, errorMessage: null);
    }

    // 确保至少选择一种导出方式
    if (!_exportBundle && !_embedIntoImage && !_exportEncoding && !_exportZip) {
      return _ValidationResult(
        isValid: false,
        errorMessage: context.l10n.vibe_export_selectAtLeastOneMethod,
      );
    }

    if (_embedIntoImage && widget.entries.length > 1) {
      return _ValidationResult(
        isValid: false,
        errorMessage: context.l10n.vibe_export_batchPngUnsupported,
      );
    }

    // 嵌入图片需要选择图片
    if (_embedIntoImage && _currentCarrierImageBytes() == null) {
      return _ValidationResult(
        isValid: false,
        errorMessage: context.l10n.vibe_export_selectPngCarrier,
      );
    }

    // 如果是导出 bundle 内部单个 vibe，需要至少选择一个
    if (_isSingleBundle && !_exportWholeBundle && _exportBundle) {
      final hasSelection = _selectedInternalVibes.any((v) => v);
      if (!hasSelection) {
        return _ValidationResult(
          isValid: false,
          errorMessage: context.l10n.vibe_export_selectAtLeastOneInternalVibe,
        );
      }
    }

    return const _ValidationResult(isValid: true);
  }

  /// 选择图片
  Future<void> _pickImage() async {
    setState(() => _isValidatingImage = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png'],
        dialogTitle: context.l10n.vibe_export_selectPngImage,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final path = file.path;

        if (path != null) {
          // 验证是有效的 PNG
          final bytes = await File(path).readAsBytes();

          // 检查 PNG 签名
          if (bytes.length < 8 ||
              bytes[0] != 0x89 ||
              bytes[1] != 0x50 ||
              bytes[2] != 0x4E ||
              bytes[3] != 0x47) {
            setState(() {
              _errorMessage = context.l10n.vibe_export_invalidPngImage;
              _isValidatingImage = false;
            });
            return;
          }

          setState(() {
            _selectedImagePath = path;
            _selectedImagePreview = bytes;
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = context.l10n.vibe_export_selectImageFailed(
          e.toString(),
        );
      });
    } finally {
      setState(() => _isValidatingImage = false);
    }
  }

  /// 执行导出
  Future<void> _export() async {
    setState(() {
      _isExporting = true;
      _progress = 0.0;
      _statusMessage = context.l10n.vibe_export_preparingExport;
    });

    try {
      final entries = await _resolveEntriesForExport();
      if (entries.isEmpty) {
        if (mounted) {
          setState(() {
            _isExporting = false;
            _errorMessage = context.l10n.vibe_export_noExportableEntries;
          });
        }
        return;
      }

      final results = <String>[];
      var completed = 0;
      final total = [
        if (_exportBundle) 1,
        if (_exportZip) 1,
        if (_embedIntoImage) 1,
        if (_exportEncoding) 1,
      ].length;

      // 导出 Bundle
      if (_exportBundle) {
        setState(() {
          _statusMessage = context.l10n.vibe_export_exportingBundle;
        });
        final bundlePath = await _exportBundleFile(entries);
        if (bundlePath != null) {
          results.add('Bundle: $bundlePath');
        }
        completed++;
        setState(() => _progress = completed / total);
      }

      if (_exportZip) {
        setState(() {
          _statusMessage = context.l10n.vibe_export_exportingZip;
        });
        final zipPath = await _exportZipFile(entries);
        if (zipPath != null) {
          results.add('ZIP: $zipPath');
        }
        completed++;
        setState(() => _progress = completed / total);
      }

      // 嵌入图片
      if (_embedIntoImage) {
        setState(() {
          _statusMessage = context.l10n.vibe_export_embeddingImage;
        });
        final embedPath = await _embedIntoImageFile(entries);
        if (embedPath != null) {
          results.add('Image: $embedPath');
        }
        completed++;
        setState(() => _progress = completed / total);
      }

      // 导出编码
      if (_exportEncoding) {
        setState(() {
          _statusMessage = context.l10n.vibe_export_exportingEncoding;
        });
        final encodingPath = await _exportEncodingFile(entries);
        if (encodingPath != null) {
          results.add('Encoding: $encodingPath');
        }
        completed++;
        setState(() => _progress = 1.0);
      }

      if (results.isEmpty) {
        if (mounted) {
          setState(() => _isExporting = false);
        }
        return;
      }

      // 显示成功提示
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, context.l10n.toast_exportSuccess);
      }
    } catch (e, stack) {
      AppLogger.e('导出 Vibe 失败', e, stack, 'VibeExportDialogAdvanced');
      if (mounted) {
        setState(() {
          _isExporting = false;
          _errorMessage = context.l10n.vibe_export_exportFailedWithError(
            _displayExportError(e),
          );
        });
      }
    }
  }

  Future<List<VibeLibraryEntry>> _resolveEntriesForExport() async {
    final cached = _resolvedEntries;
    if (cached != null) {
      return cached;
    }

    final sourceEntries = widget.entries;
    if (sourceEntries.isEmpty) {
      return const <VibeLibraryEntry>[];
    }

    final storage = ref.read(vibeLibraryStorageServiceProvider);
    final resolvedEntries = <VibeLibraryEntry>[];
    for (var i = 0; i < sourceEntries.length; i++) {
      final sourceEntry = sourceEntries[i];
      if (mounted) {
        setState(() {
          _statusMessage = context.l10n.vibe_export_preparingVibeProgress(
            i + 1,
            sourceEntries.length,
          );
        });
      }

      final resolvedEntry = await storage.getEntry(sourceEntry.id);
      resolvedEntries.add(resolvedEntry ?? sourceEntry);
    }

    _resolvedEntries = resolvedEntries;
    if (resolvedEntries.length == 1) {
      _rebuildCarrierImageOptions(resolvedEntries);
    }
    return resolvedEntries;
  }

  /// 导出 Bundle 文件
  Future<String?> _exportBundleFile(List<VibeLibraryEntry> entries) async {
    // 处理单选 bundle 且选择导出内部单个 vibe 的情况
    if (_isSingleBundle && !_exportWholeBundle) {
      return _exportSelectedInternalVibes(entries);
    }

    final vibes = entries.map((e) => e.toVibeReference()).toList();

    if (vibes.isEmpty) return null;

    if (vibes.length == 1) {
      // 单个导出为 .naiv4vibe
      return VibeExportUtils.exportToNaiv4Vibe(
        vibes.first,
        name: entries.first.displayName,
      );
    } else {
      // 多个导出为 .naiv4vibebundle
      final bundleName = 'vibe_bundle_${vibes.length}';
      return VibeExportUtils.exportToNaiv4VibeBundle(vibes, bundleName);
    }
  }

  Future<String?> _exportZipFile(List<VibeLibraryEntry> entries) async {
    if (entries.isEmpty) return null;

    final zipName = entries.length == 1
        ? '${entries.first.displayName}_vibe_files'
        : 'vibe_library_${entries.length}_items';
    return VibeExportUtils.exportEntriesToZip(
      entries,
      name: zipName,
      includeThumbnails: _bundleIncludeThumbnail,
      compress: _bundleCompress,
    );
  }

  /// 导出选中的内部 vibe（从 bundle 中提取）
  Future<String?> _exportSelectedInternalVibes(
    List<VibeLibraryEntry> entries,
  ) async {
    final entry = entries.first;
    final filePath = entry.filePath;

    if (filePath == null || filePath.isEmpty) {
      throw Exception(context.l10n.vibe_export_bundleFilePathEmpty);
    }

    final storageService = VibeFileStorageService();
    final selectedIndices = <int>[];

    for (var i = 0; i < _selectedInternalVibes.length; i++) {
      if (_selectedInternalVibes[i]) {
        selectedIndices.add(i);
      }
    }

    if (selectedIndices.isEmpty) return null;

    final outputDirectory = selectedIndices.length > 1
        ? await FilePicker.platform.getDirectoryPath(
            dialogTitle: context.l10n.vibe_export_selectVibeExportFolder,
          )
        : null;
    if (selectedIndices.length > 1 &&
        (outputDirectory == null || outputDirectory.isEmpty)) {
      return null;
    }

    final exportedPaths = <String>[];

    for (var i = 0; i < selectedIndices.length; i++) {
      final index = selectedIndices[i];
      setState(
        () => _statusMessage = context.l10n.vibe_export_extractingVibeProgress(
          i + 1,
          selectedIndices.length,
        ),
      );

      final vibe = await storageService.extractVibeFromBundle(filePath, index);
      if (vibe == null) {
        AppLogger.w('无法提取索引 $index 的 vibe', 'VibeExportDialogAdvanced');
        continue;
      }

      final path = await VibeExportUtils.exportToNaiv4Vibe(
        vibe,
        name: vibe.displayName,
        outputDirectory: outputDirectory,
      );

      if (path != null) {
        exportedPaths.add(path);
      }
    }

    if (exportedPaths.isEmpty) return null;
    if (exportedPaths.length == 1) return exportedPaths.first;
    return exportedPaths.join(',');
  }

  /// 嵌入到图片
  Future<String?> _embedIntoImageFile(List<VibeLibraryEntry> entries) async {
    if (entries.isEmpty) return null;
    if (entries.length > 1) {
      return null;
    }

    final carrierImageBytes = _currentCarrierImageBytes();
    if (carrierImageBytes == null) {
      return null;
    }

    try {
      final vibes = entries.map((entry) => entry.toVibeReference()).toList();
      final fileName = entries.length == 1
          ? '${entries.first.displayName}_vibe.png'
          : 'vibe_bundle_${entries.length}.png';

      return VibeExportUtils.exportToEmbeddedPng(
        vibes,
        carrierImageBytes: carrierImageBytes,
        fileName: fileName,
      );
    } on InvalidImageFormatException catch (e) {
      throw Exception(
        context.l10n.vibe_export_invalidImageFormatWithError(e.message),
      );
    } on VibeEmbedException catch (e) {
      throw Exception(context.l10n.vibe_export_embedFailedWithError(e.message));
    } catch (e) {
      throw Exception(
        context.l10n.vibe_export_embedImageFailedWithError(e.toString()),
      );
    }
  }

  /// 导出编码文件
  Future<String?> _exportEncodingFile(List<VibeLibraryEntry> entries) async {
    if (entries.isEmpty) return null;

    // 生成编码内容
    final buffer = StringBuffer();

    if (entries.length == 1) {
      // 单个 Vibe
      final entry = entries.first;
      final vibeRef = entry.toVibeReference();

      if (_encodingAsJson) {
        buffer.writeln(VibeEncodingUtils.encodeToJson(vibeRef));
      } else {
        buffer.writeln(VibeEncodingUtils.encodeToBase64(vibeRef));
      }
    } else {
      // 多个 Vibe - 导出为数组格式
      buffer.writeln('[');
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final vibeRef = entry.toVibeReference();

        if (_encodingAsJson) {
          buffer.writeln(VibeEncodingUtils.encodeToJson(vibeRef));
        } else {
          buffer.writeln(VibeEncodingUtils.encodeToBase64(vibeRef));
        }

        if (i < entries.length - 1) {
          buffer.writeln(',');
        }
      }
      buffer.writeln(']');
    }

    // 选择保存位置
    final extension = _encodingAsJson ? 'json' : 'txt';
    final fileName = entries.length == 1
        ? '${entries.first.displayName}_encoding.$extension'
        : 'vibe_encodings_$extension';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: context.l10n.vibe_export_saveEncodingFile,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
    );

    if (savePath == null) return null;

    // 保存文件
    await File(savePath).writeAsString(buffer.toString());

    return savePath;
  }
}

class _CarrierImageOption {
  const _CarrierImageOption({
    required this.id,
    required this.label,
    required this.bytes,
  });

  final String id;
  final String label;
  final Uint8List bytes;
}

/// 选项卡片组件
class _OptionCard extends StatelessWidget {
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? child;

  const _OptionCard({
    required this.isSelected,
    this.isDisabled = false,
    this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDisabled
                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.3)
                : isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isDisabled
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
              : isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
              : theme.colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDisabled
                          ? theme.colorScheme.outline.withValues(alpha: 0.3)
                          : isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: isDisabled
                        ? theme.colorScheme.surface
                        : isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                  ),
                  child: isSelected && !isDisabled
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: isDisabled
                                ? theme.colorScheme.outline.withValues(
                                    alpha: 0.5,
                                  )
                                : isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDisabled
                                    ? theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      )
                                    : isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDisabled
                              ? theme.colorScheme.outline.withValues(alpha: 0.5)
                              : theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}
