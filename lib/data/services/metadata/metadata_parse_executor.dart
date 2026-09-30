import 'dart:typed_data';

import '../../../core/utils/isolate_pool.dart';
import 'unified_metadata_parser.dart';

/// 在后台 isolate 执行元数据解析。
///
/// 解析含同步文件读取，找不到文本元数据时还会整图解码查找 stealth 数据。
class MetadataParseExecutor {
  const MetadataParseExecutor();

  Future<MetadataParseResult> parseFile(String path) {
    return ComputeGate().runCompute(
      _parseFileInBackground,
      path,
      debugLabel: 'image_metadata_from_file',
    );
  }

  Future<MetadataParseResult> parseBytes(Uint8List bytes) {
    return ComputeGate().runCompute(
      UnifiedMetadataParser.parseFromImage,
      bytes,
      debugLabel: 'image_metadata_from_bytes',
    );
  }
}

// 解析器的静态结果缓存随一次性 isolate 销毁，写入只是白费。
MetadataParseResult _parseFileInBackground(String path) {
  return UnifiedMetadataParser.parseFromFile(
    path,
    useGradualRead: true,
    useCache: false,
  );
}
