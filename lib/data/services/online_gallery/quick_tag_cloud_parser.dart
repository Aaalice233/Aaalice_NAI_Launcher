import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/online_gallery/quick_tag_cloud_catalog.dart';
import '../../models/online_gallery/quick_tag_cloud_codex.dart';

export '../../models/online_gallery/quick_tag_cloud_catalog.dart';
export '../../models/online_gallery/quick_tag_cloud_codex.dart';

class QuickTagCloudParser {
  const QuickTagCloudParser._();

  static final RegExp releasePattern = RegExp(r'^r-[0-9a-f]{20}$');
  static final RegExp sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

  static QuickTagCloudDataSourceConfig parseDataSource(Object? value) {
    final json = _object(value, 'data source');
    final schemaVersion = _integer(json['schemaVersion']);
    if (schemaVersion != 1) {
      throw const FormatException('Unsupported QuickTagCloud schemaVersion');
    }
    final base = _string(json['baseUrl']).replaceFirst(RegExp(r'/+$'), '');
    final baseUrl = Uri.tryParse(base);
    if (baseUrl == null ||
        baseUrl.scheme != 'https' ||
        baseUrl.host.isEmpty ||
        baseUrl.hasFragment) {
      throw const FormatException(
        'QuickTagCloud data baseUrl must be an HTTPS URL',
      );
    }
    final pointer = cleanRelativePath(
      _string(json['pointer']).isEmpty
          ? 'current.json'
          : _string(json['pointer']),
    );
    return QuickTagCloudDataSourceConfig(
      schemaVersion: schemaVersion,
      baseUrl: baseUrl,
      pointer: pointer,
    );
  }

  static QuickTagCloudReleasePointer parseReleasePointer(Object? value) {
    final json = _object(value, 'release pointer');
    final schemaVersion = _integer(json['schemaVersion']);
    if (schemaVersion != 1) {
      throw const FormatException('Unsupported QuickTagCloud schemaVersion');
    }
    final release = _string(json['release']);
    final contentHash = _string(json['contentHash']);
    _validateReleaseIdentity(release, contentHash);
    final previousRelease = _string(json['previousRelease']);
    if (previousRelease.isNotEmpty &&
        !releasePattern.hasMatch(previousRelease)) {
      throw const FormatException('Invalid previous QuickTagCloud release id');
    }
    final manifestValue = _string(json['manifest']);
    final expectedManifest = 'releases/$release/manifest.json';
    final manifest = cleanRelativePath(
      manifestValue.isEmpty ? expectedManifest : manifestValue,
    );
    if (manifest != expectedManifest) {
      throw const FormatException(
        'QuickTagCloud manifest path does not match its release',
      );
    }
    return QuickTagCloudReleasePointer(
      schemaVersion: schemaVersion,
      release: release,
      manifest: manifest,
      contentHash: contentHash,
      publishedAt: _string(json['publishedAt']),
      previousRelease: previousRelease,
    );
  }

  static QuickTagCloudReleaseManifest parseManifest(
    Object? value, {
    String? expectedRelease,
    String? expectedContentHash,
  }) {
    final json = _object(value, 'release manifest');
    final schemaVersion = _integer(json['schemaVersion']);
    if (schemaVersion != 1) {
      throw const FormatException('Unsupported QuickTagCloud schemaVersion');
    }
    final release = _string(json['release']);
    final contentHash = _string(json['contentHash']);
    _validateReleaseIdentity(release, contentHash);
    if (expectedRelease != null && release != expectedRelease ||
        expectedContentHash != null && contentHash != expectedContentHash) {
      throw const FormatException('QuickTagCloud manifest identity mismatch');
    }
    final rawFiles = _object(json['files'], 'manifest files');
    final files = <String, QuickTagCloudManifestFile>{};
    for (final item in rawFiles.entries) {
      final path = cleanRelativePath(item.key);
      if (path != item.key || files.containsKey(path)) {
        throw FormatException(
          'Invalid QuickTagCloud manifest path: ${item.key}',
        );
      }
      final metadata = _object(item.value, 'manifest file $path');
      final size = _integer(metadata['size']);
      final hash = _string(metadata['sha256']);
      if (size < 0 || !sha256Pattern.hasMatch(hash)) {
        throw FormatException('Invalid QuickTagCloud manifest file: $path');
      }
      files[path] = QuickTagCloudManifestFile(
        path: path,
        size: size,
        sha256: hash,
      );
    }
    final calculatedContentHash = manifestContentHash(files.values);
    if (calculatedContentHash != contentHash) {
      throw const FormatException(
        'QuickTagCloud manifest contentHash does not match its files',
      );
    }
    return QuickTagCloudReleaseManifest(
      schemaVersion: schemaVersion,
      release: release,
      contentHash: contentHash,
      files: files,
    );
  }

