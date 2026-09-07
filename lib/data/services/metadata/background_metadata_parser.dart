import 'dart:typed_data';

import '../../../core/utils/isolate_pool.dart';
import 'unified_metadata_parser.dart';

Future<MetadataParseResult> parseMetadataFileInBackground(String path) =>
    ComputeGate().runCompute(_parseFile, path, debugLabel: 'metadata-file');

Future<MetadataParseResult> parseMetadataBytesInBackground(Uint8List bytes) =>
    ComputeGate().runCompute(_parseBytes, bytes, debugLabel: 'metadata-bytes');

MetadataParseResult _parseFile(String path) =>
    UnifiedMetadataParser.parseFromFile(
      path,
      useGradualRead: true,
      useCache: true,
    );

MetadataParseResult _parseBytes(Uint8List bytes) =>
    UnifiedMetadataParser.parseFromImage(bytes);
