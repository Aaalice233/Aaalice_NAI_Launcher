import 'dart:typed_data';

import '../../../core/utils/isolate_pool.dart';
import 'unified_metadata_parser.dart';

/// 元数据解析入口：同步读文件与 stealth 整图解码放到后台 isolate。
///
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

  /// 与 [UnifiedMetadataParser.parseFromImage] 结果一致；文本块与 WebP EXIF 在调用方
  /// isolate 直接解析，只有 stealth 整图解码经 [ComputeGate] 交给后台。
  Future<MetadataParseResult> parseBytes(Uint8List bytes) async {
    return UnifiedMetadataParser.parseFromImageWithoutPixelDecode(bytes) ??
        await ComputeGate().runCompute(
          UnifiedMetadataParser.parseFromImage,
          bytes,
          debugLabel: 'image_metadata_from_bytes',
        );
  }
}
