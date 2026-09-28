import 'package:flutter/foundation.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/isolate_pool.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../../data/services/image_metadata_service.dart';
import '../../../data/services/metadata/unified_metadata_parser.dart';
import '../../../data/services/vibe_metadata_service.dart';
import '../../utils/dropped_file_reader.dart';
import 'image_destination_dialog.dart';

class DroppedImageMetadataDetection {
  final NaiImageMetadata? metadata;
  final String? parseError;

  const DroppedImageMetadataDetection({this.metadata, this.parseError});
}

class DroppedImageInspection {
  const DroppedImageInspection({
    required this.previewBytes,
    required this.metadataDetection,
    required this.detectedVibe,
    required this.detectedVibes,
  });

  final Uint8List previewBytes;
  final DroppedImageMetadataDetection metadataDetection;
  final VibeReference? detectedVibe;
  final List<VibeReference> detectedVibes;
}

class DroppedImageInspector {
  const DroppedImageInspector();

  Future<DroppedImageInspection> inspect(DroppedFileData fileData) async {
    final fileName = fileData.fileName;
    final bytes = fileData.bytes;
    final isDiscordAttachment =
        fileData.sourceUri != null &&
        DroppedFileReader.isDiscordAttachmentUri(fileData.sourceUri!);
    var metadataDetection = await detectDroppedImageMetadata(
      fileName,
      bytes,
      metadataBytes: fileData.metadataBytes,
      inspectNonPngStealth: isDiscordAttachment,
    );
    if (metadataDetection.metadata == null &&
        fileData.metadataBytes == null &&
        isDiscordAttachment) {
      final metadataBytes =
          await DroppedFileReader.downloadRemoteMetadataPrefix(
            fileData.sourceUri!,
            logTag: 'DropHandler',
          );
      if (metadataBytes != null) {
        final remoteDetection = await detectDroppedImageMetadata(
          fileName,
          bytes,
          metadataBytes: metadataBytes,
        );
        metadataDetection = DroppedImageMetadataDetection(
          metadata: remoteDetection.metadata,
          parseError:
              remoteDetection.parseError ?? metadataDetection.parseError,
        );
      }
    }

    final detectedVibe = fileData.imageBytesArePreview
        ? null
        : await _detectVibeMetadata(fileName, bytes);
    final detectedVibes = fileData.imageBytesArePreview
        ? const <VibeReference>[]
        : await _detectAllVibesInPng(fileName, bytes);
    return DroppedImageInspection(
      previewBytes: bytes,
      metadataDetection: metadataDetection,
      detectedVibe: detectedVibe,
      detectedVibes: detectedVibes,
    );
  }

  Future<Uint8List?> resolveOriginalBytes(DroppedFileData fileData) async {
    if (!fileData.imageBytesArePreview) return fileData.bytes;
    final sourceUri = fileData.sourceUri;
    if (sourceUri == null) return null;
    final originalImage = await DroppedFileReader.downloadRemoteImage(
      sourceUri,
      logTag: 'DropHandler',
    );
    return originalImage?.bytes;
  }

  Future<VibeReference?> _detectVibeMetadata(
    String fileName,
    Uint8List bytes,
  ) async {
    if (!fileName.toLowerCase().endsWith('.png')) return null;
    try {
      final vibe = await VibeMetadataService().extractVibeFromImage(bytes);
      if (vibe != null) {
        AppLogger.i(
          'Detected pre-encoded Vibe in dropped image: ${vibe.displayName}',
          'DropHandler',
        );
      }
      return vibe;
    } catch (error) {
      AppLogger.d('Failed to detect Vibe metadata: $error', 'DropHandler');
      return null;
    }
  }

  Future<List<VibeReference>> _detectAllVibesInPng(
    String fileName,
    Uint8List bytes,
  ) async {
    if (!fileName.toLowerCase().endsWith('.png')) return const [];
    try {
      final vibes = await VibeMetadataService().extractAllVibesFromImage(bytes);
      if (vibes.isNotEmpty) {
        AppLogger.i(
          'Detected ${vibes.length} Vibes in dropped image: '
              '${vibes.map((vibe) => vibe.displayName).join(", ")}',
          'DropHandler',
        );
      }
      return vibes;
    } catch (error) {
      AppLogger.d('Failed to detect all Vibes: $error', 'DropHandler');
      return const [];
    }
  }
}

