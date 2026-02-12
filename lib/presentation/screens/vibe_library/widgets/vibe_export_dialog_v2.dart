import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_encoding_utils.dart';
import '../../../../core/utils/vibe_export_utils.dart';
import '../../../../core/utils/vibe_image_embedder.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../widgets/common/app_toast.dart';

/// Vibe 导出对话框 V2
/// 参考 NovelAI 官网设计，支持三种导出选项
class VibeExportDialogV2 extends ConsumerStatefulWidget {
  final List<VibeLibraryEntry> entries;

  const VibeExportDialogV2({
    super.key,
    required this.entries,
  });

  @override
  ConsumerState<VibeExportDialogV2> createState() => _VibeExportDialogV2State();
}

class _VibeExportDialogV2State extends ConsumerState<VibeExportDialogV2> {
  // 导出选项状态
  bool _exportBundle = true;
  bool _embedIntoImage = false;
  bool _exportEncoding = false;

  // Bundle 选项
  bool _bundleIncludeThumbnail = true;
  bool _bundleCompress = false;

  // Embed 选项
  String? _selectedImagePath;
  Uint8List? _selectedImagePreview;
  bool _isValidatingImage = false;

  // Encoding 选项
  bool _encodingAsJson = true; // true=JSON, false=Base64

  // 导出状态
  bool _isExporting = false;
  double _progress = 0.0;
  String _statusMessage = '';

  // 错误信息
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
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
                      '导出 Vibe (${widget.entries.length} 个选中)',
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
                        _buildExportBundleOption(theme),
                        const SizedBox(height: 16),
                        _buildEmbedIntoImageOption(theme),
                        const SizedBox(height: 16),
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
                      onPressed: _canExport ? _export : null,
                      icon: const Icon(Icons.file_upload),
                      label: const Text('导出'),
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

