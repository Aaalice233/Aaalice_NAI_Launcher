import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/prompt_tag_utils.dart';

void main() {
  group('PromptTagUtils.splitTopLevel', () {
    test('splits ordinary comma, full-width comma, and newline separators', () {
      expect(PromptTagUtils.splitTopLevel('1girl, solo，smile\nblue eyes'), [
        '1girl',
        'solo',
        'smile',
        'blue eyes',
      ]);
    });

    test('keeps emphasis wrappers and numeric weights intact', () {
      expect(
        PromptTagUtils.splitTopLevel(
          '{red hair, blue eyes}, 1.2::artist:foo,bar::, solo',
        ),
        ['{red hair, blue eyes}', '1.2::artist:foo,bar::', 'solo'],
      );
    });

    test('keeps escaped separators inside a tag', () {
      expect(PromptTagUtils.splitTopLevel(r'foo\,bar, baz'), [
        r'foo\,bar',
        'baz',
      ]);
    });

    test('flattens numeric weight groups into display tags', () {
      expect(
        PromptTagUtils.splitForDisplay(
          '0.6::mignon, artist:quasarcake, artist:houkisei::, solo',
        ),
        ['mignon', 'artist:quasarcake', 'artist:houkisei', 'solo'],
      );
    });
  });
}
