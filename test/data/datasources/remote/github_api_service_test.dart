import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/github_api_service.dart';
import 'package:nai_launcher/data/models/version/release_asset_info.dart';

void main() {
  test('stable lookup uses the direct manifest without GitHub API', () async {
    final adapter = _StableReleaseDioAdapter();
    final dio = Dio(BaseOptions(baseUrl: GitHubApiService.defaultBaseUrl))
      ..httpClientAdapter = adapter;
    final service = GitHubApiService(dio: dio);

    final info = await service.fetchLatestRelease(
      owner: 'Aaalice233',
      repo: 'Aaalice_NAI_Launcher',
      currentVersion: '1.8.0+31',
      platform: 'windows-installer',
    );

    expect(info.version, '1.8.1+32');
    expect(info.releaseNotes, contains('Fixed update checks'));
    expect(info.primaryAsset?.type, ReleaseAssetType.windowsInstaller);
    expect(info.primaryAsset?.sha256, _StableReleaseDioAdapter.setupSha256);
    expect(info.supportsInAppInstall, isTrue);
    expect(adapter.manifestRequest?.responseType, ResponseType.plain);
    expect(adapter.apiRequests, 0);
  });

  test('stable lookup classifies a 403 response as rate limited', () async {
    final dio = Dio(BaseOptions(baseUrl: GitHubApiService.defaultBaseUrl))
      ..httpClientAdapter = _StatusDioAdapter(403);
    final service = GitHubApiService(dio: dio);

    await expectLater(
      service.fetchLatestRelease(
        owner: 'Aaalice233',
        repo: 'Aaalice_NAI_Launcher',
        currentVersion: '1.8.0',
      ),
      throwsA(
        isA<GitHubApiException>().having(
          (error) => error.type,
          'type',
          GitHubReleaseErrorType.rateLimited,
        ),
      ),
    );
  });

  test('stable lookup rejects invalid manifest metadata', () async {
    final adapter = _StableReleaseDioAdapter(
      manifestOverride: {
        'version': '1.8.1+32',
        'tag': 'v1.8.1',
        'assets': [
          {
            'platform': 'windows',
            'type': 'windows-installer',
            'fileName': 'wrong-name.exe',
            'downloadUrl': _StableReleaseDioAdapter.setupUrl,
            'sha256': _StableReleaseDioAdapter.setupSha256,
            'size': 123,
          },
        ],
      },
    );
    final dio = Dio(BaseOptions(baseUrl: GitHubApiService.defaultBaseUrl))
      ..httpClientAdapter = adapter;
    final service = GitHubApiService(dio: dio);

    await expectLater(
      service.fetchLatestRelease(
        owner: 'Aaalice233',
        repo: 'Aaalice_NAI_Launcher',
        currentVersion: '1.8.0',
      ),
      throwsA(
        isA<GitHubApiException>().having(
          (error) => error.type,
          'type',
          GitHubReleaseErrorType.invalidResponse,
        ),
      ),
    );
  });

  test('prerelease lookup follows the GitHub release list contract', () async {
    final adapter = _MixedReleaseDioAdapter();
    final dio = Dio(BaseOptions(baseUrl: GitHubApiService.defaultBaseUrl))
      ..httpClientAdapter = adapter;
    final service = GitHubApiService(dio: dio);

    final info = await service.fetchLatestRelease(
      owner: 'Aaalice233',
      repo: 'Aaalice_NAI_Launcher',
      currentVersion: '1.8.0',
      includePrerelease: true,
    );

    expect(info.version, '1.8.2-beta.1+33');
    expect(info.primaryAsset?.type, ReleaseAssetType.windowsPortable);
    expect(adapter.releaseListRequests, 1);
    expect(adapter.atomRequests, 0);
  });

  test('prerelease lookup continues past a full data release page', () async {
    final adapter = _PaginatedReleaseDioAdapter();
    final dio = Dio(BaseOptions(baseUrl: GitHubApiService.defaultBaseUrl))
      ..httpClientAdapter = adapter;
    final service = GitHubApiService(dio: dio);

    final info = await service.fetchLatestRelease(
      owner: 'Aaalice233',
      repo: 'Aaalice_NAI_Launcher',
      currentVersion: '1.8.0',
      includePrerelease: true,
    );

    expect(info.version, '1.8.2-beta.1+33');
    expect(adapter.requestedPages, [1, 2]);
  });

  test('prerelease lookup rejects a non-list API response', () async {
    final dio = Dio(BaseOptions(baseUrl: GitHubApiService.defaultBaseUrl))
      ..httpClientAdapter = _InvalidReleaseListDioAdapter();
    final service = GitHubApiService(dio: dio);

    await expectLater(
      service.fetchLatestRelease(
        owner: 'Aaalice233',
        repo: 'Aaalice_NAI_Launcher',
        currentVersion: '1.8.0',
        includePrerelease: true,
      ),
      throwsA(
        isA<GitHubApiException>().having(
          (error) => error.type,
          'type',
          GitHubReleaseErrorType.invalidResponse,
        ),
      ),
    );
  });

  test(
    'prerelease lookup falls back to stable when list has only data packs',
    () async {
      final adapter = _StableReleaseDioAdapter(
        releases: const [
          {
            'tag_name': 'autocomplete-data-one',
            'draft': false,
            'prerelease': true,
          },
          {
            'tag_name': 'autocomplete-data-two',
            'draft': false,
            'prerelease': true,
          },
        ],
      );
      final dio = Dio(BaseOptions(baseUrl: GitHubApiService.defaultBaseUrl))
        ..httpClientAdapter = adapter;
      final service = GitHubApiService(dio: dio);

      final info = await service.fetchLatestRelease(
        owner: 'Aaalice233',
        repo: 'Aaalice_NAI_Launcher',
        currentVersion: '1.8.0+31',
        includePrerelease: true,
        platform: 'windows-installer',
      );

      expect(info.version, '1.8.1+32');
    },
  );

  test(
    'prerelease manifest must match the tag selected from the release list',
    () async {
      final dio = Dio(BaseOptions(baseUrl: GitHubApiService.defaultBaseUrl))
        ..httpClientAdapter = _MismatchedPrereleaseDioAdapter();
      final service = GitHubApiService(dio: dio);

      await expectLater(
        service.fetchLatestRelease(
          owner: 'Aaalice233',
          repo: 'Aaalice_NAI_Launcher',
          currentVersion: '1.8.0+31',
          includePrerelease: true,
        ),
        throwsA(
          isA<GitHubApiException>().having(
            (error) => error.type,
            'type',
            GitHubReleaseErrorType.invalidResponse,
          ),
        ),
      );
    },
  );
}

