import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/models/vibe/vibe_reference.dart';
import 'app_logger.dart';

/// Vibe 导出工具类
///
/// 用于将 VibeReference 导出为 .naiv4vibe 格式文件
class VibeExportUtils {
  static const String _identifier = 'novelai-vibe-transfer';
  static const int _version = 1;

  /// 导出 VibeReference 为 .naiv4vibe 文件
  ///
  /// [vibe] 要导出的 Vibe 参考对象
  /// [name] 显示名称（可选，默认使用 vibe.displayName）
  /// [defaultModel] 默认模型名称（可选，默认 'nai-diffusion-4-full'）
  ///
  /// 返回：导出成功返回文件路径，失败返回 null
  static Future<String?> exportToNaiv4Vibe(
    VibeReference vibe, {
    String? name,
    String defaultModel = 'nai-diffusion-4-full',
  }) async {
    try {
      // 检查是否有可导出的数据
      if (!_hasExportableData(vibe)) {
        AppLogger.e(
          '无法导出：Vibe 没有编码数据或原始图片',
          null,
          null,
          'VibeExport',
        );
        return null;
      }

      // 显示保存文件对话框
      final fileName = _generateFileName(name ?? vibe.displayName);
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '导出 Vibe 文件',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['naiv4vibe'],
      );

      if (outputFile == null) {
        AppLogger.i('用户取消了文件保存', 'VibeExport');
        return null;
      }

      // 生成 .naiv4vibe JSON 数据
      final jsonData = await _generateNaiv4VibeJson(
        vibe,
        name: name,
        defaultModel: defaultModel,
      );

      // 写入文件
      final file = File(outputFile);
      await file.writeAsString(jsonData);

      AppLogger.i('Vibe 导出成功: $outputFile', 'VibeExport');
      return outputFile;
    } catch (e, stack) {
      AppLogger.e('导出 Vibe 文件失败', e, stack, 'VibeExport');
      return null;
    }
  }

  /// 批量导出多个 Vibe 为 .naiv4vibebundle 文件
  ///
  /// [vibes] 要导出的 Vibe 参考列表
  /// [bundleName] 包名称
  ///
  /// 返回：导出成功返回文件路径，失败返回 null
  static Future<String?> exportToNaiv4VibeBundle(
    List<VibeReference> vibes,
    String bundleName,
  ) async {
    try {
      if (vibes.isEmpty) {
        AppLogger.e('无法导出：Vibe 列表为空', null, null, 'VibeExport');
        return null;
      }

      // 显示保存文件对话框
      final fileName = _generateBundleFileName(bundleName);
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '导出 Vibe Bundle',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['naiv4vibebundle'],
      );

      if (outputFile == null) {
        AppLogger.i('用户取消了文件保存', 'VibeExport');
        return null;
      }

      // 生成 bundle JSON 数据
      final bundleData = await _generateBundleJson(vibes);

      // 写入文件
      final file = File(outputFile);
      await file.writeAsString(bundleData);

      AppLogger.i('Vibe Bundle 导出成功: $outputFile', 'VibeExport');
      return outputFile;
    } catch (e, stack) {
      AppLogger.e('导出 Vibe Bundle 失败', e, stack, 'VibeExport');
      return null;
    }
  }

  /// 生成 .naiv4vibe JSON 数据
  static Future<String> _generateNaiv4VibeJson(
    VibeReference vibe, {
    String? name,
    String defaultModel = 'nai-diffusion-4-full',
  }) async {
    final displayName = name ?? vibe.displayName;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 计算 ID (sha256 hash)
    final id = _generateId(vibe);

    // 确定类型和数据
    final String type;
    final String? imageBase64;
    final Map<String, dynamic> encodings;

    if (vibe.sourceType == VibeSourceType.rawImage &&
        vibe.rawImageData != null) {
      // 原始图片模式：导出为 image 类型
      type = 'image';
      imageBase64 = base64Encode(vibe.rawImageData!);
      encodings = {};
    } else if (vibe.vibeEncoding.isNotEmpty) {
      // 预编码模式：导出为 encoding 类型
      type = 'encoding';
      imageBase64 = vibe.thumbnail != null ? base64Encode(vibe.thumbnail!) : null;

      // 构建 encodings 结构
      encodings = {
        defaultModel: {
          'vibe': {
            'encoding': vibe.vibeEncoding,
          },
        },
      };
    } else {
      // 使用缩略图作为图片
      type = 'image';
      imageBase64 = vibe.thumbnail != null ? base64Encode(vibe.thumbnail!) : null;
      encodings = {};
    }

    // 生成缩略图（如果没有，使用原图缩小）
    final String? thumbnailBase64 = await _generateThumbnailBase64(vibe);

    // 构建 JSON 结构
    final jsonMap = <String, dynamic>{
      'identifier': _identifier,
      'version': _version,
      'type': type,
      'id': id,
      'name': displayName,
      'createdAt': timestamp,
      if (imageBase64 != null) 'image': imageBase64,
      'encodings': encodings,
      if (thumbnailBase64 != null) 'thumbnail': thumbnailBase64,
      'importInfo': {
        'model': defaultModel,
        'information_extracted': vibe.infoExtracted,
        'strength': vibe.strength,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(jsonMap);
  }

  /// 生成 bundle JSON 数据
  static Future<String> _generateBundleJson(
    List<VibeReference> vibes,
  ) async {
    final vibeEntries = <Map<String, dynamic>>[];

    for (final vibe in vibes) {
      if (!_hasExportableData(vibe)) {
        AppLogger.w(
          '跳过无法导出的 Vibe: ${vibe.displayName}',
          'VibeExport',
        );
        continue;
      }

      final entry = await _generateBundleEntry(vibe);
      vibeEntries.add(entry);
    }

    final bundleMap = <String, dynamic>{
      'identifier': 'novelai-vibe-transfer-bundle',
      'version': 1,
      'vibes': vibeEntries,
    };

    return const JsonEncoder.withIndent('  ').convert(bundleMap);
  }

  /// 生成单个 bundle 条目（简化格式，仅包含必要字段）
  ///
  /// 根据 vibe_file_parser.dart 的 fromBundle 解析逻辑，
  /// bundle 条目只需要：name、importInfo.strength、encodings
  static Future<Map<String, dynamic>> _generateBundleEntry(
    VibeReference vibe,
  ) async {
    // 构建 encodings 结构
    final Map<String, dynamic> encodings;

    if (vibe.vibeEncoding.isNotEmpty) {
      encodings = {
        'nai-diffusion-4-full': {
          'vibe': {
            'encoding': vibe.vibeEncoding,
          },
        },
      };
    } else {
      encodings = {};
    }

    return <String, dynamic>{
      'name': vibe.displayName,
      'encodings': encodings,
      'importInfo': {
        'strength': vibe.strength,
      },
    };
  }

  /// 生成缩略图的 base64（如果没有缩略图，尝试生成一个）
  static Future<String?> _generateThumbnailBase64(VibeReference vibe) async {
    // 如果已有缩略图，直接使用
    if (vibe.thumbnail != null && vibe.thumbnail!.isNotEmpty) {
      return base64Encode(vibe.thumbnail!);
    }

    // 如果有原始图片数据，使用原始图片
    if (vibe.rawImageData != null && vibe.rawImageData!.isNotEmpty) {
      // 这里可以添加图片压缩逻辑，但目前直接使用原图
      return base64Encode(vibe.rawImageData!);
    }

    return null;
  }

  /// 检查 Vibe 是否有可导出的数据
  static bool _hasExportableData(VibeReference vibe) {
    return vibe.vibeEncoding.isNotEmpty ||
        (vibe.rawImageData != null && vibe.rawImageData!.isNotEmpty) ||
        (vibe.thumbnail != null && vibe.thumbnail!.isNotEmpty);
  }

  /// 生成唯一 ID (SHA256)
  static String _generateId(VibeReference vibe) {
    final data = <int>[];

    // 使用 vibe 编码或图片数据生成 ID
    if (vibe.vibeEncoding.isNotEmpty) {
      data.addAll(utf8.encode(vibe.vibeEncoding));
    } else if (vibe.rawImageData != null) {
      data.addAll(vibe.rawImageData!);
    } else if (vibe.thumbnail != null) {
      data.addAll(vibe.thumbnail!);
    } else {
      // 回退：使用名称和时间戳
      data.addAll(utf8.encode(vibe.displayName));
      data.addAll(utf8.encode(DateTime.now().toIso8601String()));
    }

    final hash = sha256.convert(data);
    return hash.toString();
  }

  /// 生成文件名
  static String _generateFileName(String name) {
    // 清理文件名中的非法字符
    final sanitized = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim();

    // 限制长度
    var finalName = sanitized;
    if (finalName.length > 50) {
      finalName = finalName.substring(0, 50);
    }

    // 确保不为空
    if (finalName.isEmpty) {
      finalName = 'vibe';
    }

    return '$finalName.naiv4vibe';
  }

  /// 生成 bundle 文件名
  static String _generateBundleFileName(String name) {
    final sanitized = name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim();

    var finalName = sanitized;
    if (finalName.length > 50) {
      finalName = finalName.substring(0, 50);
    }

    if (finalName.isEmpty) {
      finalName = 'vibe-bundle';
    }

    return '$finalName.naiv4vibebundle';
  }

  /// 验证 .naiv4vibe JSON 格式是否有效
  static bool validateNaiv4VibeJson(String jsonString) {
    try {
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      // 检查必需字段
      if (jsonData['identifier'] != _identifier) {
        return false;
      }

      if (jsonData['version'] != _version) {
        return false;
      }

      if (jsonData['id'] == null || jsonData['id'] is! String) {
        return false;
      }

      if (jsonData['name'] == null || jsonData['name'] is! String) {
        return false;
      }

      final type = jsonData['type'] as String?;
      if (type != 'image' && type != 'encoding') {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
