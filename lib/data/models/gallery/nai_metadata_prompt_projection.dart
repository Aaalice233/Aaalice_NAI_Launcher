import 'dart:convert';
import 'dart:typed_data';

import '../../../core/constants/api_constants.dart';
import '../../../core/enums/precise_ref_type.dart';
import '../../../core/utils/portable_logger.dart';
import '../image/image_params.dart';
import 'nai_image_metadata.dart';

/// Projects imported metadata into prompt text and reusable image references.
///
/// This keeps display/copy policy separate from the persisted Hive/Freezed
/// record while preserving the model's compatibility getters.
class NaiMetadataPromptProjection {
  const NaiMetadataPromptProjection(this.metadata);

  final NaiImageMetadata metadata;

  bool get hasData =>
      metadata.prompt.isNotEmpty ||
      metadata.negativePrompt.isNotEmpty ||
      metadata.characterPrompts.isNotEmpty ||
      metadata.characterNegativePrompts.isNotEmpty ||
      metadata.characterInfos.isNotEmpty ||
      metadata.seed != null ||
      metadata.vibeReferences.isNotEmpty ||
      metadata.preciseReferenceImages.isNotEmpty;

  bool get hasRecordedTransparentBackgroundTag =>
      metadata.transparentBackground == true &&
      metadata.prompt
          .split(',')
          .any(
            (tag) =>
                tag.trim().toLowerCase() ==
                QualityTags.transparentBackgroundTag.toLowerCase(),
          );

  bool get hasCharacters => metadata.characterPrompts.isNotEmpty;

  bool get hasSeparatedFields =>
      metadata.fixedPrefixTags.isNotEmpty ||
      metadata.fixedSuffixTags.isNotEmpty ||
      metadata.fixedNegativePrefixTags.isNotEmpty ||
      metadata.fixedNegativeSuffixTags.isNotEmpty ||
      metadata.qualityTags.isNotEmpty ||
      metadata.transparentBackground == true ||
      metadata.characterInfos.isNotEmpty ||
      metadata.vibeReferences.isNotEmpty ||
      metadata.preciseReferenceImages.isNotEmpty;

  List<PreciseReference> get preciseReferences {
    final results = <PreciseReference>[];
    for (var i = 0; i < metadata.preciseReferenceImages.length; i++) {
      try {
        final image = Uint8List.fromList(
          base64Decode(metadata.preciseReferenceImages[i]),
        );
        final type = i < metadata.preciseReferenceTypes.length
            ? _parsePreciseRefType(metadata.preciseReferenceTypes[i])
            : PreciseRefType.character;
        results.add(
          PreciseReference(
            image: image,
            type: type,
            strength: i < metadata.preciseReferenceStrengths.length
                ? metadata.preciseReferenceStrengths[i]
                : 1.0,
            fidelity: i < metadata.preciseReferenceFidelities.length
                ? metadata.preciseReferenceFidelities[i]
                : 1.0,
          ),
        );
      } catch (error) {
        PortableLogger.w(
          'Failed to decode precise reference image at index $i: $error',
          'NaiImageMetadata',
        );
      }
    }
    return results;
  }

  String get mainPrompt {
    if (!hasSeparatedFields) return metadata.prompt;

    final mainTags = _splitPromptSegments(metadata.prompt);
    _removeLeadingSegments(
      mainTags,
      _splitPromptEntries(metadata.fixedPrefixTags),
    );
    _removeTrailingSegments(
      mainTags,
      _splitPromptEntries(metadata.qualityTags),
    );
    if (hasRecordedTransparentBackgroundTag) {
      _removeTrailingSegments(mainTags, const [
        QualityTags.transparentBackgroundTag,
      ]);
    }
    _removeTrailingSegments(
      mainTags,
      _splitPromptEntries(metadata.fixedSuffixTags),
    );
    return mainTags.join(', ');
  }

  String get promptWithoutFixedTags => buildPositivePromptSelection(
    includeMainPrompt: true,
    includeCharacterPrompts: false,
    includeQualityTags: true,
    includeFixedTags: false,
  );

  String get negativePromptWithoutFixedTags {
    var result = metadata.negativePrompt.trim();
    for (final tag in metadata.fixedNegativePrefixTags) {
      result = _stripLeadingPromptSegment(result, tag);
    }
    for (final tag in metadata.fixedNegativeSuffixTags.reversed) {
      result = _stripTrailingPromptSegment(result, tag);
    }
    return result;
  }

  String get fullPrompt => _appendCharacterPrompts(metadata.prompt);

  String get fullPromptWithoutFixedTags => buildPositivePromptSelection(
    includeMainPrompt: true,
    includeCharacterPrompts: true,
    includeQualityTags: true,
    includeFixedTags: false,
  );

