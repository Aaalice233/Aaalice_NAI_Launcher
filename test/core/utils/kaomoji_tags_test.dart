import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/kaomoji_tags.dart';

void main() {
  test('every kaomoji keeps its underscores', () {
    for (final kaomoji in KaomojiTags.values) {
      expect(KaomojiTags.underscoresToSpaces(kaomoji), kaomoji);
    }
  });

  test('ordinary tags switch to spaces', () {
    expect(KaomojiTags.underscoresToSpaces('long_hair'), 'long hair');
    expect(KaomojiTags.underscoresToSpaces('solo'), 'solo');
  });

  test('kaomoji inside prompt syntax are recognized', () {
    expect(
      KaomojiTags.underscoresToSpaces('{^_^}, 1.2::>_<::, ^_^;, smile ^_^'),
      '{^_^}, 1.2::>_<::, ^_^;, smile ^_^',
    );
  });

  test('look-alike fragments of longer tags are not kaomoji', () {
    expect(KaomojiTags.underscoresToSpaces('foo_ood'), 'foo ood');
    expect(KaomojiTags.underscoresToSpaces('x_x_x'), 'x x x');
    expect(KaomojiTags.underscoresToSpaces('o_o_eyes'), 'o o eyes');
  });
}
