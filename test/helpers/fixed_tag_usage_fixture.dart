import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/image_save_utils.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

/// Builds a single positive prefix entry whose id doubles as its rendered text.
FixedTagUsageSnapshot fixedTagUsageSnapshotOf(String id) =>
    FixedTagUsageSnapshot(
      entries: [
        FixedTagUsageEntry(
          fixedTagId: id,
          name: id,
          content: id,
          weight: 1,
          renderedContent: id,
          position: FixedTagPosition.prefix,
          promptType: FixedTagPromptType.positive,
          order: 0,
        ),
      ],
    );

/// Builds a 2×2 PNG carrying NovelAI's own metadata chunks.
Future<Uint8List> novelAiPngBytes(String prompt) =>
    ImageSaveUtils.rebuildImageBytesWithMetadata(
      imageBytes: Uint8List.fromList(
        img.encodePng(img.Image(width: 2, height: 2)),
      ),
      params: ImageParams(prompt: prompt, width: 2, height: 2),
      actualSeed: 42,
    );

/// Writes [snapshot] into the PNG Comment so the parser reports it as a fact.
Uint8List embedFixedTagUsageSnapshot(
  Uint8List bytes,
  FixedTagUsageSnapshot snapshot,
) {
  final comment =
      jsonDecode(UnifiedMetadataParser.extractPngTextData(bytes)['Comment']!)
          as Map<String, dynamic>;
  comment['aaalice_fixed_tags'] = snapshot.toJson();
  return UnifiedMetadataParser.embedTextChunkOnly(
    bytes,
    'Comment',
    jsonEncode(comment),
  );
}
