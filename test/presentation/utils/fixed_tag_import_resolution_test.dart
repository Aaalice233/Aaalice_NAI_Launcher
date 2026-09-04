import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/presentation/utils/fixed_tag_import_resolution.dart';

void main() {
  test('structured empty snapshot is authoritative', () {
    final resolution = resolveFixedTagImport(
      metadata: const NaiImageMetadata(
        prompt: 'masterpiece, subject',
        fixedTagUsageData: {'version': 1, 'entries': <dynamic>[]},
      ),
      entries: [FixedTagEntry.create(name: 'A', content: 'masterpiece')],
    );

    expect(resolution.source, FixedTagImportSource.structured);
    expect(resolution.snapshot?.entries, isEmpty);
    expect(resolution.metadata.fixedPrefixTags, isEmpty);
  });

  test('legacy fields are authoritative and block extra inference', () {
    final resolution = resolveFixedTagImport(
      metadata: const NaiImageMetadata(
        prompt: 'recorded, current, subject',
        fixedPrefixTags: ['recorded'],
        hasRecordedFixedTagFields: true,
      ),
      entries: [FixedTagEntry.create(name: 'current', content: 'current')],
    );

    expect(resolution.source, FixedTagImportSource.legacyFields);
    expect(resolution.metadata.fixedPrefixTags, ['recorded']);
    expect(resolution.snapshot?.entries.single.renderedContent, 'recorded');
  });

  test('old image can match exact boundaries from the current library', () {
    final entry = FixedTagEntry.create(
      name: 'A',
      content: 'masterpiece, best quality',
    );
    final resolution = resolveFixedTagImport(
      metadata: const NaiImageMetadata(
        prompt: 'masterpiece, best quality, 1girl',
      ),
      entries: [entry],
    );

    expect(resolution.source, FixedTagImportSource.currentLibrary);
    expect(resolution.metadata.mainPrompt, '1girl');
    expect(resolution.snapshot?.entries.single.fixedTagId, entry.id);
  });

  test('issue 219 prompt remains intact when no user-library entry matches', () {
    const prompt =
        '<quality>\n2::best quality::,masterpiece,very aesthetic, highres, absurdres, highly finished\n</quality>';
    final resolution = resolveFixedTagImport(
      metadata: const NaiImageMetadata(prompt: prompt),
      entries: const [],
    );

    expect(resolution.source, FixedTagImportSource.unknown);
    expect(resolution.metadata.mainPrompt, prompt);
    expect(resolution.metadata.fixedPrefixTags, isEmpty);
  });
}
