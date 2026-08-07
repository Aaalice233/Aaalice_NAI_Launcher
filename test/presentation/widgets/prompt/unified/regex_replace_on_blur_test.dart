import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/prompt/prompt_regex_rule.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

/// 失焦时执行正则替换的回归测试
///
/// 关注三件事：开关是否真的门控、规则的 enabled 是否生效、
/// 以及正则替换是否排在 SD 语法转换之前。
void main() {
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Future<void> pumpInput(
    WidgetTester tester, {
    required bool enableRegexReplace,
    required List<PromptRegexRule> rules,
    bool enableSdSyntaxAutoConvert = false,
    bool enableAutoFormat = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _TestLocalStorageService(rules: rules),
          ),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 120,
              child: UnifiedPromptInput(
                controller: controller,
                focusNode: focusNode,
                enableAssistant: false,
                config: UnifiedPromptConfig(
                  enableAutocomplete: false,
                  enableSyntaxHighlight: false,
                  enableAutoFormat: enableAutoFormat,
                  enableSdSyntaxAutoConvert: enableSdSyntaxAutoConvert,
                  enableRegexReplace: enableRegexReplace,
                ),
                maxLines: null,
                expands: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 写入文本、聚焦，然后失焦触发改写
  ///
  /// 失焦后要把时钟推到 Toast 自动关闭之后：改写成功会弹提示，
  /// 它的 3 秒定时器若留到 teardown 会触发 "A Timer is still pending" 断言。
  Future<void> typeAndBlur(WidgetTester tester, String text) async {
    controller.text = text;
    focusNode.requestFocus();
    await tester.pump();
    focusNode.unfocus();
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('开关打开时失焦按规则改写文本', (tester) async {
    await pumpInput(
      tester,
      enableRegexReplace: true,
      rules: [
        const PromptRegexRule(
          id: 'a',
          pattern: 'blue_hair',
          replacement: 'aqua hair',
        ),
      ],
    );

    await typeAndBlur(tester, '1girl, blue_hair, smile');

    expect(controller.text, '1girl, aqua hair, smile');
    expect(tester.takeException(), isNull);
  });

  testWidgets('开关关闭时失焦不改写', (tester) async {
    await pumpInput(
      tester,
      enableRegexReplace: false,
      rules: [
        const PromptRegexRule(
          id: 'a',
          pattern: 'blue_hair',
          replacement: 'aqua hair',
        ),
      ],
    );

    await typeAndBlur(tester, '1girl, blue_hair, smile');

    expect(controller.text, '1girl, blue_hair, smile');
  });

  testWidgets('被禁用的规则不参与替换', (tester) async {
    await pumpInput(
      tester,
      enableRegexReplace: true,
      rules: [
        const PromptRegexRule(
          id: 'a',
          pattern: 'blue_hair',
          replacement: 'aqua hair',
          enabled: false,
        ),
      ],
    );

    await typeAndBlur(tester, '1girl, blue_hair');

    expect(controller.text, '1girl, blue_hair');
  });

  testWidgets('正则替换先于 SD 语法转换执行', (tester) async {
    await pumpInput(
      tester,
      enableRegexReplace: true,
      enableSdSyntaxAutoConvert: true,
      rules: [
        const PromptRegexRule(
          id: 'a',
          pattern: 'blue_hair',
          replacement: '(aqua hair:1.2)',
        ),
      ],
    );

    await typeAndBlur(tester, 'blue_hair');

    // 规则产出的 SD 权重语法被后续的 SD→NAI 转换接手，
    // 若顺序颠倒，结果会停留在 "(aqua hair:1.2)"
    expect(controller.text, '1.2::aqua hair::');
  });

  testWidgets('非法规则被跳过，合法规则照常生效', (tester) async {
    await pumpInput(
      tester,
      enableRegexReplace: true,
      rules: [
        const PromptRegexRule(id: 'broken', pattern: '(unclosed'),
        const PromptRegexRule(
          id: 'ok',
          pattern: 'smile',
          replacement: 'grin',
          sortOrder: 1,
        ),
      ],
    );

    await typeAndBlur(tester, '1girl, smile');

    expect(controller.text, '1girl, grin');
    expect(tester.takeException(), isNull);
  });

  testWidgets('空文本不触发任何处理', (tester) async {
    await pumpInput(
      tester,
      enableRegexReplace: true,
      rules: [const PromptRegexRule(id: 'a', pattern: '.*', replacement: 'x')],
    );

    await typeAndBlur(tester, '');

    expect(controller.text, isEmpty);
  });
}

class _TestLocalStorageService extends LocalStorageService {
  _TestLocalStorageService({required this.rules});

  final List<PromptRegexRule> rules;

  @override
  List<String> getPromptRegexRules() =>
      rules.map((rule) => jsonEncode(rule.toJson())).toList();

  @override
  bool getResolveAliasOnCopy() => false;

  @override
  bool getEnablePromptWeightScroll() => false;

  @override
  bool getEnableAutocomplete() => false;

  @override
  bool getAutoFormatPrompt() => false;

  @override
  bool getHighlightEmphasis() => false;

  @override
  bool getSdSyntaxAutoConvert() => false;

  @override
  bool getEnableCooccurrenceRecommendation() => false;

  @override
  String? getTagLibraryEntriesJson() => null;

  @override
  String? getTagLibraryCategoriesJson() => null;

  @override
  int getTagLibraryViewMode() => 0;
}
