import 'dart:convert';
import 'dart:typed_data';

import '../../../core/constants/api_constants.dart';
import '../../../core/enums/precise_ref_type.dart';
import '../../../core/utils/nai_prompt_parser.dart';
import '../../../core/utils/portable_logger.dart';
import '../image/image_params.dart';
import 'nai_image_metadata.dart';

/// 判定 [source] 从 [start] 起是否逐段等于 [expected]（trim 后大小写不敏感）。
///
/// 固定词的剥离与回填必须共用这一条规则，否则会出现"判定说能剥、实际没剥"。
bool promptSegmentsMatchAt(
  List<String> source,
  List<String> expected,
  int start,
) {
  if (expected.isEmpty || start < 0 || start + expected.length > source.length) {
    return false;
  }
  for (var offset = 0; offset < expected.length; offset++) {
    if (NaiPromptParser.normalizeSegment(source[start + offset]) !=
        NaiPromptParser.normalizeSegment(expected[offset])) {
      return false;
    }
  }
  return true;
}

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
      NaiPromptParser.splitSegments(metadata.prompt).any(
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
    final originalCount = mainTags.length;
    final prefixEntries = _splitPromptEntries(metadata.fixedPrefixTags);
    final qualityEntries = _splitPromptEntries(metadata.qualityTags);
    final suffixEntries = _splitPromptEntries(metadata.fixedSuffixTags);

    _removeLeadingSegments(mainTags, prefixEntries);
    _removeTrailingSegments(mainTags, qualityEntries);
    if (hasRecordedTransparentBackgroundTag) {
      _removeTrailingSegments(mainTags, const [
        QualityTags.transparentBackgroundTag,
      ]);
    }
    _removeTrailingSegments(mainTags, suffixEntries);

    // 若标签段落数量没有改变（例如 resolvedMetadata.prompt 已经预先清洗过），
    // 必须直接原样返回 metadata.prompt，绝对不能用 mainTags.join(', ') 把用户的换行排版拍扁！
    if (mainTags.length == originalCount) {
      return metadata.prompt;
    }

    // 若原文本不含换行符，按常规逗号拼接返回
    if (!metadata.prompt.contains('\n') && !metadata.prompt.contains('\r')) {
      return mainTags.join(', ');
    }

    // 若原文本包含换行符，采用逐行保留排版的剥离逻辑
    return _stripLeadingAndTrailingTagsPreservingLines(
      metadata.prompt,
      leading: prefixEntries,
      trailing: [
        ...qualityEntries,
        if (hasRecordedTransparentBackgroundTag)
          QualityTags.transparentBackgroundTag,
        ...suffixEntries,
      ],
    );
  }

  static String _stripLeadingAndTrailingTagsPreservingLines(
    String prompt, {
    required List<String> leading,
    required List<String> trailing,
  }) {
    if (leading.isEmpty && trailing.isEmpty) return prompt;

    final normLeading = leading
        .map(NaiPromptParser.normalizeSegment)
        .where((s) => s.isNotEmpty)
        .toSet();
    final normTrailing = trailing
        .map(NaiPromptParser.normalizeSegment)
        .where((s) => s.isNotEmpty)
        .toSet();

    final lineBreakPattern = RegExp(r'\r\n|\r|\n');
    final leadingWhitespacePattern = RegExp(r'^[ \t]*');
    final trailingWhitespacePattern = RegExp(r'[ \t]*$');

    final cleanedPrompt = prompt.splitMapJoin(
      lineBreakPattern,
      onMatch: (match) => match.group(0)!,
      onNonMatch: (line) {
        if (line.isEmpty) return line;

        final leadingWs =
            leadingWhitespacePattern.firstMatch(line)?.group(0) ?? '';
        final trailingWs =
            trailingWhitespacePattern.firstMatch(line)?.group(0) ?? '';
        final contentEnd = line.length - trailingWs.length;
        if (leadingWs.length >= contentEnd) return line;

        final content = line.substring(leadingWs.length, contentEnd);
        final keepsTrailingComma = content.trim().endsWith(',');

        final lineTags = NaiPromptParser.splitSegments(content);
        if (lineTags.isEmpty) return line;

        final remainingLineTags = <String>[];
        for (final rawTag in lineTags) {
          final norm = NaiPromptParser.normalizeSegment(rawTag);
          if (norm.isNotEmpty &&
              !normLeading.contains(norm) &&
              !normTrailing.contains(norm)) {
            remainingLineTags.add(rawTag);
          }
        }

        if (remainingLineTags.isEmpty) return '';

        var formatted = remainingLineTags.join(', ');
        if (keepsTrailingComma && formatted.isNotEmpty) {
          formatted = '$formatted,';
        }
        return '$leadingWs$formatted$trailingWs';
      },
    );

    if (cleanedPrompt.replaceAll(RegExp(r'[\r\n\s,]+'), '').isEmpty) {
      return '';
    }
    return cleanedPrompt;
  }

  String get promptWithoutFixedTags => buildPositivePromptSelection(
    includeMainPrompt: true,
    includeCharacterPrompts: false,
    includeQualityTags: true,
    includeFixedTags: false,
  );

  /// 发送时 UC 预设拼在最外层：`[预设][固定前缀][主负面][固定后缀]`，
  /// 识别负向固定词前必须先拆掉预设。
  UcPresetSplit get negativePresetSplit {
    final ucPreset = metadata.ucPreset;
    if (ucPreset == null) {
      return (preset: '', body: metadata.negativePrompt.trim());
    }
    return UcPresets.splitPresetByInt(
      metadata.negativePrompt,
      metadata.importableModel,
      ucPreset,
    );
  }

  /// 不含 UC 预设与负向固定词的负面，与正面的 [mainPrompt] 对应。
  String get mainNegativePrompt {
    final body = negativePresetSplit.body;
    final prefix = _splitPromptEntries(metadata.fixedNegativePrefixTags);
    final suffix = _splitPromptEntries(metadata.fixedNegativeSuffixTags);
    if (prefix.isEmpty && suffix.isEmpty) return body;

    final tags = _splitPromptSegments(body);
    _removeLeadingSegments(tags, prefix);
    _removeTrailingSegments(tags, suffix);
    return tags.join(', ');
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

  static List<String> _splitPromptSegments(String text) =>
      NaiPromptParser.splitSegments(text);

  static List<String> _splitPromptEntries(List<String> entries) =>
      entries.expand(_splitPromptSegments).toList();

  static void _removeLeadingSegments(
    List<String> source,
    List<String> expected,
  ) {
    if (!promptSegmentsMatchAt(source, expected, 0)) return;
    source.removeRange(0, expected.length);
  }

  static void _removeTrailingSegments(
    List<String> source,
    List<String> expected,
  ) {
    final offset = source.length - expected.length;
    if (!promptSegmentsMatchAt(source, expected, offset)) return;
    source.removeRange(offset, source.length);
  }
}
