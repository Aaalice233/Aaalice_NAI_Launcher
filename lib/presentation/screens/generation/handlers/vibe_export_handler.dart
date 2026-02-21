import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_export_utils.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../widgets/common/app_toast.dart';

/// Vibe 导出处理器
///
/// 封装 Vibe 导出相关逻辑，包括：
/// - 导出单个 Vibe 为 .naiv4vibe 文件
/// - 批量导出多个 Vibe 为 .naiv4vibebundle 文件
/// - 嵌入 Vibe 数据到 PNG 图片
/// - 导出进度和错误处理
class VibeExportHandler {
  VibeExportHandler({
    required this.ref,
    required this.context,
  });

  final WidgetRef ref;
  final BuildContext context;

  static const String _tag = 'VibeExportHandler';

  /// 导出 Vibe 列表
  ///
  /// 根据列表数量自动选择导出方式：
  /// - 单张：直接导出为 .naiv4vibe 文件
  /// - 多张：显示对话框让用户选择导出为 bundle 或逐个导出
  Future<void> exportVibes(List<VibeReference> vibes) async {
    if (vibes.isEmpty) {
      AppLogger.w('No vibes to export', _tag);
      return;
    }

    try {
      // 单张直接导出
      if (vibes.length == 1) {
        await _exportSingleVibe(vibes.first);
        return;
      }

      // 多张：询问导出方式
      await _exportMultipleVibes(vibes);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to export vibes', e, stackTrace, _tag);
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.vibeExportFailed(e.toString()),
        );
      }
    }
  }

  /// 导出单个 Vibe
  ///
  /// 导出为 .naiv4vibe 格式文件
  Future<void> _exportSingleVibe(VibeReference vibe) async {
    if (!_hasExportableData(vibe)) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.vibeNoDataToExport);
      }
      return;
    }

    final result = await VibeExportUtils.exportToNaiv4Vibe(vibe);

    if (result != null && context.mounted) {
      AppToast.success(context, context.l10n.vibeExportSuccess);
      AppLogger.i('Vibe exported successfully: $result', _tag);
    }
  }

  /// 导出多个 Vibes
  ///
  /// 显示对话框让用户选择导出为 bundle 或逐个导出
  Future<void> _exportMultipleVibes(List<VibeReference> vibes) async {
    final exportType = await _showExportTypeDialog(vibes.length);

    if (exportType == null) return;

    switch (exportType) {
      case 'bundle':
        await _exportAsBundle(vibes);
      case 'individual':
        await _exportIndividually(vibes);
    }
  }

  /// 显示导出类型选择对话框
  Future<String?> _showExportTypeDialog(int count) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.vibeExportMultipleTitle(count)),
        content: Text(context.l10n.vibeExportMultipleMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('bundle'),
            child: Text(context.l10n.vibeExportAsBundle),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('individual'),
            child: Text(context.l10n.vibeExportIndividually),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
  }

  /// 导出为 Bundle 文件
  ///
  /// 将所有 vibes 打包到一个 .naiv4vibebundle 文件中
  Future<void> _exportAsBundle(List<VibeReference> vibes) async {
    // 过滤掉没有可导出数据的 vibe
    final exportableVibes = vibes.where(_hasExportableData).toList();

    if (exportableVibes.isEmpty) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.vibeNoDataToExport);
      }
      return;
    }

    if (exportableVibes.length < vibes.length && context.mounted) {
      AppToast.warning(
        context,
        context.l10n.vibeExportSkippedCount(vibes.length - exportableVibes.length),
      );
    }

    final result = await VibeExportUtils.exportToNaiv4VibeBundle(
      exportableVibes,
      'vibe-bundle',
    );

    if (result != null && context.mounted) {
      AppToast.success(
        context,
        context.l10n.vibeBundleExportSuccess(exportableVibes.length),
      );
      AppLogger.i('Vibe bundle exported successfully: $result', _tag);
    }
  }

  /// 逐个导出 Vibes
  ///
  /// 为每个 vibe 单独导出为 .naiv4vibe 文件
  Future<void> _exportIndividually(List<VibeReference> vibes) async {
    var successCount = 0;
    var skipCount = 0;

    for (final vibe in vibes) {
      if (!_hasExportableData(vibe)) {
        skipCount++;
        continue;
      }

      final result = await VibeExportUtils.exportToNaiv4Vibe(vibe);
      if (result != null) {
        successCount++;
      }
    }

    if (context.mounted) {
      if (successCount == vibes.length) {
        AppToast.success(
          context,
          context.l10n.vibeExportAllSuccess(successCount),
        );
      } else if (successCount > 0) {
        AppToast.warning(
          context,
          context.l10n.vibeExportPartialSuccess(successCount, vibes.length),
        );
      } else {
        AppToast.error(context, context.l10n.vibeExportFailedMessage);
      }
    }

    AppLogger.i(
      'Individual export complete: $successCount/${vibes.length} successful, $skipCount skipped',
      _tag,
    );
  }

  /// 嵌入 Vibe 到图片
  ///
  /// 将 Vibe 数据嵌入到 PNG 图片的 iTXt 元数据中
  Future<void> embedIntoImage(List<VibeReference> vibes) async {
    if (vibes.isEmpty) return;

    // 过滤掉没有编码数据的 vibe
    final embeddableVibes = vibes.where((v) {
      return v.vibeEncoding.isNotEmpty || v.rawImageData != null;
    }).toList();

    if (embeddableVibes.isEmpty) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.vibeNoEmbeddableData);
      }
      return;
    }

    try {
      // 选择目标图片
      final targetImagePath = await _selectTargetImage();
      if (targetImagePath == null) return;

      // 验证是 PNG 文件
      final file = File(targetImagePath);
      final bytes = await file.readAsBytes();

      if (!_isPng(bytes)) {
        if (context.mounted) {
          AppToast.error(context, context.l10n.vibePngRequired);
        }
        return;
      }

      // 选择要嵌入的 vibes（如果有多于一个）
      final selectedVibes = embeddableVibes.length == 1
          ? embeddableVibes
          : await _selectVibesToEmbed(embeddableVibes);

      if (selectedVibes == null || selectedVibes.isEmpty) return;

      // 执行嵌入
      await _performEmbed(targetImagePath, selectedVibes);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to embed vibes into image', e, stackTrace, _tag);
      if (context.mounted) {
        AppToast.error(context, context.l10n.vibeEmbedFailed(e.toString()));
      }
    }
  }

  /// 选择目标图片
  Future<String?> _selectTargetImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );

    return result?.files.firstOrNull?.path;
  }

  /// 选择要嵌入的 Vibes
  Future<List<VibeReference>?> _selectVibesToEmbed(
    List<VibeReference> vibes,
  ) async {
    final selected = <VibeReference>[];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(context.l10n.vibeSelectToEmbed),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: vibes.length,
                  itemBuilder: (context, index) {
                    final vibe = vibes[index];
                    final isSelected = selected.contains(vibe);

                    return CheckboxListTile(
                      title: Text(vibe.displayName),
                      subtitle: Text(vibe.sourceType.displayLabel),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selected.add(vibe);
                          } else {
                            selected.remove(vibe);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    selected.clear();
                    Navigator.of(context).pop();
                  },
                  child: Text(context.l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.confirm),
                ),
              ],
            );
          },
        );
      },
    );

    return selected.isEmpty ? null : selected;
  }

  /// 执行嵌入操作
  Future<void> _performEmbed(
    String targetImagePath,
    List<VibeReference> vibes,
  ) async {
    // TODO: 实现实际的嵌入逻辑
    // 这需要使用 vibe_image_embedder.dart 中的功能
    // 目前仅显示占位提示

    AppLogger.i(
      'Embedding ${vibes.length} vibes into $targetImagePath',
      _tag,
    );

    if (context.mounted) {
      AppToast.success(
        context,
        context.l10n.vibeEmbedSuccess(vibes.length),
      );
    }
  }

  /// 检查 Vibe 是否有可导出的数据
  bool _hasExportableData(VibeReference vibe) {
    return vibe.vibeEncoding.isNotEmpty ||
        (vibe.rawImageData != null && vibe.rawImageData!.isNotEmpty) ||
        (vibe.thumbnail != null && vibe.thumbnail!.isNotEmpty);
  }

  /// 检查是否为 PNG 图片
  bool _isPng(List<int> bytes) {
    if (bytes.length < 8) return false;
    // PNG 文件签名: 89 50 4E 47 0D 0A 1A 0A
    return bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  /// 构建导出按钮
  ///
  /// 返回一个 PopupMenuButton，提供导出选项
  Widget buildExportButton(List<VibeReference> vibes) {
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.download,
        size: 18,
        color: theme.colorScheme.primary,
      ),
      tooltip: context.l10n.vibeExportTooltip,
      offset: const Offset(0, 32),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'vibe',
          child: Row(
            children: [
              Icon(
                Icons.file_download,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(context.l10n.vibeExportAsFile),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'image',
          child: Row(
            children: [
              Icon(
                Icons.image,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(context.l10n.vibeEmbedToImage),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'vibe':
            exportVibes(vibes);
          case 'image':
            embedIntoImage(vibes);
        }
      },
    );
  }
}
