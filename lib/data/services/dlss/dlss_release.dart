import 'package:dio/dio.dart';

const dlssRepository = 'DaniilSokolyuk/video2dlssnr';
const dlssRepositoryUrl = 'https://github.com/$dlssRepository';

class DlssRelease {
  const DlssRelease({
    required this.id,
    required this.tag,
    required this.prerelease,
    required this.publishedAt,
    required this.assetId,
    required this.bytes,
    required this.url,
    required this.digest,
  });

  final int id;
  final String tag;
  final bool prerelease;
  final DateTime publishedAt;
  final int assetId;
  final int bytes;
  final String url;
  final String digest;
  String get directoryName => '$id-$assetId';
  String get pageUrl =>
      '$dlssRepositoryUrl/releases/tag/${Uri.encodeComponent(tag)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'tag': tag,
    'prerelease': prerelease,
    'publishedAt': publishedAt.toIso8601String(),
    'assetId': assetId,
    'bytes': bytes,
    'url': url,
    'digest': digest,
  };

  factory DlssRelease.fromJson(Map<String, dynamic> json) => DlssRelease(
    id: json['id'] as int,
    tag: json['tag'] as String,
    prerelease: json['prerelease'] as bool,
    publishedAt: DateTime.parse(json['publishedAt'] as String),
    assetId: json['assetId'] as int,
    bytes: json['bytes'] as int,
    url: json['url'] as String,
    digest: json['digest'] as String,
  );
}

/// Only the full upstream bundle contains the NR DLL; the light asset does not.
class DlssReleaseSource {
  DlssReleaseSource(this.dio);
  final Dio dio;

  Future<List<DlssRelease>> list({CancelToken? cancelToken}) async {
    final releases = <DlssRelease>[];
    for (var page = 1; ; page++) {
      final response = await dio.get<List<dynamic>>(
        'https://api.github.com/repos/$dlssRepository/releases',
        queryParameters: {'per_page': 100, 'page': page},
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'Aaalice-NAI-Launcher',
          },
        ),
        cancelToken: cancelToken,
      );
      final rows = response.data;
      if (rows == null) {
        throw const FormatException('Empty GitHub Release response');
      }
      for (final row in rows) {
        final release = parse(row as Map<String, dynamic>);
        if (release != null) releases.add(release);
      }
      if (rows.length < 100) break;
    }
    releases.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return releases;
  }

  static DlssRelease? parse(Map<String, dynamic> json) {
    if (json['draft'] == true) return null;
    final assets = json['assets'] as List<dynamic>;
    final matches = assets
        .where((a) => a['name'] == 'video2dlssnr_release.zip')
        .toList();
    if (matches.isEmpty) return null;
    if (matches.length != 1) {
      throw const FormatException('Ambiguous DLSS release asset');
    }
    final asset = matches.single as Map<String, dynamic>;
    final tag = json['tag_name'] as String;
    final url = asset['browser_download_url'] as String;
    final expected =
        '$dlssRepositoryUrl/releases/download/${Uri.encodeComponent(tag)}/video2dlssnr_release.zip';
    if (url != expected) {
      throw FormatException('Unexpected DLSS asset URL: $url');
    }
    final digest = asset['digest'] as String? ?? '';
    if (!RegExp(r'^sha256:[0-9a-fA-F]{64}$').hasMatch(digest)) {
      throw FormatException('Release $tag has no verifiable SHA-256 digest');
    }
    return DlssRelease(
      id: json['id'] as int,
      tag: tag,
      prerelease: json['prerelease'] as bool,
      publishedAt: DateTime.parse(json['published_at'] as String),
      assetId: asset['id'] as int,
      bytes: asset['size'] as int,
      url: url,
      digest: digest.substring(7).toLowerCase(),
    );
  }
}
