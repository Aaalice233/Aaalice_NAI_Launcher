import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/services/prompt_token_counter_service.dart';
import 'package:nai_launcher/core/services/tokenizers/qwen_prompt_token_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QwenPromptTokenEncoder encoder;

  setUpAll(() {
    final compressed = File(
      'assets/data/tokenizers/qwen35_bpe.txt.gz',
    ).readAsBytesSync();
    encoder = QwenPromptTokenEncoder.fromAssetText(
      utf8.decode(GZipCodec().decode(compressed)),
    );
  });

  test('matches the token counts reported by the official tokenizer', () {
    // Golden 取自 NovelAI 官方 /tokenizer 页面的 "Qwen 3.5 Tokenizer"。
    final golden =
        jsonDecode(
              File('test/fixtures/qwen35_token_golden.json').readAsStringSync(),
            )
            as List<dynamic>;

    expect(golden, isNotEmpty);
    for (final entry in golden.cast<Map<String, dynamic>>()) {
      final text = entry['text'] as String;
      final expected = entry['tokens'] as int;
      final label = text.length > 40 ? '${text.substring(0, 40)}…' : text;

      expect(
        encoder.countTokensSync(text),
        expected,
        reason: 'token count mismatch for ${jsonEncode(label)}',
      );
    }
  });

  test('normalizes decomposed input before counting', () {
    // 官方前端会先做 NFC，否则分解形式的韩文会被拆成一堆字节。
    expect(encoder.countTokensSync('한국'), 1);
    expect(
      encoder.countTokensSync('한국'),
      1,
    );
  });

  test('treats special tokens as a single token', () {
    expect(encoder.countTokensSync('<|endoftext|>'), 1);
    expect(encoder.countTokensSync('<|im_start|>'), 1);
  });

  test('counts an empty prompt as zero tokens', () {
    expect(encoder.countTokensSync(''), 0);
  });

  test('counts weight syntax through the service like the web client', () async {
    // 官网口径：不剥权重语法、不 trim、不加 EOS 校准。
    final service = PromptTokenCounterService(
      encoder: encoder,
      qwenEncoder: encoder,
    );

    expect(
      await service.countTokensForTexts(
        const ['-0.8::feet::'],
        model: ImageModels.v5StagingKey,
        applyWebAdjustment: true,
      ),
      8,
    );
    expect(
      await service.countTokensForTexts(
        const ['1girl, {{blue eyes}}, [smile], -0.8::feet::'],
        model: ImageModels.v5StagingKey,
        applyWebAdjustment: true,
      ),
      19,
    );
  });

  test('loads the tokenizer from the bundled asset', () async {
    final bundled = await QwenPromptTokenEncoder.load(
      assetPath: 'assets/data/tokenizers/qwen35_bpe.txt.gz',
    );

    expect(await bundled.countTokens('hello world'), 2);
  });

  test('stays fast enough for live prompt editing', () {
    final prompt = '1girl, masterpiece, best quality, very aesthetic, ' * 40;
    expect(prompt.length, greaterThan(1800));

    // 首次统计不复用缓存，模拟用户刚粘贴一段长提示词。
    final stopwatch = Stopwatch()..start();
    final tokens = encoder.countTokensSync(prompt);
    stopwatch.stop();

    expect(tokens, greaterThan(0));
    expect(
      stopwatch.elapsedMilliseconds,
      lessThan(200),
      reason: 'token counter runs on every keystroke',
    );
  });
}