class _StableReleaseDioAdapter implements HttpClientAdapter {
  static const manifestUrl =
      'https://github.com/Aaalice233/Aaalice_NAI_Launcher/'
      'releases/latest/download/release_manifest.json';
  static const setupUrl =
      'https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/'
      'download/v1.8.1/NAI_Launcher_Windows_1.8.1%2B32_Setup.exe';
  static const notesUrl =
      'https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/'
      'download/v1.8.1/release_notes_v1.8.1.md';
  static const setupSha256 =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  _StableReleaseDioAdapter({this.manifestOverride, this.releases});

  final Map<String, dynamic>? manifestOverride;
  final List<dynamic>? releases;
  RequestOptions? manifestRequest;
  int apiRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.host == 'api.github.com' && releases != null) {
      apiRequests++;
      return ResponseBody.fromString(
        jsonEncode(releases),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.uri.toString() == manifestUrl) {
      manifestRequest = options;
      return ResponseBody.fromString(
        jsonEncode(
          manifestOverride ??
              {
                'version': '1.8.1+32',
                'tag': 'v1.8.1',
                'name': 'NAI Launcher v1.8.1',
                'publishedAt': '2026-08-22T00:00:00Z',
                'assets': [
                  {
                    'platform': 'windows',
                    'type': 'windows-installer',
                    'fileName': 'NAI_Launcher_Windows_1.8.1+32_Setup.exe',
                    'downloadUrl': setupUrl,
                    'sha256': setupSha256,
                    'size': 123,
                  },
                ],
              },
        ),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/octet-stream'],
        },
      );
    }
    if (options.uri.toString() == notesUrl) {
      return ResponseBody.fromString(
        '### Fixed\n\n- Fixed update checks.',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/octet-stream'],
        },
      );
    }
    if (options.uri.host == 'api.github.com') apiRequests++;
    return ResponseBody.fromString('not found', 404);
  }

  @override
  void close({bool force = false}) {}
}

