import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../models/prompt/preset_export_format.dart';
import '../models/prompt/random_preset.dart';

part 'preset_export_service.g.dart';

/// 预设导出进度回调
typedef PresetExportProgressCallback = void Function({
  required int current,
  required int total,
  required String currentItem,
});

/// 预设导出服务
///
/// 负责将预设导出为不同格式
class PresetExportService {
  static const String _tag = 'PresetExport';

  /// 导出为 Bundle 格式
  ///
  /// [presets] - 要导出的预设列表
  /// [options] - 导出选项
  /// [onProgress] - 进度回调
  Future<String?> exportAsBundle(
    List<RandomPreset> presets, {
    required PresetExportOptions options,
    PresetExportProgressCallback? onProgress,
  }) async {
    if (presets.isEmpty) {
      AppLogger.w('Cannot export empty presets to bundle', _tag);
      return null;
    }

    final stopwatch = Stopwatch()..start();

    try {
      final outputDir = await _getExportDirectory();
      final fileName = _generateFileName(
        options.fileName,
        'preset-bundle',
        kNaiv4presetbundleExtension,
      );
      final filePath = p.join(outputDir, fileName);

      AppLogger.i(
        'Starting bundle export: ${presets.length} presets to $filePath',
        _tag,
      );

      final bundleData = await _buildBundleData(
        presets,
        options,
        onProgress,
      );

      final file = File(filePath);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(bundleData),
      );

      stopwatch.stop();
      AppLogger.i(
        'Bundle export completed: ${presets.length} presets in ${stopwatch.elapsedMilliseconds}ms',
        _tag,
      );

      return filePath;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.e('Bundle export failed', e, stackTrace, _tag);
      return null;
    }
  }

  /// 导出为 JSON 格式
  ///
  /// [preset] - 要导出的预设
  /// [options] - 导出选项
  Future<String?> exportAsJson(
    RandomPreset preset, {
    required PresetExportOptions options,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final outputDir = await _getExportDirectory();
      final fileName = _generateFileName(
        options.fileName,
        'preset-${preset.name}',
        'json',
      );
      final filePath = p.join(outputDir, fileName);

      AppLogger.i(
        'Starting JSON export: ${preset.name} to $filePath',
        _tag,
      );

      final exportData = _buildPresetExportData(preset, options);

      final file = File(filePath);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportData),
      );

      stopwatch.stop();
      AppLogger.i(
        'JSON export completed: ${preset.name} in ${stopwatch.elapsedMilliseconds}ms',
        _tag,
      );

      return filePath;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.e('JSON export failed', e, stackTrace, _tag);
      return null;
    }
  }

  /// 导出为纯编码格式
  ///
  /// [presets] - 要导出的预设列表
  /// [options] - 导出选项
  /// [onProgress] - 进度回调
  ///
  /// 对于预设，编码格式导出为 Base64 编码的 JSON 数据
  Future<String?> exportAsEncoding(
    List<RandomPreset> presets, {
    required PresetExportOptions options,
    PresetExportProgressCallback? onProgress,
  }) async {
    if (presets.isEmpty) {
      AppLogger.w('Cannot export empty presets to encoding', _tag);
      return null;
    }

    final stopwatch = Stopwatch()..start();

    try {
      final outputDir = await _getExportDirectory();
      final fileName = _generateFileName(
        options.fileName,
        'preset-encodings',
        'txt',
      );
      final filePath = p.join(outputDir, fileName);

      AppLogger.i(
        'Starting encoding export: ${presets.length} presets to $filePath',
        _tag,
      );

      final encodingList = <String>[];

      for (var i = 0; i < presets.length; i++) {
        final preset = presets[i];

        onProgress?.call(
          current: i,
          total: presets.length,
          currentItem: preset.name,
        );

        // 将预设数据编码为 Base64
        final exportData = _buildPresetExportData(preset, options);
        final jsonString = const JsonEncoder().convert(exportData);
        final base64String = base64Encode(utf8.encode(jsonString));

        encodingList.add(base64String);
        AppLogger.d(
          'Added encoding for: ${preset.name} (${i + 1}/${presets.length})',
          _tag,
        );
      }

      if (encodingList.isEmpty) {
        AppLogger.w('No valid encodings to export', _tag);
        return null;
      }

      final file = File(filePath);
      await file.writeAsString(encodingList.join('\n'));

      onProgress?.call(
        current: presets.length,
        total: presets.length,
        currentItem: '',
      );

      stopwatch.stop();
      AppLogger.i(
        'Encoding export completed: ${encodingList.length} encodings in ${stopwatch.elapsedMilliseconds}ms',
        _tag,
      );

      return filePath;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.e('Encoding export failed', e, stackTrace, _tag);
      return null;
    }
  }

  /// 通用导出方法
  ///
  /// 根据 options 中的 format 自动选择导出方式
  Future<String?> export(
    List<RandomPreset> presets, {
    required PresetExportOptions options,
    PresetExportProgressCallback? onProgress,
  }) async {
    switch (options.format) {
      case PresetExportFormat.bundle:
        return exportAsBundle(
          presets,
          options: options,
          onProgress: onProgress,
        );
      case PresetExportFormat.json:
        // JSON 格式只支持单个导出
        if (presets.length > 1) {
          AppLogger.w(
            'JSON format only supports single preset export, '
            'falling back to bundle format',
            _tag,
          );
          return exportAsBundle(
            presets,
            options: options,
            onProgress: onProgress,
          );
        }
        return exportAsJson(
          presets.first,
          options: options,
        );
      case PresetExportFormat.encoding:
        return exportAsEncoding(
          presets,
          options: options,
          onProgress: onProgress,
        );
    }
  }

  /// 导出单个预设
  ///
  /// 根据 options 中的 format 自动选择导出方式
  Future<String?> exportSingle(
    RandomPreset preset, {
    required PresetExportOptions options,
  }) async {
    switch (options.format) {
      case PresetExportFormat.bundle:
        return exportAsBundle(
          [preset],
          options: options,
        );
      case PresetExportFormat.json:
        return exportAsJson(
          preset,
          options: options,
        );
      case PresetExportFormat.encoding:
        return exportAsEncoding(
          [preset],
          options: options,
        );
    }
  }

  /// 构建 Bundle 数据
  Future<Map<String, dynamic>> _buildBundleData(
    List<RandomPreset> presets,
    PresetExportOptions options,
    PresetExportProgressCallback? onProgress,
  ) async {
    final presetDataList = <Map<String, dynamic>>[];

    for (var i = 0; i < presets.length; i++) {
      final preset = presets[i];

      onProgress?.call(
        current: i,
        total: presets.length,
        currentItem: preset.name,
      );

      final presetData = _buildPresetExportData(preset, options);
      presetDataList.add(presetData);

      AppLogger.d(
        'Added to bundle: ${preset.name} (${i + 1}/${presets.length})',
        _tag,
      );
    }

    return {
      'identifier': 'novelai-random-preset-bundle',
      'version': options.version,
      'exportedAt': DateTime.now().toIso8601String(),
      'presetCount': presets.length,
      'description': options.description,
      'presets': presetDataList,
    };
  }

  /// 构建单个预设的导出数据
  Map<String, dynamic> _buildPresetExportData(
    RandomPreset preset,
    PresetExportOptions options,
  ) {
    final data = <String, dynamic>{
      'name': preset.name,
      'description': preset.description,
      'version': preset.version,
    };

    // 添加完整数据（如果启用）
    if (options.includeFullData) {
      data['algorithmConfig'] = preset.algorithmConfig.toJson();
      data['categories'] = preset.categories.map((c) => c.toJson()).toList();
      data['tagGroupMappings'] =
          preset.tagGroupMappings.map((m) => m.toJson()).toList();
      data['poolMappings'] =
          preset.poolMappings.map((m) => m.toJson()).toList();
    }

    // 添加时间信息（如果启用）
    if (options.includeCreatedAt && preset.createdAt != null) {
      data['createdAt'] = preset.createdAt!.toIso8601String();
    }
    if (options.includeUpdatedAt && preset.updatedAt != null) {
      data['updatedAt'] = preset.updatedAt!.toIso8601String();
    }

    // 添加预览信息（如果启用）
    if (options.includePreview) {
      data['preview'] = {
        'categoryCount': preset.categoryCount,
        'enabledCategoryCount': preset.enabledCategoryCount,
        'totalTagCount': preset.totalTagCount,
        'enabledTagCount': preset.enabledTagCount,
      };
    }

    return data;
  }

  /// 获取导出目录
  Future<String> _getExportDirectory() async {
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return downloadsDir.path;
      }
    } catch (e) {
      AppLogger.w('Failed to get downloads directory: $e', _tag);
    }

    // 降级到应用文档目录
    final appDir = await getApplicationDocumentsDirectory();
    return appDir.path;
  }

  /// 生成文件名
  String _generateFileName(
    String? customName,
    String defaultBaseName,
    String extension,
  ) {
    final timestamp = DateTime.now();
    final formattedTime =
        '${timestamp.year}${_twoDigits(timestamp.month)}${_twoDigits(timestamp.day)}_'
        '${_twoDigits(timestamp.hour)}${_twoDigits(timestamp.minute)}${_twoDigits(timestamp.second)}';

    final baseName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : '${defaultBaseName}_$formattedTime';

    // 清理文件名中的非法字符
    final sanitizedBaseName = _sanitizeFileName(baseName);

    return '$sanitizedBaseName.$extension';
  }

  /// 清理文件名中的非法字符
  String _sanitizeFileName(String fileName) {
    // 移除或替换 Windows/Unix 文件系统中的非法字符
    return fileName
        .replaceAll(RegExp(r'[<>:"/\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 将数字格式化为两位字符串
  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}

/// PresetExportService Provider
@riverpod
PresetExportService presetExportService(Ref ref) {
  return PresetExportService();
}