  String buildPositivePromptSelection({
    required bool includeMainPrompt,
    required bool includeCharacterPrompts,
    required bool includeQualityTags,
    required bool includeFixedTags,
  }) {
    final tags = <String>[];
    if (includeFixedTags) tags.addAll(metadata.fixedPrefixTags);

    final body = hasSeparatedFields ? mainPrompt : metadata.prompt.trim();
    if (includeMainPrompt && body.isNotEmpty) tags.add(body);

    if (includeFixedTags) tags.addAll(metadata.fixedSuffixTags);
    if (includeQualityTags) {
      if (hasRecordedTransparentBackgroundTag &&
          !metadata.qualityTags.any(
            (tag) =>
                tag.trim().toLowerCase() ==
                QualityTags.transparentBackgroundTag.toLowerCase(),
          )) {
        tags.add(QualityTags.transparentBackgroundTag);
      }
      tags.addAll(metadata.qualityTags);
    }

    var result = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .join(', ');
    if (includeCharacterPrompts) {
      result = _appendCharacterPrompts(result);
    }
    return result;
  }

  String _appendCharacterPrompts(String basePrompt) {
    if (!hasCharacters) return basePrompt;

    final buffer = StringBuffer(basePrompt);
    for (final characterPrompt in metadata.characterPrompts) {
      if (characterPrompt.isEmpty) continue;
      if (buffer.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln();
      }
      buffer
        ..write('| ')
        ..write(characterPrompt);
    }
    return buffer.toString();
  }

  String get displayNegativePrompt => metadata.negativePrompt;

  String get sizeString {
    if (metadata.width != null && metadata.height != null) {
      return '${metadata.width} x ${metadata.height}';
    }
    return '';
  }

  String get displaySampler {
    final sampler = metadata.sampler;
    if (sampler == null) return '';
    return sampler
        .replaceAll('k_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  static PreciseRefType _parsePreciseRefType(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'style' => PreciseRefType.style,
      'character&style' ||
      'character_and_style' ||
      'character and style' => PreciseRefType.characterAndStyle,
      _ => PreciseRefType.character,
    };
  }

  static List<String> _splitPromptSegments(String text) => text
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList();

  static List<String> _splitPromptEntries(List<String> entries) =>
      entries.expand(_splitPromptSegments).toList();

  static void _removeLeadingSegments(
    List<String> source,
    List<String> expected,
  ) {
    if (expected.isEmpty || source.length < expected.length) return;
    for (var i = 0; i < expected.length; i++) {
      if (source[i].toLowerCase() != expected[i].toLowerCase()) return;
    }
    source.removeRange(0, expected.length);
  }

  static void _removeTrailingSegments(
    List<String> source,
    List<String> expected,
  ) {
    if (expected.isEmpty || source.length < expected.length) return;
    final offset = source.length - expected.length;
    for (var i = 0; i < expected.length; i++) {
      if (source[offset + i].toLowerCase() != expected[i].toLowerCase()) return;
    }
    source.removeRange(offset, source.length);
  }

  static bool _hasTrailingPromptSegment(String text, String segment) {
    final trimmedText = text.trim();
    final trimmedSegment = segment.trim();
    if (trimmedText == trimmedSegment) return true;
    if (!trimmedText.endsWith(trimmedSegment)) return false;
    final prefix = trimmedText.substring(
      0,
      trimmedText.length - trimmedSegment.length,
    );
    return prefix.trimRight().endsWith(',');
  }

  static String _stripLeadingPromptSegment(String text, String segment) {
    final trimmedText = text.trim();
    final trimmedSegment = segment.trim();
    if (trimmedText.isEmpty || trimmedSegment.isEmpty) return trimmedText;
    if (trimmedText == trimmedSegment) return '';
    if (!trimmedText.startsWith(trimmedSegment)) return trimmedText;

    final rest = trimmedText.substring(trimmedSegment.length).trimLeft();
    if (!rest.startsWith(',')) return trimmedText;
    return rest.substring(1).trimLeft();
  }

  static String _stripTrailingPromptSegment(String text, String segment) {
    final trimmedText = text.trim();
    final trimmedSegment = segment.trim();
    if (trimmedText.isEmpty || trimmedSegment.isEmpty) return trimmedText;
    if (trimmedText == trimmedSegment) return '';
    if (!_hasTrailingPromptSegment(trimmedText, trimmedSegment)) {
      return trimmedText;
    }

    final rest = trimmedText.substring(
      0,
      trimmedText.length - trimmedSegment.length,
    );
    final trimmedRest = rest.trimRight();
    return trimmedRest.substring(0, trimmedRest.length - 1).trimRight();
  }
}