  /// 构建导出 Bundle 选项
  Widget _buildExportBundleOption(ThemeData theme) {
    final isDisabled = _embedIntoImage;

    return _OptionCard(
      isSelected: _exportBundle,
      isDisabled: isDisabled,
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _exportBundle = !_exportBundle;
                _validateOptions();
              });
            },
      icon: Icons.folder_zip_outlined,
      title: 'Export Bundle',
      subtitle: '导出为 .naiv4vibe / .naiv4vibebundle 文件',
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
                  title: '包含缩略图',
                  subtitle: '导出文件中包含预览缩略图',
                ),
                const SizedBox(height: 8),
                _buildCheckbox(
                  value: _bundleCompress,
                  onChanged: (value) {
                    setState(() => _bundleCompress = value ?? false);
                  },
                  title: '压缩数据',
                  subtitle: '使用压缩减少文件大小（推荐用于批量导出）',
                ),
              ],
            )
          : null,
    );
  }

  /// 构建嵌入图片选项
  Widget _buildEmbedIntoImageOption(ThemeData theme) {
    final isMultiSelect = widget.entries.length > 1;

    return _OptionCard(
      isSelected: _embedIntoImage,
      isDisabled: isMultiSelect,
      onTap: isMultiSelect
          ? null
          : () {
              setState(() {
                _embedIntoImage = !_embedIntoImage;
                if (_embedIntoImage) {
                  _exportBundle = false;
                }
                _validateOptions();
              });
            },
      icon: Icons.image_outlined,
      title: 'Embed Into Image',
      subtitle: isMultiSelect
          ? '嵌入到图片功能仅支持单个 Vibe'
          : '将 Vibe 数据嵌入到现有 PNG 图片中',
      child: _embedIntoImage && !isMultiSelect
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // 图片选择
                if (_selectedImagePath == null) ...[
                  OutlinedButton.icon(
                    onPressed: _isValidatingImage ? null : _pickImage,
                    icon: _isValidatingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open),
                    label: const Text('选择 PNG 图片...'),
                  ),
                ] else ...[
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
                              _selectedImagePath!.split(Platform.pathSeparator).last,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: _isValidatingImage ? null : _pickImage,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('更换'),
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
                  const SizedBox(height: 8),
                  Text(
                    '将保存为新文件，不会覆盖原图',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
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
          _validateOptions();
        });
      },
      icon: Icons.code,
      title: 'Export as Encodings',
      subtitle: '以编码形式导出数据（JSON 或 Base64）',
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
                      ? '导出为格式化的 JSON 文件，便于阅读和编辑'
                      : '导出为纯 Base64 编码，便于复制和分享',
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

  /// 验证选项
  void _validateOptions() {
    _errorMessage = null;

    // 确保至少选择一种导出方式
    if (!_exportBundle && !_embedIntoImage && !_exportEncoding) {
      _errorMessage = '请至少选择一种导出方式';
      return;
    }

    // 嵌入图片需要选择图片
    if (_embedIntoImage && _selectedImagePath == null) {
      _errorMessage = '请选择一个 PNG 图片用于嵌入';
      return;
    }
  }

  /// 是否可以导出
  bool get _canExport {
    if (_isExporting) return false;
    if (!_exportBundle && !_embedIntoImage && !_exportEncoding) return false;
    if (_embedIntoImage && _selectedImagePath == null) return false;
    return true;
  }

  /// 选择图片
  Future<void> _pickImage() async {
    setState(() => _isValidatingImage = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png'],
        dialogTitle: '选择 PNG 图片',
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
              _errorMessage = '选择的文件不是有效的 PNG 图片';
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
        _errorMessage = '选择图片失败: $e';
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
      _statusMessage = '准备导出...';
    });

    try {
      final results = <String>[];
      var completed = 0;
      final total = [
        if (_exportBundle) 1,
        if (_embedIntoImage) 1,
        if (_exportEncoding) 1,
      ].length;

      // 导出 Bundle
      if (_exportBundle) {
        setState(() => _statusMessage = '正在导出 Bundle...');
        final bundlePath = await _exportBundleFile();
        if (bundlePath != null) {
          results.add('Bundle: $bundlePath');
        }
        completed++;
        setState(() => _progress = completed / total);
      }

      // 嵌入图片
      if (_embedIntoImage && _selectedImagePath != null) {
        setState(() => _statusMessage = '正在嵌入图片...');
        final embedPath = await _embedIntoImageFile();
        if (embedPath != null) {
          results.add('图片: $embedPath');
        }
        completed++;
        setState(() => _progress = completed / total);
      }

      // 导出编码
      if (_exportEncoding) {
        setState(() => _statusMessage = '正在导出编码...');
        final encodingPath = await _exportEncodingFile();
        if (encodingPath != null) {
          results.add('编码: $encodingPath');
        }
        completed++;
        setState(() => _progress = 1.0);
      }

      // 显示成功提示
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, '导出成功');
      }
    } catch (e, stack) {
      AppLogger.e('导出 Vibe 失败', e, stack, 'VibeExportDialogV2');
      if (mounted) {
        setState(() {
          _isExporting = false;
          _errorMessage = '导出失败: $e';
        });
      }
    }
  }

  /// 导出 Bundle 文件
  Future<String?> _exportBundleFile() async {
    final vibes = widget.entries.map((e) => e.toVibeReference()).toList();

    if (vibes.isEmpty) return null;

    if (vibes.length == 1) {
      // 单个导出为 .naiv4vibe
      return VibeExportUtils.exportToNaiv4Vibe(
        vibes.first,
        name: widget.entries.first.displayName,
      );
    } else {
      // 多个导出为 .naiv4vibebundle
      final bundleName = 'vibe_bundle_${vibes.length}';
      return VibeExportUtils.exportToNaiv4VibeBundle(
        vibes,
        bundleName,
      );
    }
  }

  /// 嵌入到图片
  Future<String?> _embedIntoImageFile() async {
    if (_selectedImagePath == null || widget.entries.isEmpty) return null;

    final entry = widget.entries.first;
    final vibeRef = entry.toVibeReference();

    try {
      // 读取原图
      final imageBytes = await File(_selectedImagePath!).readAsBytes();

      // 嵌入 Vibe 数据
      final embeddedBytes = await VibeImageEmbedder.embedVibeToImage(
        imageBytes,
        vibeRef,
      );

      // 选择保存位置
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存嵌入 Vibe 的图片',
        fileName: '${entry.displayName}_embedded.png',
        type: FileType.custom,
        allowedExtensions: ['png'],
      );

      if (savePath == null) return null;

      // 保存文件
      await File(savePath).writeAsBytes(embeddedBytes);

      return savePath;
    } on InvalidImageFormatException catch (e) {
      throw Exception('无效的图片格式: ${e.message}');
    } on VibeEmbedException catch (e) {
      throw Exception('嵌入失败: ${e.message}');
    } catch (e) {
      throw Exception('嵌入图片失败: $e');
    }
  }

  /// 导出编码文件
  Future<String?> _exportEncodingFile() async {
    if (widget.entries.isEmpty) return null;

    // 生成编码内容
    final buffer = StringBuffer();

    if (widget.entries.length == 1) {
      // 单个 Vibe
      final entry = widget.entries.first;
      final vibeRef = entry.toVibeReference();

      if (_encodingAsJson) {
        buffer.writeln(VibeEncodingUtils.encodeToJson(vibeRef));
      } else {
        buffer.writeln(VibeEncodingUtils.encodeToBase64(vibeRef));
      }
    } else {
      // 多个 Vibe - 导出为数组格式
      buffer.writeln('[');
      for (var i = 0; i < widget.entries.length; i++) {
        final entry = widget.entries[i];
        final vibeRef = entry.toVibeReference();

        if (_encodingAsJson) {
          buffer.writeln(VibeEncodingUtils.encodeToJson(vibeRef));
        } else {
          buffer.writeln(VibeEncodingUtils.encodeToBase64(vibeRef));
        }

        if (i < widget.entries.length - 1) {
          buffer.writeln(',');
        }
      }
      buffer.writeln(']');
    }

    // 选择保存位置
    final extension = _encodingAsJson ? 'json' : 'txt';
    final fileName = widget.entries.length == 1
        ? '${widget.entries.first.displayName}_encoding.$extension'
        : 'vibe_encodings_$extension';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: '保存编码文件',
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
                ? theme.colorScheme.outlineVariant.withOpacity(0.3)
                : isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isDisabled
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
              : isSelected
                  ? theme.colorScheme.primaryContainer.withOpacity(0.2)
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
                          ? theme.colorScheme.outline.withOpacity(0.3)
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
                                ? theme.colorScheme.outline.withOpacity(0.5)
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
                                    ? theme.colorScheme.onSurface.withOpacity(0.5)
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
                              ? theme.colorScheme.outline.withOpacity(0.5)
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
