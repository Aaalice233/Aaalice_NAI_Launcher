import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/image/image_params.dart';
import '../../../data/services/fixed_tag/fixed_tag_usage_record_store.dart';
import '../image_generation_provider.dart';

final dlssEnhancementAdopterProvider = Provider(DlssEnhancementAdopter.new);

/// Keeps a manually enhanced image as the latest saved generation result.
final class DlssEnhancementAdopter {
  DlssEnhancementAdopter(this.ref);

  final Ref ref;

  /// Returns the saved file path, or null when the file could not be written.
  Future<String?> adopt({
    required Uint8List result,
    required Uint8List source,
  }) async {
    final generation = ref.read(imageGenerationNotifierProvider.notifier);
    // Persisting before startup restore completes would evict older records.
    await generation.ensureGenerationHistoryRestored();
    final savedPath = await generation.registerExternalImage(
      result,
      // Bytes stay verbatim; params only seed filenames without metadata.
      params: const ImageParams(),
      comparisonSourceImage: source,
      saveToLocal: true,
      replaceCurrentDisplay: true,
      embedNaiMetadata: false,
    );
    // Records key on content hash, not the saved file: a later manual save
    // preserves these bytes and adds no record of its own.
    await FixedTagUsageRecordStore().copyForDerivative(
      sourceBytes: source,
      outputBytes: result,
    );
    return savedPath;
  }
}
