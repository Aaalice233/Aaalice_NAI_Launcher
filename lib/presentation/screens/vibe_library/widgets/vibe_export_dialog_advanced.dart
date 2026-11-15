import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../providers/generation/generation_params_notifier.dart';
import '../../../widgets/common/app_toast.dart';
import 'vibe_export_advanced/vibe_export_advanced_executor.dart';
import 'vibe_export_advanced/vibe_export_advanced_models.dart';
import 'vibe_export_advanced/vibe_export_bundle_sections.dart';
import 'vibe_export_advanced/vibe_export_embed_and_encoding_sections.dart';
import 'vibe_export_advanced/vibe_export_option_card.dart';

@visibleForTesting
Size vibeExportChangeImageMinimumSize(InteractionPolicy policy) {
  return resolveVibeExportChangeImageMinimumSize(policy);
}

/// Vibe 导出对话框（高级版）
/// 支持导出单个 vibe、批量导出，以及从 bundle 中导出单个 vibe
class VibeExportDialogAdvanced extends ConsumerStatefulWidget {
  final List<VibeLibraryEntry> entries;

  const VibeExportDialogAdvanced({super.key, required this.entries});

  static Future<void> show(
    BuildContext context, {
    required List<VibeLibraryEntry> entries,
  }) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            Icons.file_upload_outlined,
            color: Theme.of(panelContext).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entries.length == 1 && entries.first.isBundle
                  ? panelContext.l10n.vibe_export_bundleTitle(
                      entries.first.displayName,
                    )
                  : panelContext.l10n.vibe_export_vibesTitle(entries.length),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                panelContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      dialogWidth: 520,
      builder: (_, __) => VibeExportDialogAdvanced(entries: entries),
    );
  }

  @override
  ConsumerState<VibeExportDialogAdvanced> createState() =>
      _VibeExportDialogAdvancedState();
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
  List<VibeExportCarrierImageOption> _carrierImageOptions = const [];
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

  String get _defaultModel => ref.read(generationParamsNotifierProvider).model;

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
    _carrierImageOptions = buildVibeCarrierImageOptions(entries);
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
    return findVibeCarrierImageBytes(
      selectedImagePreview: _selectedImagePreview,
      carrierImageOptions: _carrierImageOptions,
      selectedCarrierImageId: _selectedCarrierImageId,
    );
  }

  VibeExportValidationResult _validateExportOptions() {
    return validateVibeExportOptions(
      context,
      isExporting: _isExporting,
      exportBundle: _exportBundle,
      embedIntoImage: _embedIntoImage,
      exportEncoding: _exportEncoding,
      exportZip: _exportZip,
      entryCount: widget.entries.length,
      currentCarrierImageBytes: _currentCarrierImageBytes(),
      isSingleBundle: _isSingleBundle,
      exportWholeBundle: _exportWholeBundle,
      selectedInternalVibes: _selectedInternalVibes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSingleBundle = _isSingleBundle;

    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        key: const Key('vibe-export-advanced-dialog-frame'),
        padding: EdgeInsets.all(constraints.maxWidth < 380 ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isExporting) ...[
              // 导出进度
              VibeExportProgressView(
                progress: _progress,
                statusMessage: _statusMessage,
              ),
            ] else ...[
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.vibe_export_format,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.vibe_export_multipleFormatsHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Bundle 导出选项（如果不是单选 bundle，或选择了导出整个 bundle）
                      if (!isSingleBundle || _exportWholeBundle) ...[
                        VibeExportBundleOptionCard(
                          isSelected: _exportBundle,
                          isDisabled: _embedIntoImage,
                          isBundle: _isSingleBundle && _exportWholeBundle,
                          includeThumbnail: _bundleIncludeThumbnail,
                          compress: _bundleCompress,
                          onToggle: () {
                            setState(() {
                              _exportBundle = !_exportBundle;
                              _errorMessage =
                                  _validateExportOptions().errorMessage;
                            });
                          },
                          onIncludeThumbnailChanged: (value) {
                            setState(() => _bundleIncludeThumbnail = value);
                          },
                          onCompressChanged: (value) {
                            setState(() => _bundleCompress = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        VibeExportZipOptionCard(
                          isSelected: _exportZip,
                          includeThumbnail: _bundleIncludeThumbnail,
                          compress: _bundleCompress,
                          onToggle: () {
                            setState(() {
                              _exportZip = !_exportZip;
                              _errorMessage =
                                  _validateExportOptions().errorMessage;
                            });
                          },
                          onIncludeThumbnailChanged: (value) {
                            setState(() => _bundleIncludeThumbnail = value);
                          },
                          onCompressChanged: (value) {
                            setState(() => _bundleCompress = value);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      // 单选 bundle 时的导出模式选择
                      if (isSingleBundle) ...[
                        VibeExportBundleModeCard(
                          entry: widget.entries.first,
                          exportWholeBundle: _exportWholeBundle,
                          onModeChanged: (value) {
                            setState(() {
                              _exportWholeBundle = value;
                              _errorMessage =
                                  _validateExportOptions().errorMessage;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      // 内部 vibe 选择列表（仅当单选 bundle 且选择导出单个 vibe 时显示）
                      if (isSingleBundle && !_exportWholeBundle) ...[
                        VibeExportInternalVibeList(
                          entry: widget.entries.first,
                          selectedInternalVibes: _selectedInternalVibes,
                          errorMessage: _errorMessage,
                          hasInternalVibeSelectionError:
                              _hasInternalVibeSelectionError,
                          onToggleAll: () {
                            setState(() {
                              final allSelected = _selectedInternalVibes.every(
                                (v) => v,
                              );
                              for (
                                var i = 0;
                                i < _selectedInternalVibes.length;
                                i++
                              ) {
                                _selectedInternalVibes[i] = !allSelected;
                              }
                              _errorMessage =
                                  _validateExportOptions().errorMessage;
                            });
                          },
                          onItemChanged: (index, selected) {
                            setState(() {
                              _selectedInternalVibes[index] = selected;
                              _errorMessage =
                                  _validateExportOptions().errorMessage;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (widget.entries.length == 1) ...[
                        VibeExportEmbedImageOptionCard(
                          isSelected: _embedIntoImage,
                          isBundleInternalExport:
                              _isSingleBundle && !_exportWholeBundle,
                          isBatchPngExport: widget.entries.length > 1,
                          carrierImageOptions: _carrierImageOptions,
                          selectedCarrierImageId: _selectedCarrierImageId,
                          selectedImagePath: _selectedImagePath,
                          selectedImagePreview: _selectedImagePreview,
                          isValidatingImage: _isValidatingImage,
                          onToggle: () {
                            setState(() {
                              _embedIntoImage = !_embedIntoImage;
                              if (_embedIntoImage) {
                                _exportBundle = false;
                              }
                              _errorMessage =
                                  _validateExportOptions().errorMessage;
                            });
                          },
                          onCarrierChanged: (value) {
                            setState(() {
                              _selectedCarrierImageId = value;
                              _selectedImagePath = null;
                              _selectedImagePreview = null;
                              _errorMessage =
                                  _validateExportOptions().errorMessage;
                            });
                          },
                          onPickImage: _pickImage,
                        ),
                        const SizedBox(height: 8),
                      ],
                      VibeExportEncodingOptionCard(
                        isSelected: _exportEncoding,
                        encodingAsJson: _encodingAsJson,
                        onToggle: () {
                          setState(() {
                            _exportEncoding = !_exportEncoding;
                            _errorMessage =
                                _validateExportOptions().errorMessage;
                          });
                        },
                        onFormatChanged: (value) {
                          setState(() => _encodingAsJson = value);
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        VibeExportErrorBanner(message: _errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      VibeExportDialogActions(
                        canExport: _validateExportOptions().isValid,
                        onCancel: () => Navigator.of(context).pop(),
                        onExport: _export,
                      ),
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

  /// 选择图片
  Future<void> _pickImage() async {
    final l10n = context.l10n;
    setState(() => _isValidatingImage = true);

    try {
      final pickResult = await VibeExportAdvancedExecutor.pickCarrierPngImage(
        l10n: l10n,
      );
      if (pickResult.errorMessage != null) {
        setState(() {
          _errorMessage = pickResult.errorMessage;
          _isValidatingImage = false;
        });
        return;
      }
      if (!pickResult.cancelled &&
          pickResult.path != null &&
          pickResult.bytes != null) {
        setState(() {
          _selectedImagePath = pickResult.path;
          _selectedImagePreview = pickResult.bytes;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = l10n.vibe_export_selectImageFailed(e.toString());
      });
    } finally {
      setState(() => _isValidatingImage = false);
    }
  }

  /// 执行导出
  Future<void> _export() async {
    final l10n = context.l10n;
    setState(() {
      _isExporting = true;
      _progress = 0.0;
      _statusMessage = l10n.vibe_export_preparingExport;
    });

    try {
      final entries = await _resolveEntriesForExport();
      if (entries.isEmpty) {
        if (mounted) {
          setState(() {
            _isExporting = false;
            _errorMessage = l10n.vibe_export_noExportableEntries;
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
          _statusMessage = l10n.vibe_export_exportingBundle;
        });
        final bundlePath = await VibeExportAdvancedExecutor.exportBundleFile(
          l10n: l10n,
          entries: entries,
          isSingleBundle: _isSingleBundle,
          exportWholeBundle: _exportWholeBundle,
          selectedInternalVibes: _selectedInternalVibes,
          defaultModel: _defaultModel,
          onStatusMessage: (message) {
            setState(() => _statusMessage = message);
          },
        );
        if (bundlePath != null) {
          results.add('Bundle: $bundlePath');
        }
        completed++;
        setState(() => _progress = completed / total);
      }

      if (_exportZip) {
        setState(() {
          _statusMessage = l10n.vibe_export_exportingZip;
        });
        final zipPath = await VibeExportAdvancedExecutor.exportZipFile(
          entries: entries,
          includeThumbnails: _bundleIncludeThumbnail,
          compress: _bundleCompress,
          defaultModel: _defaultModel,
        );
        if (zipPath != null) {
          results.add('ZIP: $zipPath');
        }
        completed++;
        setState(() => _progress = completed / total);
      }

      // 嵌入图片
      if (_embedIntoImage) {
        setState(() {
          _statusMessage = l10n.vibe_export_embeddingImage;
        });
        final embedPath = await VibeExportAdvancedExecutor.embedIntoImageFile(
          l10n: l10n,
          entries: entries,
          carrierImageBytes: _currentCarrierImageBytes(),
          defaultModel: _defaultModel,
        );
        if (embedPath != null) {
          results.add('Image: $embedPath');
        }
        completed++;
        setState(() => _progress = completed / total);
      }

      // 导出编码
      if (_exportEncoding) {
        setState(() {
          _statusMessage = l10n.vibe_export_exportingEncoding;
        });
        final encodingPath =
            await VibeExportAdvancedExecutor.exportEncodingFile(
              l10n: l10n,
              entries: entries,
              encodingAsJson: _encodingAsJson,
            );
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
        AppToast.success(context, l10n.toast_exportSuccess);
      }
    } catch (e, stack) {
      AppLogger.e('导出 Vibe 失败', e, stack, 'VibeExportDialogAdvanced');
      if (mounted) {
        setState(() {
          _isExporting = false;
          _errorMessage = l10n.vibe_export_exportFailedWithError(
            displayVibeExportError(e),
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

    final resolvedEntries =
        await VibeExportAdvancedExecutor.resolveEntriesForExport(
          l10n: context.l10n,
          isMounted: () => mounted,
          sourceEntries: widget.entries,
          storage: ref.read(vibeLibraryStorageServiceProvider),
          onStatusMessage: (message) {
            setState(() => _statusMessage = message);
          },
          onRebuildCarrierImageOptions: _rebuildCarrierImageOptions,
        );

    _resolvedEntries = resolvedEntries;
    return resolvedEntries;
  }
}