  static String manifestContentHash(Iterable<QuickTagCloudManifestFile> files) {
    final sorted = files.toList(growable: false)
      ..sort((left, right) => left.path.compareTo(right.path));
    final input = StringBuffer();
    for (final file in sorted) {
      input
        ..write(file.path)
        ..writeCharCode(0)
        ..write(file.sha256)
        ..write('\n');
    }
    return sha256.convert(utf8.encode(input.toString())).toString();
  }

  static void _validateReleaseIdentity(String release, String contentHash) {
    if (!releasePattern.hasMatch(release) ||
        !sha256Pattern.hasMatch(contentHash) ||
        release != 'r-${contentHash.substring(0, 20)}') {
      throw const FormatException('Invalid QuickTagCloud release identity');
    }
  }

  static List<QuickTagCloudCodexMeta> parseCodexes(Object? value) {
    if (value is! List) {
      throw const FormatException('QuickTagCloud codexes must be an array');
    }
    final seen = <String>{};
    return List.unmodifiable(
      value.map((item) {
        final json = _object(item, 'codex metadata');
        final id = _string(json['id']);
        if (id.isEmpty || !seen.add(id)) {
          throw FormatException(
            'Invalid or duplicate QuickTagCloud codex: $id',
          );
        }
        final contributors = _list(json['contributors'])
            .map((item) {
              if (item is String) {
                return QuickTagCloudContributor(name: item, role: '');
              }
              final contributor = _object(item, 'codex contributor');
              return QuickTagCloudContributor(
                name: _string(contributor['name']),
                role: _string(contributor['role']),
              );
            })
            .toList(growable: false);
        final links = _list(json['links'])
            .map((item) {
              if (item is String) {
                return QuickTagCloudLink(label: '', url: _httpsUrl(item));
              }
              final link = _object(item, 'codex link');
              return QuickTagCloudLink(
                label: _string(link['label']),
                url: _httpsUrl(link['url']),
              );
            })
            .where((link) => link.url.isNotEmpty)
            .toList(growable: false);
        final filters = _list(json['updateFilters'])
            .map((item) {
              final filter = _object(item, 'codex update filter');
              return QuickTagCloudUpdateFilter(
                id: _string(filter['id']),
                label: _string(filter['label']),
                latest: filter['latest'] == true,
              );
            })
            .toList(growable: false);
        return QuickTagCloudCodexMeta(
          id: id,
          type: _string(json['type']),
          title: _string(json['title']),
          version: _string(json['version']),
          author: _string(json['author']),
          entryCount: _integer(json['entryCount']),
          imagedCount: _integer(json['imagedCount']),
          hasOriginal: json['hasOriginal'] == true,
          nsfw: json['nsfw'] == true,
          dataUrl: _string(json['dataUrl']),
          fallbackDataUrl: _string(json['fallbackDataUrl']),
          fallbackVersion: _string(json['fallbackVersion']),
          assetBaseUrl: _stripTrailingSlash(
            _firstString([json['assetBaseUrl'], json['baseUrl']]),
          ),
          assetPathMode: _string(json['assetPathMode']),
          source: _string(json['source']),
          cover: _string(json['cover']),
          coverRev: _string(json['coverRev']),
          coverCodexId: _string(json['coverCodexId']),
          newFilterLabel: _string(json['newFilterLabel']),
          aliases: _stringList(json['aliases']),
          contributors: contributors,
          links: links,
          updateFilters: filters,
          raw: Map<String, dynamic>.from(json),
        );
      }),
    );
  }

  static QuickTagCloudMediaConfig parseMedia(Object? value) {
    final json = _object(value, 'media config');
    return QuickTagCloudMediaConfig(
      baseUrl: _stripTrailingSlash(_string(json['baseUrl'])),
      bucket: _string(json['bucket']),
      imagePrefix: _string(json['imagePrefix']).isEmpty
          ? 'images'
          : _string(json['imagePrefix']),
      originalPrefix: _string(json['originalPrefix']).isEmpty
          ? 'originals'
          : _string(json['originalPrefix']),
      localFallback: json['localFallback'] != false,
    );
  }