class _StatusDioAdapter implements HttpClientAdapter {
  _StatusDioAdapter(this.statusCode);

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('request failed', statusCode);

  @override
  void close({bool force = false}) {}
}

class _MixedReleaseDioAdapter implements HttpClientAdapter {
  static const betaTag = 'v1.8.2-beta.1';
  static const betaManifestUrl =
      'https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/'
      'download/$betaTag/release_manifest.json';
  static const betaAssetUrl =
      'https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/'
      'download/$betaTag/NAI_Launcher_Windows_Beta_Portable.zip';

  int releaseListRequests = 0;
  int atomRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.host == 'api.github.com' &&
        options.uri.path.endsWith('/releases')) {
      releaseListRequests++;
      expect(options.uri.queryParameters['per_page'], '100');
      expect(options.uri.queryParameters['page'], '1');
      expect(options.headers['Accept'], 'application/vnd.github+json');
      expect(options.headers['User-Agent'], 'Aaalice-NAI-Launcher');
      return ResponseBody.fromString(
        jsonEncode([
          {
            'tag_name': 'autocomplete-data-cooccurrence-2dadc5bf-v2',
            'draft': false,
            'prerelease': true,
          },
          {'tag_name': 'v1.8.2-..', 'draft': false, 'prerelease': true},
          {'tag_name': 'v1.8.3-beta.1', 'draft': true, 'prerelease': true},
          {'tag_name': betaTag, 'draft': false, 'prerelease': true},
          {'tag_name': 'v1.8.1', 'draft': false, 'prerelease': false},
        ]),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.uri.path.endsWith('/releases.atom')) atomRequests++;
    if (options.uri.toString() == betaManifestUrl) {
      return ResponseBody.fromString(
        jsonEncode({
          'version': '1.8.2-beta.1+33',
          'tag': betaTag,
          'name': 'NAI Launcher $betaTag',
          'publishedAt': '2026-08-22T00:00:00Z',
          'releaseNotes': 'Preview',
          'assets': [
            {
              'platform': 'windows',
              'type': 'windows-portable',
              'fileName': 'NAI_Launcher_Windows_Beta_Portable.zip',
              'downloadUrl': betaAssetUrl,
              'sha256':
                  'abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd',
              'size': 123,
            },
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/octet-stream'],
        },
      );
    }
    throw StateError('Unexpected prerelease request: ${options.uri}');
  }

  @override
  void close({bool force = false}) {}
}

class _PaginatedReleaseDioAdapter extends _MixedReleaseDioAdapter {
  final List<int> requestedPages = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.host == 'api.github.com' &&
        options.uri.path.endsWith('/releases')) {
      final page = int.parse(options.uri.queryParameters['page']!);
      requestedPages.add(page);
      final releases = page == 1
          ? List.generate(
              100,
              (index) => {
                'tag_name': 'autocomplete-data-$index',
                'draft': false,
                'prerelease': true,
              },
            )
          : [
              {
                'tag_name': _MixedReleaseDioAdapter.betaTag,
                'draft': false,
                'prerelease': true,
              },
            ];
      return ResponseBody.fromString(
        jsonEncode(releases),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

class _InvalidReleaseListDioAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'message': 'unexpected object'}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MismatchedPrereleaseDioAdapter implements HttpClientAdapter {
  static const selectedTag = 'v1.8.2-beta.1';
  static const returnedTag = 'v1.8.3-beta.1';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.host == 'api.github.com' &&
        options.uri.path.endsWith('/releases')) {
      return ResponseBody.fromString(
        jsonEncode([
          {'tag_name': selectedTag, 'draft': false, 'prerelease': true},
        ]),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    expect(
      options.uri.toString(),
      'https://github.com/Aaalice233/Aaalice_NAI_Launcher/'
      'releases/download/$selectedTag/release_manifest.json',
    );
    return ResponseBody.fromString(
      jsonEncode({
        'version': '1.8.3-beta.1',
        'tag': returnedTag,
        'assets': [
          {
            'platform': 'windows',
            'type': 'windows-portable',
            'fileName': 'NAI_Launcher_Windows_Beta_Portable.zip',
            'downloadUrl':
                'https://github.com/Aaalice233/Aaalice_NAI_Launcher/'
                'releases/download/$returnedTag/'
                'NAI_Launcher_Windows_Beta_Portable.zip',
            'sha256':
                'abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd',
            'size': 123,
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/octet-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
