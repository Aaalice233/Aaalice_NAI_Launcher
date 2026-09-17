import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/fixed_tag_usage_projection.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';

Map<String, dynamic> _entry({
  required String content,
  required String position,
  required String promptType,
  required int order,
}) => {
  'name': content,
  'content': content,
  'weight': 1,
  'rendered_content': content,
  'position': position,
  'prompt_type': promptType,
  'order': order,
};

Map<String, dynamic> _snapshot(List<Map<String, dynamic>> entries) => {
  'version': 1,
  'entries': entries,
};

void main() {
  test('positive prefix and suffix are projected out of the main prompt', () {
    final projected = projectFixedTagUsageSnapshot(
      NaiImageMetadata(
        prompt: 'masterpiece, best quality, 1girl, artist:foo',
        fixedTagUsageData: _snapshot([
          _entry(
            content: 'masterpiece, best quality',
            position: 'prefix',
            promptType: 'positive',
            order: 0,
          ),
          _entry(
            content: 'artist:foo',
            position: 'suffix',
            promptType: 'positive',
            order: 1,
          ),
        ]),
      ),
    );

    expect(projected.fixedPrefixTags, ['masterpiece, best quality']);
    expect(projected.fixedSuffixTags, ['artist:foo']);
    expect(projected.mainPrompt, '1girl');
  });

  test('negative fixed tags are projected out of the negative prompt', () {
    final projected = projectFixedTagUsageSnapshot(
      NaiImageMetadata(
        prompt: '1girl',
        negativePrompt: 'lowres, bad anatomy, watermark',
        fixedTagUsageData: _snapshot([
          _entry(
            content: 'lowres',
            position: 'prefix',
            promptType: 'negative',
            order: 0,
          ),
          _entry(
            content: 'watermark',
            position: 'suffix',
            promptType: 'negative',
            order: 1,
          ),
        ]),
      ),
    );

    expect(projected.fixedNegativePrefixTags, ['lowres']);
    expect(projected.fixedNegativeSuffixTags, ['watermark']);
    expect(projected.negativePromptWithoutFixedTags, 'bad anatomy');
  });

  test('quality tags at the tail do not hide the fixed suffix', () {
    final projected = projectFixedTagUsageSnapshot(
      NaiImageMetadata(
        prompt: '1girl, artist:foo, very aesthetic, masterpiece',
        qualityTags: const ['very aesthetic', 'masterpiece'],
        fixedTagUsageData: _snapshot([
          _entry(
            content: 'artist:foo',
            position: 'suffix',
            promptType: 'positive',
            order: 0,
          ),
        ]),
      ),
    );

    expect(projected.fixedSuffixTags, ['artist:foo']);
    expect(projected.mainPrompt, '1girl');
  });

  test('transparent background marker does not hide the fixed suffix', () {
    final projected = projectFixedTagUsageSnapshot(
      NaiImageMetadata(
        prompt: '1girl, artist:foo, transparent background',
        transparentBackground: true,
        fixedTagUsageData: _snapshot([
          _entry(
            content: 'artist:foo',
            position: 'suffix',
            promptType: 'positive',
            order: 0,
          ),
        ]),
      ),
    );

    expect(projected.fixedSuffixTags, ['artist:foo']);
    expect(projected.mainPrompt, '1girl');
  });

  test('snapshot text that is not on the prompt boundary is not stripped', () {
    const prompt = '1girl, masterpiece, best quality, outdoors';
    final projected = projectFixedTagUsageSnapshot(
      const NaiImageMetadata(
        prompt: prompt,
        fixedTagUsageData: {
          'version': 1,
          'entries': [
            {
              'name': 'A',
              'content': 'masterpiece, best quality',
              'weight': 1,
              'rendered_content': 'masterpiece, best quality',
              'position': 'prefix',
              'prompt_type': 'positive',
              'order': 0,
            },
          ],
        },
      ),
    );

    expect(projected.fixedPrefixTags, isEmpty);
    expect(projected.mainPrompt, prompt);
  });

  test('a mismatched prefix does not block a matching suffix', () {
    final projected = projectFixedTagUsageSnapshot(
      NaiImageMetadata(
        prompt: '1girl, artist:foo',
        fixedTagUsageData: _snapshot([
          _entry(
            content: 'masterpiece',
            position: 'prefix',
            promptType: 'positive',
            order: 0,
          ),
          _entry(
            content: 'artist:foo',
            position: 'suffix',
            promptType: 'positive',
            order: 1,
          ),
        ]),
      ),
    );

    expect(projected.fixedPrefixTags, isEmpty);
    expect(projected.fixedSuffixTags, ['artist:foo']);
    expect(projected.mainPrompt, '1girl');
  });

  test('prefix and suffix may not claim the same tags', () {
    final projected = projectFixedTagUsageSnapshot(
      NaiImageMetadata(
        prompt: 'masterpiece',
        fixedTagUsageData: _snapshot([
          _entry(
            content: 'masterpiece',
            position: 'prefix',
            promptType: 'positive',
            order: 0,
          ),
          _entry(
            content: 'masterpiece',
            position: 'suffix',
            promptType: 'positive',
            order: 1,
          ),
        ]),
      ),
    );

    expect(projected.fixedPrefixTags, ['masterpiece']);
    expect(projected.fixedSuffixTags, isEmpty);
  });

  test('png fixed_* fields stay authoritative over the snapshot', () {
    final projected = projectFixedTagUsageSnapshot(
      NaiImageMetadata(
        prompt: 'recorded, 1girl',
        fixedPrefixTags: const ['recorded'],
        fixedTagUsageData: _snapshot([
          _entry(
            content: 'recorded, 1girl',
            position: 'prefix',
            promptType: 'positive',
            order: 0,
          ),
        ]),
      ),
    );

    expect(projected.fixedPrefixTags, ['recorded']);
    expect(projected.mainPrompt, '1girl');
  });

  test('projection is idempotent', () {
    final metadata = NaiImageMetadata(
      prompt: 'masterpiece, 1girl',
      fixedTagUsageData: _snapshot([
        _entry(
          content: 'masterpiece',
          position: 'prefix',
          promptType: 'positive',
          order: 0,
        ),
      ]),
    );

    final once = projectFixedTagUsageSnapshot(metadata);
    expect(projectFixedTagUsageSnapshot(once), once);
  });

  test('an empty snapshot leaves the prompt untouched', () {
    const prompt = 'masterpiece, 1girl';
    final projected = projectFixedTagUsageSnapshot(
      const NaiImageMetadata(
        prompt: prompt,
        fixedTagUsageData: {'version': 1, 'entries': <dynamic>[]},
      ),
    );

    expect(projected.fixedPrefixTags, isEmpty);
    expect(projected.mainPrompt, prompt);
  });
}
