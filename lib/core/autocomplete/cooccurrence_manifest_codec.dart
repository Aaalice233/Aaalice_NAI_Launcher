import 'dart:convert';

class CooccurrenceDataPackManifest {
  const CooccurrenceDataPackManifest({
    required this.dataVersion,
    required this.schemaVersion,
    required this.releaseTag,
    required this.archiveName,
    required this.downloadUri,
    required this.archiveSize,
    required this.archiveSha256,
    required this.databaseName,
    required this.databaseSize,
    required this.databaseSha256,
    required this.sourcePairCount,
    required this.selfRelationCount,
    required this.directedEdgeCount,
    required this.tagCount,
    required this.sourceRevision,
    required this.sourceUrl,
    required this.sourceSha256,
  });

  final String dataVersion;
  final int schemaVersion;
  final String releaseTag;
  final String archiveName;
  final Uri downloadUri;
  final int archiveSize;
  final String archiveSha256;
  final String databaseName;
  final int databaseSize;
  final String databaseSha256;
  final int sourcePairCount;
  final int selfRelationCount;
  final int directedEdgeCount;
  final int tagCount;
  final String sourceRevision;
  final String sourceUrl;
  final String sourceSha256;

  static CooccurrenceDataPackManifest parse(String source) =>
      CooccurrenceManifestCodec.parse(source);

  Map<String, dynamic> toJson() => CooccurrenceManifestCodec.encode(this);
}

class CooccurrenceManifestCodec {
  const CooccurrenceManifestCodec._();

  static CooccurrenceDataPackManifest parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['manifestVersion'] != 1) {
      throw const FormatException('Unsupported co-occurrence manifest');
    }
    final release = _map(decoded, 'release');
    final archive = _map(decoded, 'archive');
    final database = _map(decoded, 'database');
    final counts = _map(decoded, 'counts');
    final provenance = _map(decoded, 'provenance');
    final uri = Uri.parse(_string(release, 'url'));
    final releaseTag = _string(release, 'tag');
    final archiveName = _string(archive, 'name');
    final expectedPath =
        '/Aaalice233/Aaalice_NAI_Launcher/releases/download/'
        '$releaseTag/$archiveName';
    if (uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.path != expectedPath ||
        !releaseTag.startsWith('autocomplete-data-cooccurrence-') ||
        release['prerelease'] != true ||
        release['makeLatest'] != false) {
      throw const FormatException('Untrusted co-occurrence release URL');
    }
    final schemaVersion = (decoded['schemaVersion'] as num?)?.toInt();
    if (schemaVersion != 2 ||
        _string(database, 'name') != 'cooccurrence-v2.db') {
      throw const FormatException('Unsupported co-occurrence schema');
    }
    final manifest = CooccurrenceDataPackManifest(
      dataVersion: _string(decoded, 'dataVersion'),
      schemaVersion: schemaVersion!,
      releaseTag: releaseTag,
      archiveName: archiveName,
      downloadUri: uri,
      archiveSize: _positiveInt(archive, 'size'),
      archiveSha256: _sha256(archive, 'sha256'),
      databaseName: _string(database, 'name'),
      databaseSize: _positiveInt(database, 'size'),
      databaseSha256: _sha256(database, 'sha256'),
      sourcePairCount: _positiveInt(counts, 'sourcePairCount'),
      selfRelationCount: (counts['selfRelationCount'] as num?)?.toInt() ?? -1,
      directedEdgeCount: _positiveInt(counts, 'directedEdgeCount'),
      tagCount: _positiveInt(counts, 'tagCount'),
      sourceRevision: _string(provenance, 'sourceRevision'),
      sourceUrl: _string(provenance, 'sourceUrl'),
      sourceSha256: _sha256(provenance, 'sourceSha256'),
    );
    if (manifest.selfRelationCount < 0 ||
        manifest.directedEdgeCount !=
            manifest.sourcePairCount * 2 - manifest.selfRelationCount ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(manifest.sourceRevision)) {
      throw const FormatException('Invalid co-occurrence record counts');
    }
    final sourceUri = Uri.parse(manifest.sourceUrl);
    if (sourceUri.scheme != 'https' ||
        !sourceUri.path.contains(manifest.sourceRevision)) {
      throw const FormatException('Unpinned co-occurrence provenance URL');
    }
    return manifest;
  }

  static Map<String, dynamic> encode(CooccurrenceDataPackManifest manifest) => {
    'manifestVersion': 1,
    'schemaVersion': manifest.schemaVersion,
    'dataVersion': manifest.dataVersion,
    'release': {
      'tag': manifest.releaseTag,
      'url': manifest.downloadUri.toString(),
      'prerelease': true,
      'makeLatest': false,
    },
    'archive': {
      'name': manifest.archiveName,
      'size': manifest.archiveSize,
      'sha256': manifest.archiveSha256,
    },
    'database': {
      'name': manifest.databaseName,
      'size': manifest.databaseSize,
      'sha256': manifest.databaseSha256,
    },
    'counts': {
      'sourcePairCount': manifest.sourcePairCount,
      'selfRelationCount': manifest.selfRelationCount,
      'directedEdgeCount': manifest.directedEdgeCount,
      'tagCount': manifest.tagCount,
    },
    'provenance': {
      'sourceRevision': manifest.sourceRevision,
      'sourceUrl': manifest.sourceUrl,
      'sourceSha256': manifest.sourceSha256,
    },
  };

  static Map<String, dynamic> _map(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! Map<String, dynamic>) {
      throw FormatException('Missing manifest object: $key');
    }
    return value;
  }

  static String _string(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing manifest string: $key');
    }
    return value;
  }

  static int _positiveInt(Map<String, dynamic> map, String key) {
    final value = (map[key] as num?)?.toInt() ?? 0;
    if (value <= 0) throw FormatException('Invalid manifest integer: $key');
    return value;
  }

  static String _sha256(Map<String, dynamic> map, String key) {
    final value = _string(map, key).toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      throw FormatException('Invalid manifest SHA256: $key');
    }
    return value;
  }
}