Future<DroppedImageMetadataDetection> detectDroppedImageMetadata(
  String fileName,
  Uint8List bytes, {
  Uint8List? metadataBytes,
  bool inspectNonPngStealth = false,
}) async {
  try {
    String? parseError;
    NaiImageMetadata? metadata;

    void recordParseFailure(MetadataParseResult result, Uint8List sourceBytes) {
      if (parseError == null &&
          _isDroppedMetadataParseFailure(result.errorMessage, sourceBytes)) {
        parseError = result.errorMessage;
      }
    }

    if (metadataBytes != null &&
        UnifiedMetadataParser.isPngHeader(metadataBytes)) {
      final textData = UnifiedMetadataParser.extractPngTextData(metadataBytes);
      final result = UnifiedMetadataParser.parseFromTextData(textData);
      metadata = result.success ? result.metadata : null;
      if (metadata == null || !metadata.hasData) {
        recordParseFailure(result, metadataBytes);
      }
    }

    if (metadata == null || !metadata.hasData) {
      final result = await ImageMetadataService()
          .getMetadataParseResultFromBytes(bytes);
      metadata = result.success ? result.metadata : null;
      if (metadata == null || !metadata.hasData) {
        recordParseFailure(result, bytes);
      }
    }

    if ((metadata == null || !metadata.hasData) && inspectNonPngStealth) {
      metadata = await ComputeGate().runCompute(
        _parseStealthMetadataFromImageBytes,
        bytes,
        debugLabel: 'dropped_image_stealth_metadata',
      );
    }
    if (metadata != null && metadata.hasData) {
      AppLogger.i(
        'Detected NovelAI metadata in dropped image: $fileName',
        'DropHandler',
      );
      return DroppedImageMetadataDetection(metadata: metadata);
    }
    return DroppedImageMetadataDetection(parseError: parseError);
  } catch (error) {
    AppLogger.d('Failed to detect NovelAI metadata: $error', 'DropHandler');
    return DroppedImageMetadataDetection(parseError: error.toString());
  }
}

Future<NaiImageMetadata?> detectImportableDroppedImageMetadata(
  String fileName,
  Uint8List bytes, {
  Uint8List? metadataBytes,
  bool inspectNonPngStealth = false,
}) async {
  return (await detectDroppedImageMetadata(
    fileName,
    bytes,
    metadataBytes: metadataBytes,
    inspectNonPngStealth: inspectNonPngStealth,
  )).metadata;
}

bool _isDroppedMetadataParseFailure(String? errorMessage, Uint8List bytes) {
  if (errorMessage == null || errorMessage.isEmpty) return false;
  final fieldCount = RegExp(
    r'from (\d+) fields',
  ).firstMatch(errorMessage)?.group(1);
  if (fieldCount != null) {
    if (int.parse(fieldCount) == 0) return false;
    final textData = UnifiedMetadataParser.extractPngTextData(bytes);
    final normalizedData = {
      for (final entry in textData.entries)
        entry.key.toLowerCase(): entry.value,
    };
    const generationPayloadKeys = {
      'comment',
      'parameters',
      'sd:parameters',
      'prompt',
      'workflow',
      'nai',
      'novelai',
      'sd-metadata',
      'fooocus',
      'draw_things',
      'drawthings',
    };
    if (normalizedData.keys.any(generationPayloadKeys.contains)) return true;
    final description = normalizedData['description'];
    return description != null &&
        (description.contains('Steps:') || description.contains('Sampler:'));
  }
  if (errorMessage.startsWith('No EXIF UserComment metadata')) return false;
  if (errorMessage.startsWith('Unsupported image container')) return false;
  return true;
}

NaiImageMetadata? _parseStealthMetadataFromImageBytes(Uint8List bytes) {
  final result = UnifiedMetadataParser.parseStealthFromImageBytes(bytes);
  return result.success ? result.metadata : null;
}

bool imageDestinationRequiresOriginalBytes(ImageDestination destination) {
  return switch (destination) {
    ImageDestination.img2img ||
    ImageDestination.reversePrompt ||
    ImageDestination.vibeTransfer ||
    ImageDestination.vibeTransferRaw ||
    ImageDestination.characterReference => true,
    ImageDestination.vibeTransferReuse ||
    ImageDestination.saveToVibeLibrary ||
    ImageDestination.extractMetadata ||
    ImageDestination.addToQueue => false,
  };
}