  static QuickTagCloudCodex parseCodex(
    Object? value,
    QuickTagCloudCodexMeta meta, {
    QuickTagCloudCodexLoadSource loadSource =
        QuickTagCloudCodexLoadSource.canonical,
    QuickTagCloudMediaConfig? mediaOverride,
    String sourceRelease = '',
    Object? externalError,
  }) {
    final data = _object(value, 'codex');
    final id = _firstString([meta.id, data['id']]);
    if (id.isEmpty) {
      throw const FormatException('QuickTagCloud codex has no id');
    }

    final isFallback = loadSource == QuickTagCloudCodexLoadSource.fallback;
    final isLiveExternal =
        meta.isExternal && loadSource == QuickTagCloudCodexLoadSource.external;
    final effectiveDataUrl = isFallback
        ? ''
        : _firstString([meta.dataUrl, data['dataUrl']]);
    final assetBaseUrl = isFallback
        ? ''
        : _stripTrailingSlash(
            _firstString(
              isLiveExternal
                  ? [
                      data['assetBaseUrl'],
                      meta.assetBaseUrl,
                      meta.raw['baseUrl'],
                    ]
                  : [
                      meta.assetBaseUrl,
                      meta.raw['baseUrl'],
                      data['assetBaseUrl'],
                    ],
            ),
          );
    final pathMode = isFallback
        ? 'codex'
        : _firstString([
            if (isLiveExternal) data['assetPathMode'],
            meta.assetPathMode,
            if (!isLiveExternal) data['assetPathMode'],
            effectiveDataUrl.isNotEmpty ? 'relative' : 'codex',
          ]);
    final entries = <QuickTagCloudEntry>[];
    final seenEntryIds = <String>{};
    for (final item in _list(data['entries']).asMap().entries) {
      final entry = normalizeEntry(item.value, id, item.key);
      if (!seenEntryIds.add(entry.id)) {
        throw FormatException(
          'QuickTagCloud codex "$id" contains duplicate entry id "${entry.id}"',
        );
      }
      entries.add(entry);
    }
    final tree = data['tree'] is List
        ? List<dynamic>.from(data['tree'] as List)
        : buildTreeFromEntries(entries);
    // External codexes evolve independently of the release snapshot. Their
    // live document is authoritative for counts when it provides them.
    final declaredEntryCount = _integer(
      _firstNonNull([data['entryCount'], meta.raw['entryCount']]),
    );
    final declaredImagedCount = _integer(
      _firstNonNull([data['imagedCount'], meta.raw['imagedCount']]),
    );

    return QuickTagCloudCodex(
      id: id,
      type: isLiveExternal
          ? _firstString([data['type'], meta.type, 'codex'])
          : _firstString([meta.type, data['type'], 'codex']),
      title: isLiveExternal
          ? _firstString([data['title'], meta.title, data['id'], meta.id])
          : _firstString([meta.title, data['title'], data['id'], meta.id]),
      version: isFallback
          ? _firstString([meta.fallbackVersion, meta.version, data['version']])
          : isLiveExternal
          ? _firstString([data['version'], meta.version])
          : _firstString([meta.version, data['version']]),
      author: isLiveExternal
          ? _firstString([data['author'], meta.author])
          : _firstString([meta.author, data['author']]),
      nsfw: meta.nsfw || data['nsfw'] == true,
      assetBaseUrl: assetBaseUrl,
      assetPathMode: pathMode,
      dataUrl: effectiveDataUrl,
      sourceDataUrl: _firstString([
        meta.dataUrl,
        data['sourceDataUrl'],
        data['dataUrl'],
      ]),
      fallbackDataUrl: _firstString([
        meta.fallbackDataUrl,
        data['fallbackDataUrl'],
      ]),
      source: _firstString([meta.source, data['source']]),
      aliases: meta.aliases.isNotEmpty
          ? meta.aliases
          : _stringList(data['aliases']),
      // The signed release metadata is the capability boundary. Entry JSON
      // may describe an original path but cannot enable originals for a codex
      // whose published metadata disables them.
      hasOriginal: meta.hasOriginal,
      entries: entries,
      entryCount: declaredEntryCount == 0 ? entries.length : declaredEntryCount,
      imagedCount: declaredImagedCount == 0
          ? entries.where((entry) => entry.hasImage).length
          : declaredImagedCount,
      tree: tree,
      loadSource: loadSource,
      metadata: meta,
      mediaOverride: mediaOverride,
      sourceRelease: sourceRelease,
      externalError: externalError,
      raw: Map<String, dynamic>.from(data),
    );
  }

