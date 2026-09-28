import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../../models/online_gallery/gallery_item.dart';
import '../../../models/online_gallery/gallery_source.dart';
import '../../../services/online_gallery/quick_tag_cloud_access.dart';
import '../../../services/online_gallery/quick_tag_cloud_media_resolver.dart';
import 'quick_tag_cloud_gallery_repository.dart';

class QuickTagCloudGalleryMapper {
  const QuickTagCloudGalleryMapper();

  GalleryItem toGalleryItem(QuickTagCloudGalleryRecord record) {
    final media = mediaFor(record);
    final cover = media.isEmpty
        ? const GalleryMedia(id: 'no-image')
        : media.first;
    final entry = record.entry;
    return GalleryItem(
      id: _stableNumericId(record.workId),
      workId: record.workId,
      sourceId: GallerySourceId.quickTagCloud,
      site: GallerySourceId.quickTagCloud.key,
      title: entry.title,
      author: _displayAttribution(record),
      description: entry.note,
      createdAt: record.codex.version,
      source: sourceUrl(record),
      rating: QuickTagCloudAccess.galleryRating(entry, codex: record.codex),
      imageWidth: cover.width,
      imageHeight: cover.height,
      tagString: entry.tags,
      tags: record.promptTags,
      tagsComplete: true,
      fileExt: cover.extension,
      fileUrl: cover.downloadUrl.isEmpty ? null : cover.downloadUrl,
      largeFileUrl: cover.displayUrl.isEmpty ? null : cover.displayUrl,
      previewFileUrl: cover.previewUrl.isEmpty ? null : cover.previewUrl,
      cover: cover,
      mediaCount: media.length,
      rawSourceMetadata: metadataFor(record),
    );
  }

  GalleryDetail toGalleryDetail(QuickTagCloudGalleryRecord record) {
    final media = [
      for (final item in mediaFor(record))
        item.copyWith(
          displayUrl: item.downloadUrl.isEmpty
              ? item.displayUrl
              : item.downloadUrl,
        ),
    ];
    return GalleryDetail(
      item: toGalleryItem(record),
      media: media,
      prompt: record.entry.tags,
      negativePrompt: record.entry.negative,
      description: record.entry.note,
      categoryPath: record.entry.path,
      note: record.entry.note,
      rawTags: record.entry.rawTag.isEmpty ? const [] : [record.entry.rawTag],
      characterPrompts: [
        for (final character in record.entry.characterPrompts)
          GalleryCharacterPrompt(
            label: character.label,
            prompt: character.prompt,
            negativePrompt: character.negative,
          ),
      ],
      contributors: [
        for (final contributor in record.meta.contributors)
          GalleryContributor(name: contributor.name, role: contributor.role),
      ],
      sourceUrl: sourceUrl(record),
      rawSourceMetadata: metadataFor(record),
    );
  }

  List<GalleryMedia> mediaFor(QuickTagCloudGalleryRecord record) {
    final resolver = QuickTagCloudMediaResolver(media: record.media);
    final images = record.entry.images;
    return [
      for (var index = 0; index < images.length; index++)
        _galleryMedia(resolver, record, images[index], index),
    ];
  }

  Map<String, dynamic> metadataFor(QuickTagCloudGalleryRecord record) => {
    'codexId': record.codex.id,
    'codexTitle': record.codex.title,
    'codexVersion': record.codex.version,
    'codexAuthor': record.codex.author,
    'codexNsfw': record.codex.nsfw,
    'loadSource': record.codex.loadSource.name,
    'sourceRelease': record.codex.sourceRelease,
    'entryId': record.entry.id,
    'entryAuthor': record.entry.author,
    'entryCredit': record.entry.credit,
    'detailRevision': _detailRevision(record),
    'prompt': record.entry.tags,
    'negativePrompt': record.entry.negative,
    'note': record.entry.note,
    'categoryPath': record.entry.path,
    'rawTag': record.entry.rawTag,
    'characterPrompts': [
      for (final character in record.entry.characterPrompts)
        {
          'label': character.label,
          'prompt': character.prompt,
          'negative': character.negative,
        },
    ],
    'contributors': [
      for (final contributor in record.meta.contributors)
        {'name': contributor.name, 'role': contributor.role},
    ],
    'sourceUrl': sourceUrl(record),
    'declaredSource': record.codex.source,
    'entry': record.entry.raw,
  };

  String sourceUrl(QuickTagCloudGalleryRecord record) {
    for (final value in [
      ...record.meta.links.map((link) => link.url),
      record.codex.source,
      record.codex.sourceDataUrl,
    ]) {
      final uri = Uri.tryParse(value);
      if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
        return uri.toString();
      }
    }
    return '';
  }

  GalleryMedia _galleryMedia(
    QuickTagCloudMediaResolver resolver,
    QuickTagCloudGalleryRecord record,
    QuickTagCloudImage image,
    int index,
  ) {
    final preview = resolver.imageItemUrl(
      QuickTagCloudMediaKind.image,
      record.entry,
      image,
      record.codex,
    );
    final hasOriginal = record.codex.hasOriginal && image.hasOriginal;
    final original = hasOriginal
        ? resolver.imageItemUrl(
            QuickTagCloudMediaKind.original,
            record.entry,
            image,
            record.codex,
          )
        : preview;
    final dimensions = image.dimensions.isKnown
        ? image.dimensions
        : record.entry.dimensions;
    final parsedExtension = p
        .extension(Uri.tryParse(original)?.path ?? '')
        .replaceFirst('.', '')
        .toLowerCase();
    final extension = RegExp(r'^[a-z0-9]{1,10}$').hasMatch(parsedExtension)
        ? parsedExtension
        : '';
    return GalleryMedia(
      id: '${record.workId}:$index',
      previewUrl: preview,
      displayUrl: preview,
      downloadUrl: original,
      width: dimensions.width,
      height: dimensions.height,
      extension: extension.isEmpty ? null : extension,
      mediaType: 'image',
      rawMetadata: image.rawTag.isEmpty ? record.entry.rawTag : image.rawTag,
      prompt: record.entry.tags,
      negativePrompt: record.entry.negative,
      metadata: <String, dynamic>{...image.raw, 'hasOriginal': hasOriginal},
    );
  }

  String _displayAttribution(QuickTagCloudGalleryRecord record) {
    final values = <String>[];
    for (final value in [
      record.entry.credit,
      record.entry.author,
      record.codex.author,
    ]) {
      final normalized = value.trim();
      if (normalized.isNotEmpty && !values.contains(normalized)) {
        values.add(normalized);
      }
    }
    return values.join(' · ');
  }

  String _detailRevision(QuickTagCloudGalleryRecord record) => _stableNumericId(
    jsonEncode({
      'release': record.codex.sourceRelease,
      'version': record.codex.version,
      'assetBaseUrl': record.codex.assetBaseUrl,
      'mediaBaseUrl': record.media.baseUrl,
      'entry': record.entry.raw,
    }),
  ).toRadixString(16);

  int _stableNumericId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
