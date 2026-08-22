import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/github_api_service.dart';
import 'package:nai_launcher/data/models/version/release_asset_info.dart';

void main() {
  test('merges octet-stream release manifest for in-app updates', () async {
    final adapter = _ReleaseDioAdapter();
    final dio = Dio(BaseOptions(baseUrl: GitHubApiService.defaultBaseUrl))
      ..httpClientAdapter = adapter;
    final service = GitHubApiService(dio: dio);

    final info = await service.fetchLatestRelease(
      owner: 'Aaalice233',
      repo: 'Aaalice_NAI_Launcher',
      currentVersion: '1.7.1',
      platform: 'windows-installer',
    );

    expect(info.primaryAsset?.type, ReleaseAssetType.windowsInstaller);
    expect(info.primaryAsset?.sha256, _ReleaseDioAdapter.setupSha256);
    expect(info.supportsInAppInstall, isTrue);
    expect(adapter.manifestRequest?.responseType, ResponseType.plain);
  });
}

class _ReleaseDioAdapter implements HttpClientAdapter {
  static const manifestUrl = 'https://downloads.example/release_manifest.json';
  static const setupUrl = 'https://downloads.example/NAI_Launcher_Setup.exe';
  static const setupSha256 =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  RequestOptions? manifestRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.toString() == manifestUrl) {
      manifestRequest = options;
      return ResponseBody.fromString(
        jsonEncode({
          'assets': [
            {
              'platform': 'windows',
              'type': 'windows-installer',
              'fileName': 'NAI_Launcher_Setup.exe',
              'downloadUrl': setupUrl,
              'sha256': setupSha256,
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

    return ResponseBody.fromString(
      jsonEncode({
        'tag_name': 'v1.7.2',
        'name': 'NAI Launcher v1.7.2',
        'body': 'Fixes',
        'published_at': '2026-08-21T00:00:00Z',
        'html_url': 'https://github.com/example/releases/v1.7.2',
        'assets': [
          {
            'name': 'release_manifest.json',
            'browser_download_url': manifestUrl,
            'size': 500,
          },
          {
            'name': 'NAI_Launcher_Setup.exe',
            'browser_download_url': setupUrl,
            'size': 123,
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
