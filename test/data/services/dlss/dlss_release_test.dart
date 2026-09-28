import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/dlss/dlss_release.dart';

void main() {
  Map<String, dynamic> row() => {
    'id': 1,
    'tag_name': 'v1.3',
    'draft': false,
    'prerelease': false,
    'published_at': '2026-09-03T11:54:32Z',
    'assets': [
      {
        'id': 2,
        'name': 'video2dlssnr_release.zip',
        'size': 123,
        'digest': 'sha256:${'a' * 64}',
        'browser_download_url':
            '$dlssRepositoryUrl/releases/download/v1.3/video2dlssnr_release.zip',
      },
    ],
  };
  test(
    'selects the full pinned release asset and ignores drafts and light-only releases',
    () {
      expect(DlssReleaseSource.parse(row())!.tag, 'v1.3');
      expect(DlssReleaseSource.parse({...row(), 'draft': true}), isNull);
      final light = row();
      (light['assets'] as List).single['name'] =
          'video2dlssnr_release_light.zip';
      expect(DlssReleaseSource.parse(light), isNull);
    },
  );
  test('does not accept a different source or unverifiable digest', () {
    for (final field in ['browser_download_url', 'digest']) {
      final invalid = row();
      (invalid['assets'] as List).single[field] =
          'https://other.invalid/runtime.zip';
      expect(() => DlssReleaseSource.parse(invalid), throwsFormatException);
    }
  });
}
