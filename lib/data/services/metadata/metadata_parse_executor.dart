import 'dart:typed_data';

import '../../../core/utils/isolate_pool.dart';
import 'unified_metadata_parser.dart';

/// 在后台 isolate 执行元数据解析。
///
/// 解析含同步文件读取，找不到文本元数据时还会整图解码查找 stealth 数据。
/// 不复用扫描的 worker 池：池只收文件路径、结果不含 sourceFormat，且任务超时即判失败。
class MetadataParseExecutor {
  const MetadataParseExecutor();

  Future<MetadataParseResult> parseFile(String path) {
    return ComputeGate().runCompute(
      UnifiedMetadataParser.parseFromFile,
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
