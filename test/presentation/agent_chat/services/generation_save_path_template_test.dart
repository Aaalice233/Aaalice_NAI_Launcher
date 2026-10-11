import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_save_path_template.dart';

void main() {
  test('index padding follows the decimal width of the total', () {
    expect(_expand('{index}.png', index: 3, total: 9), '3.png');
    expect(_expand('{index}.png', index: 3, total: 10), '03.png');
    expect(_expand('{index}.png', index: 12, total: 99), '12.png');
    expect(_expand('{index}.png', index: 7, total: 120), '007.png');
    expect(_expand('{index}.png', index: 120, total: 120), '120.png');
  });

  test('every placeholder occurrence is expanded', () {
    expect(
      _expand('{index}-{seed}-{index}.png', index: 2, total: 10, seed: 41),
      '02-41-02.png',
    );
  });

  test('{id} is replaced literally and never padded', () {
    const id = 'ca6b9b4e-6b0e-4d2f-9a0c-0f3d5a4c7e11';
    expect(_expand('{id}.png', index: 1, total: 1, id: id), '$id.png');
    expect(
      _expand('{index}-{id}-{id}.png', index: 3, total: 10, id: id),
      '03-$id-$id.png',
    );
    // {id} 先展开，展开值里的占位符文本不得再被二次替换。
    expect(
      _expand('{id}.png', index: 4, total: 10, id: 'x-{index}-y'),
      'x-{index}-y.png',
    );
  });

  test('templates without placeholders are returned unchanged', () {
    expect(_expand('result.png', index: 1, total: 1), 'result.png');
  });

  test('a missing seed only fails when the template needs it', () {
    expect(
      () => _expand('{seed}.png', index: 1, total: 1),
      throwsA(isA<GenerationSavePathSeedUnavailable>()),
    );
    expect(_expand('{index}.png', index: 1, total: 1), '1.png');
  });

  test('placeholders are detected in the basename only', () {
    expect(
      GenerationSavePathTemplate.hasPlaceholder('out/a-{index}.png'),
      isTrue,
    );
    expect(
      GenerationSavePathTemplate.hasPlaceholder('out/a-{seed}.png'),
      isTrue,
    );
    expect(GenerationSavePathTemplate.hasPlaceholder('out/{id}.png'), isTrue);
    expect(GenerationSavePathTemplate.hasPlaceholder('{id}/a.png'), isFalse);
    expect(
      GenerationSavePathTemplate.hasPlaceholderInDirectory('{id}/a.png'),
      isTrue,
    );
    expect(GenerationSavePathTemplate.hasPlaceholder('{index}/a.png'), isFalse);
    expect(
      GenerationSavePathTemplate.hasPlaceholder('out/result.png'),
      isFalse,
    );
  });

  test('directory placeholders are reported separately', () {
    expect(
      GenerationSavePathTemplate.hasPlaceholderInDirectory('{index}/a.png'),
      isTrue,
    );
    expect(
      GenerationSavePathTemplate.hasPlaceholderInDirectory('out/{seed}/a.png'),
      isTrue,
    );
    expect(
      GenerationSavePathTemplate.hasPlaceholderInDirectory('out/a-{index}.png'),
      isFalse,
    );
    expect(
      GenerationSavePathTemplate.hasPlaceholderInDirectory('a-{index}.png'),
      isFalse,
    );
  });

  test('backslash separators are treated as path separators', () {
    expect(
      GenerationSavePathTemplate.hasPlaceholder(r'out\a-{index}.png'),
      isTrue,
    );
    expect(
      GenerationSavePathTemplate.hasPlaceholder(r'out\{index}\a.png'),
      isFalse,
    );
    expect(
      GenerationSavePathTemplate.hasPlaceholderInDirectory(
        r'out\{index}\a.png',
      ),
      isTrue,
    );
    expect(
      GenerationSavePathTemplate.hasPlaceholderInDirectory(
        r'out\a-{index}.png',
      ),
      isFalse,
    );
  });

  test('placeholder constants stay part of the public contract', () {
    expect(GenerationSavePathTemplate.indexPlaceholder, '{index}');
    expect(GenerationSavePathTemplate.seedPlaceholder, '{seed}');
    expect(GenerationSavePathTemplate.idPlaceholder, '{id}');
  });
}

String _expand(
  String template, {
  required int index,
  required int total,
  int? seed,
  String id = 'image-id',
}) => GenerationSavePathTemplate.expand(
  template,
  index: index,
  total: total,
  seed: seed,
  id: id,
);
