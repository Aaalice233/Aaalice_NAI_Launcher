import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../../core/services/file_export_service.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/utils/vibe_encoding_utils.dart';
import '../../../../../core/utils/vibe_export_utils.dart';
import '../../../../../core/utils/vibe_image_embedder.dart';
import '../../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../../data/models/vibe/vibe_reference.dart';
import '../../../../../data/services/vibe_file_storage_service.dart';
import '../../../../../data/services/vibe_library_storage_service.dart';

/// 选择并校验 PNG 载体图片的结果。
class VibeCarrierPngPickResult {
  const VibeCarrierPngPickResult.picked({
    required this.path,
    required this.bytes,
  }) : errorMessage = null,
       cancelled = false;

  const VibeCarrierPngPickResult.invalid(this.errorMessage)
    : path = null,
      bytes = null,
      cancelled = false;

  const VibeCarrierPngPickResult.cancelled()
    : path = null,
      bytes = null,
      errorMessage = null,
      cancelled = true;

  final String? path;
  final Uint8List? bytes;
  final String? errorMessage;
  final bool cancelled;
}

/// 封装高级 Vibe 导出的异步条目解析与各格式导出逻辑。
class VibeExportAdvancedExecutor {
  const VibeExportAdvancedExecutor._();

  static Future<VibeCarrierPngPickResult> pickCarrierPngImage({
    required AppLocalizations l10n,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'],
      dialogTitle: l10n.vibe_export_selectPngImage,
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
          return VibeCarrierPngPickResult.invalid(
            l10n.vibe_export_invalidPngImage,
          );
        }

        return VibeCarrierPngPickResult.picked(path: path, bytes: bytes);
      }
    }

    return const VibeCarrierPngPickResult.cancelled();
  }

  static Future<List<VibeLibraryEntry>> resolveEntriesForExport({
    required AppLocalizations l10n,
    required bool Function() isMounted,
    required List<VibeLibraryEntry> sourceEntries,
    required VibeLibraryStorageService storage,
    required ValueChanged<String> onStatusMessage,
    required ValueChanged<List<VibeLibraryEntry>> onRebuildCarrierImageOptions,
  }) async {
    if (sourceEntries.isEmpty) {
      return const <VibeLibraryEntry>[];
    }

    final resolvedEntries = <VibeLibraryEntry>[];
    for (var i = 0; i < sourceEntries.length; i++) {
      final sourceEntry = sourceEntries[i];
      if (isMounted()) {
        onStatusMessage(
          l10n.vibe_export_preparingVibeProgress(i + 1, sourceEntries.length),
        );
      }

      final resolvedEntry = await storage.getEntry(sourceEntry.id);
      resolvedEntries.add(resolvedEntry ?? sourceEntry);
    }

    if (resolvedEntries.length == 1) {
      onRebuildCarrierImageOptions(resolvedEntries);
    }
    return resolvedEntries;
  }

  /// 导出 Bundle 文件
  static Future<String?> exportBundleFile({
    required AppLocalizations l10n,
    required List<VibeLibraryEntry> entries,
    required bool isSingleBundle,
    required bool exportWholeBundle,
    required List<bool> selectedInternalVibes,
    required String defaultModel,
    required ValueChanged<String> onStatusMessage,
  }) async {
    // 处理单选 bundle 且选择导出内部单个 vibe 的情况
    if (isSingleBundle && !exportWholeBundle) {
      return exportSelectedInternalVibes(
        l10n: l10n,
        entries: entries,
        selectedInternalVibes: selectedInternalVibes,
        defaultModel: defaultModel,
        onStatusMessage: onStatusMessage,
      );
    }

    final vibes = <VibeReference>[];
    for (final entry in entries) {
      vibes.addAll(await resolveEntryVibes(entry));
    }

    if (vibes.isEmpty) return null;

    if (vibes.length == 1 && !(isSingleBundle && exportWholeBundle)) {
      // 单个导出为 .naiv4vibe
      return VibeExportUtils.exportToNaiv4Vibe(
        vibes.first,
        name: entries.first.displayName,
        defaultModel: defaultModel,
      );
    } else {
      // 多个导出为 .naiv4vibebundle
      final bundleName = 'vibe_bundle_${vibes.length}';
      return VibeExportUtils.exportToNaiv4VibeBundle(
        vibes,
        bundleName,
        defaultModel: defaultModel,
      );
    }
  }

  static Future<String?> exportZipFile({
    required List<VibeLibraryEntry> entries,
    required bool includeThumbnails,
    required bool compress,
    required String defaultModel,
  }) async {
    if (entries.isEmpty) return null;

    final zipName = entries.length == 1
        ? '${entries.first.displayName}_vibe_files'
        : 'vibe_library_${entries.length}_items';
    return VibeExportUtils.exportEntriesToZip(
      entries,
      name: zipName,
      includeThumbnails: includeThumbnails,
      compress: compress,
      defaultModel: defaultModel,
    );
  }

  /// 导出选中的内部 vibe（从 bundle 中提取）
  static Future<String?> exportSelectedInternalVibes({
    required AppLocalizations l10n,
    required List<VibeLibraryEntry> entries,
    required List<bool> selectedInternalVibes,
    required String defaultModel,
    required ValueChanged<String> onStatusMessage,
  }) async {
    final entry = entries.first;
    final filePath = entry.filePath;

    if (filePath == null || filePath.isEmpty) {
      throw Exception(l10n.vibe_export_bundleFilePathEmpty);
    }

    final storageService = VibeFileStorageService();
    final selectedIndices = <int>[];

    for (var i = 0; i < selectedInternalVibes.length; i++) {
      if (selectedInternalVibes[i]) {
        selectedIndices.add(i);
      }
    }

    if (selectedIndices.isEmpty) return null;

    final outputDirectory = selectedIndices.length > 1
        ? await FileExportService.pickExportDirectory(
            dialogTitle: l10n.vibe_export_selectVibeExportFolder,
          )
        : null;
    if (selectedIndices.length > 1 &&
        (outputDirectory == null || outputDirectory.isEmpty)) {
      return null;
    }

    final exportedPaths = <String>[];

    for (var i = 0; i < selectedIndices.length; i++) {
      final index = selectedIndices[i];
      onStatusMessage(
        l10n.vibe_export_extractingVibeProgress(i + 1, selectedIndices.length),
      );

      final vibe = await storageService.extractVibeFromBundle(filePath, index);
      if (vibe == null) {
        AppLogger.w('无法提取索引 $index 的 vibe', 'VibeExportDialogAdvanced');
        continue;
      }

      final path = await VibeExportUtils.exportToNaiv4Vibe(
        vibe,
        name: vibe.displayName,
        defaultModel: defaultModel,
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
  static Future<String?> embedIntoImageFile({
    required AppLocalizations l10n,
    required List<VibeLibraryEntry> entries,
    required Uint8List? carrierImageBytes,
    required String defaultModel,
  }) async {
    if (entries.isEmpty) return null;
    if (entries.length > 1) {
      return null;
    }

    if (carrierImageBytes == null) {
      return null;
    }

    try {
      final vibes = await resolveEntryVibes(entries.first);
      if (vibes.isEmpty) {
        return null;
      }
      final fileName = vibes.length == 1
          ? '${entries.first.displayName}_vibe.png'
          : 'vibe_bundle_${vibes.length}.png';

      return await VibeExportUtils.exportToEmbeddedPng(
        vibes,
        carrierImageBytes: carrierImageBytes,
        fileName: fileName,
        defaultModel: defaultModel,
      );
    } on InvalidImageFormatException catch (e) {
      throw Exception(l10n.vibe_export_invalidImageFormatWithError(e.message));
    } on VibeEmbedException catch (e) {
      throw Exception(l10n.vibe_export_embedFailedWithError(e.message));
    } catch (e) {
      throw Exception(l10n.vibe_export_embedImageFailedWithError(e.toString()));
    }
  }

  static Future<List<VibeReference>> resolveEntryVibes(
    VibeLibraryEntry entry,
  ) async {
    if (!entry.isBundle) {
      return [entry.toVibeReference()];
    }

    final filePath = entry.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      final storedVibes = await VibeFileStorageService().extractVibesFromBundle(
        filePath,
      );
      if (storedVibes.isNotEmpty) {
        return storedVibes;
      }
    }

    final names = entry.bundledVibeNames;
    final encodings = entry.bundledVibeEncodings;
    if (names == null ||
        names.isEmpty ||
        encodings == null ||
        encodings.isEmpty) {
      return const <VibeReference>[];
    }

    final previews = entry.bundledVibePreviews;
    final strengths = entry.bundledVibeStrengths;
    final informationExtracted = entry.bundledVibeInfoExtracted;
    final encodingModels = entry.bundledVibeEncodingModels;
    return [
      for (var i = 0; i < names.length && i < encodings.length; i++)
        VibeReference(
          displayName: names[i],
          vibeEncoding: encodings[i],
          thumbnail: previews != null && i < previews.length
              ? previews[i]
              : null,
          strength: strengths != null && i < strengths.length
              ? strengths[i]
              : entry.strength,
          infoExtracted:
              informationExtracted != null && i < informationExtracted.length
              ? informationExtracted[i]
              : entry.infoExtracted,
          encodingModel: encodingModels != null && i < encodingModels.length
              ? encodingModels[i]
              : entry.encodingModel,
          sourceType: VibeSourceType.naiv4vibebundle,
        ),
    ];
  }

  /// 导出编码文件
  static Future<String?> exportEncodingFile({
    required AppLocalizations l10n,
    required List<VibeLibraryEntry> entries,
    required bool encodingAsJson,
  }) async {
    if (entries.isEmpty) return null;

    // 生成编码内容
    final buffer = StringBuffer();

    if (entries.length == 1) {
      // 单个 Vibe
      final entry = entries.first;
      final vibeRef = entry.toVibeReference();

      if (encodingAsJson) {
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

        if (encodingAsJson) {
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
    final extension = encodingAsJson ? 'json' : 'txt';
    final fileName = entries.length == 1
        ? '${entries.first.displayName}_encoding.$extension'
        : 'vibe_encodings_$extension';

    return FileExportService.saveText(
      text: buffer.toString(),
      fileName: fileName,
      dialogTitle: l10n.vibe_export_saveEncodingFile,
      mimeType: encodingAsJson ? 'application/json' : 'text/plain',
      allowedExtensions: [extension],
    );
  }
}
