import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/prompt_edit_document.dart';

void main() {
  test(
    'selection translations require one entire leaf or its unweighted text',
    () {
      const source = '1.20::blue eyes::, cat';
      expect(
        PromptEditDocument.singleSelected(
          source,
          0,
          source.indexOf(','),
        )?.label,
        'blue eyes',
      );
      expect(
        PromptEditDocument.singleSelected(source, 6, 15)?.label,
        'blue eyes',
      );
      expect(PromptEditDocument.singleSelected(source, 6, 10), isNull);
      expect(
        PromptEditDocument.singleSelected(source, 0, source.length),
        isNull,
      );
    },
  );
  test(
    'full mixed prompt remains lossless including large and negative weights',
    () {
      const source =
          r'''ultra\_complexity, year\_2026, 20::best\_quality::, 30::very\_aesthetic::,
2::amazing\_quality, masterpiece, ultra-detailed, absurdres::, 1.2::*digital\_illustration::,
-2::simple\_illustration::, artist:1=2, artist:rido*(ridograph), 1.45::todder::,
1.3::blender (medium), 3d::, [[greasy\_skin]], {shiny\_skin, shiny, skindentation},
-3::unfinished\_small\_objects, chibi::, .5::cat::, 1.::dog::,
<span title="a > b, c">自然语言, HTML</span>, ||red, blue||, <random:cats,dogs>, 🐱''';
      final roots = PromptEditDocument.parse(source);
      expect(roots.every((span) => span.complete), isTrue);
      for (final leaf in roots.expand((root) => root.leaves)) {
        expect(source.substring(leaf.start, leaf.end), leaf.raw);
      }
      expect(PromptEditDocument.effectiveText(source), source);
    },
  );
  test('ranges preserve duplicate tags, separators and nested syntax', () {
    const source = '  cat,\n cat , {{red, blue}}, ||a,b||, escaped\\,comma';
    final spans = PromptEditDocument.parse(source);
    expect(spans.map((span) => span.raw), [
      'cat',
      'cat',
      '{{red, blue}}',
      '||a,b||',
      r'escaped\,comma',
    ]);
    for (final span in spans) {
      expect(source.substring(span.start, span.end), span.raw);
      expect(span.complete, isTrue);
    }
  });
  test('disabled syntax round trips backslashes and closing delimiters', () {
    const source = r'{{cat, dog}}, a\b */ end';
    final encoded = PromptEditDocument.disable(source);
    expect(PromptEditDocument.decodeDisabled(encoded), source);
    expect(PromptEditDocument.parse(encoded).single.text, source);
    expect(PromptEditDocument.effectiveText('a, $encoded, b'), 'a, b');
  });
  test('only unescaped dedicated markers are removed', () {
    const source = r'/*ordinary*/ \/\*disabled:x*/';
    expect(PromptEditDocument.effectiveText(source), source);
    expect(
      PromptEditDocument.effectiveText(r'\/*disabled:x*/'),
      r'\/*disabled:x*/',
    );
  });
  test(
    'incomplete syntax remains editable but is not structurally complete',
    () {
      expect(PromptEditDocument.parse('cat, {dog').last.complete, isFalse);
      expect(PromptEditDocument.parse('/*disabled:x').single.complete, isFalse);
      expect(
        () => PromptEditDocument.effectiveText('/*disabled:x'),
        throwsFormatException,
      );
    },
  );
  test('natural language, comparisons and emoticons are literal text', () {
    const source =
        "A girl is standing in the rain. It's quiet, <3, a < b and c > d";
    final spans = PromptEditDocument.parse(source);
    expect(spans.map((span) => span.raw), [
      "A girl is standing in the rain. It's quiet",
      '<3',
      'a < b and c > d',
    ]);
    expect(spans.every((span) => span.complete), isTrue);
    expect(PromptEditDocument.effectiveText(source), source);
  });
  test('HTML, quoted prose and comma-containing aliases remain opaque', () {
    const source =
        '''<span title="a > b, c"><b>red, blue</b></span>, <random:词库A,词库B>, "blue, red", <!-- x,y -->''';
    final spans = PromptEditDocument.parse(source);
    expect(spans, hasLength(4));
    expect(spans.first.raw, '<span title="a > b, c"><b>red, blue</b></span>');
    expect(spans.every((span) => span.complete), isTrue);
  });
  test('combined groups preserve leaf source ranges and all weight wrappers', () {
    const source =
        '1.20::{cat, [dog], -2::bird::}::, {{wolf}}, negative(red, blue), ||a,b||';
    final roots = PromptEditDocument.parse(source);
    expect(roots.every((span) => span.complete), isTrue);
    expect(roots.expand((span) => span.leaves).map((span) => span.label), [
      'cat',
      'dog',
      'bird',
      'wolf',
      'red',
      'blue',
      '||a,b||',
    ]);
    for (final leaf in roots.expand((span) => span.leaves)) {
      expect(source.substring(leaf.start, leaf.end), leaf.raw);
      expect(source.substring(leaf.editStart, leaf.editEnd), leaf.label);
    }
  });
  test('removing disabled groups does not leave active delimiter tokens', () {
    expect(
      PromptEditDocument.effectiveText('/*disabled:a*/, /*disabled:b*/, c'),
      'c',
    );
    expect(
      PromptEditDocument.effectiveText(
        'a, { /*disabled:b*/, /*disabled:c*/ }, d',
      ),
      'a, d',
    );
    expect(
      PromptEditDocument.effectiveText('{a, /*disabled:b*/, c}'),
      '{a, c}',
    );
    expect(PromptEditDocument.effectiveText('a /*disabled:b*/ c'), 'a  c');
  });
}