  static QuickTagCloudEntry normalizeEntry(
    Object? value,
    String codexId,
    int index,
  ) {
    final entry = _object(value, 'codex entry');
    final images = normalizeImages(entry);
    final primary = images.isEmpty ? null : images.first;
    final image = _firstString([entry['image'], primary?.path]);
    final original = _firstString([
      entry['original'],
      primary?.original,
      primary?.path,
    ]);
    final rawTag = _firstString([entry['rawTag'], entry['rawTags']]);
    final rating = _firstString([
      entry['rating'],
      entry['level'],
    ]).toLowerCase();
    final explicitId = _string(entry['id']);
    final generatedId = explicitId.isEmpty
        ? _generatedEntryId(entry, codexId, images, index)
        : explicitId;
    return QuickTagCloudEntry(
      id: generatedId,
      title: _string(entry['title']),
      path: _stringList(entry['path']),
      tags: _firstString([entry['tags'], entry['rawTags']]),
      negative: _string(entry['negative']),
      note: _string(entry['note']),
      author: _string(entry['author']),
      credit: _string(entry['credit']),
      rating: rating,
      isNew: entry['isNew'] == true,
      updateBatches: _uniqueStrings(entry['updateBatches']),
      characterPrompts: normalizeCharacterPrompts(entry['characterPrompts']),
      images: images,
      image: image,
      original: original,
      assetRev: _string(entry['assetRev']),
      dimensions: _dimensions(entry),
      rawTag: rawTag,
      assetCodexId: _string(entry['assetCodexId']),
      raw: Map<String, dynamic>.from(entry),
    );
  }

  static List<QuickTagCloudCharacterPrompt> normalizeCharacterPrompts(
    Object? value,
  ) {
    if (value is! List) return const [];
    final output = <QuickTagCloudCharacterPrompt>[];
    for (var index = 0; index < value.length; index++) {
      final raw = value[index];
      final item = raw is String
          ? <String, dynamic>{'prompt': raw}
          : raw is Map
          ? Map<String, dynamic>.from(raw)
          : null;
      if (item == null) continue;
      final prompt = _firstString([
        item['prompt'],
        item['positive'],
        item['char_caption'],
      ]).trim();
      final negative = _firstString([item['negative'], item['uc']]).trim();
      if (prompt.isEmpty && negative.isEmpty) continue;
      final defaultLabel = 'char${index + 1}';
      final label = _string(item['label']).trim();
      output.add(
        QuickTagCloudCharacterPrompt(
          label: label.isEmpty ? defaultLabel : label,
          prompt: prompt,
          negative: negative,
        ),
      );
    }
    return List.unmodifiable(output);
  }

  static List<QuickTagCloudImage> normalizeImages(Map<String, dynamic> entry) {
    final output = <QuickTagCloudImage>[];
    final seen = <String>{};

    void add(Object? value, {bool toFront = false}) {
      if (value == null || value == false) return;
      final item = value is String
          ? <String, dynamic>{'path': value}
          : value is Map
          ? Map<String, dynamic>.from(value)
          : null;
      if (item == null) return;
      final path = _firstString([
        item['path'],
        item['image'],
        item['url'],
        item['src'],
      ]);
      if (path.isEmpty || !seen.add(path)) return;
      final hasOriginal = item.containsKey('_hasOriginal')
          ? item['_hasOriginal'] == true
          : _string(item['original']).isNotEmpty;
      final image = QuickTagCloudImage(
        path: path,
        original: _firstString([item['original'], path]),
        hasOriginal: hasOriginal,
        rawTag: _firstString([item['rawTag'], item['rawTags']]),
        dimensions: _dimensions(item),
        raw: item,
      );
      if (toFront) {
        output.insert(0, image);
      } else {
        output.add(image);
      }
    }

    for (final image in _list(entry['images'])) {
      add(image);
    }
    final primaryPath = _string(entry['image']);
    if (primaryPath.isNotEmpty && !seen.contains(primaryPath)) {
      add(<String, dynamic>{
        'path': primaryPath,
        'original': _firstString([entry['original'], primaryPath]),
        '_hasOriginal': _string(entry['original']).isNotEmpty,
      }, toFront: true);
    }
    if (primaryPath.isNotEmpty && output.isNotEmpty) {
      final primaryIndex = output.indexWhere(
        (image) => image.path == primaryPath,
      );
      if (primaryIndex > 0) {
        output.insert(0, output.removeAt(primaryIndex));
      }
      final entryOriginal = _string(entry['original']);
      if (entryOriginal.isNotEmpty && output.first.path == primaryPath) {
        final current = output.first;
        output[0] = QuickTagCloudImage(
          path: current.path,
          original: entryOriginal,
          hasOriginal: true,
          rawTag: current.rawTag,
          dimensions: current.dimensions,
          raw: current.raw,
        );
      }
    }
    if (output.isEmpty && _string(entry['original']).isNotEmpty) {
      add(<String, dynamic>{
        'path': _string(entry['original']),
        'original': _string(entry['original']),
        '_hasOriginal': true,
      });
    }
    return List.unmodifiable(output);
  }

  static List<dynamic> buildTreeFromEntries(List<QuickTagCloudEntry> entries) {
    final roots = <String, _MutableTreeNode>{};
    for (final entry in entries) {
      var level = roots;
      for (final name in entry.path) {
        final node = level.putIfAbsent(name, () => _MutableTreeNode(name));
        node.count++;
        level = node.children;
      }
    }
    List<Map<String, dynamic>> serialize(Map<String, _MutableTreeNode> level) {
      return level.values
          .map(
            (node) => <String, dynamic>{
              'name': node.name,
              'count': node.count,
              'children': serialize(node.children),
            },
          )
          .toList(growable: false);
    }

    return List<dynamic>.unmodifiable(serialize(roots));
  }

  static String cleanRelativePath(String value) {
    if (value.isEmpty ||
        value.startsWith('/') ||
        value.startsWith(r'\') ||
        value.contains(r'\') ||
        value.contains(':') ||
        value.contains('?') ||
        value.contains('#') ||
        value.contains('%') ||
        value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
      throw FormatException('Invalid QuickTagCloud data path: $value');
    }
    final parts = value.split('/');
    if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw FormatException('Invalid QuickTagCloud data path: $value');
    }
    return value;
  }

  static Map<String, dynamic> _object(Object? value, String label) {
    if (value is! Map) {
      throw FormatException('QuickTagCloud $label must be an object');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> _list(Object? value) =>
      value is List ? List<dynamic>.from(value) : const [];

  static int _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _generatedEntryId(
    Map<String, dynamic> entry,
    String codexId,
    List<QuickTagCloudImage> images,
    int _,
  ) {
    final characters = normalizeCharacterPrompts(entry['characterPrompts']);
    final identity = jsonEncode({
      'codex': codexId,
      'title': _string(entry['title']),
      'path': _stringList(entry['path']),
      'tags': _firstString([entry['tags'], entry['rawTags']]),
      'negative': _string(entry['negative']),
      'note': _string(entry['note']),
      'characters': [
        for (final character in characters)
          [character.label, character.prompt, character.negative],
      ],
      'images': [
        for (final image in images) [image.path, image.original, image.rawTag],
      ],
    });
    final digest = sha256.convert(utf8.encode(identity)).toString();
    return 'generated-${digest.substring(0, 20)}';
  }

  static String _string(Object? value) => value?.toString() ?? '';

  static String _firstString(List<Object?> values) {
    for (final value in values) {
      final text = _string(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static Object? _firstNonNull(List<Object?> values) {
    for (final value in values) {
      if (value != null) return value;
    }
    return null;
  }

  static List<String> _stringList(Object? value) => value is List
      ? value.map(_string).toList(growable: false)
      : const <String>[];

  static List<String> _uniqueStrings(Object? value) {
    if (value is! List) return const [];
    final seen = <String>{};
    return value
        .map(_string)
        .where((item) => item.isNotEmpty && seen.add(item))
        .toList(growable: false);
  }

  static QuickTagCloudDimensions _dimensions(Map<String, dynamic> value) {
    return QuickTagCloudDimensions(
      width: _integer(
        _firstNonNull([
          value['imageWidth'],
          value['width'],
          value['thumbnailWidth'],
        ]),
      ),
      height: _integer(
        _firstNonNull([
          value['imageHeight'],
          value['height'],
          value['thumbnailHeight'],
        ]),
      ),
    );
  }

  static String _httpsUrl(Object? value) {
    final raw = _string(value);
    final uri = Uri.tryParse(raw);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri.toString()
        : '';
  }

  static String _stripTrailingSlash(String value) =>
      value.replaceFirst(RegExp(r'/+$'), '');
}

class _MutableTreeNode {
  _MutableTreeNode(this.name);

  final String name;
  int count = 0;
  final Map<String, _MutableTreeNode> children = {};
}
