import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_providers.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/core/autocomplete/zh_dictionary_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/prompt/nai_syntax_controller.dart';
import 'package:nai_launcher/presentation/widgets/prompt/quick_translate_prompt_field.dart';

void main() {
  testWidgets('汉化预览使用独立草稿且再次点击完整还原原输入', (tester) async {
    final source = TextEditingController(
      text: '1.20::best_quality::, unknown_artist',
    )..selection = const TextSelection(baseOffset: 0, extentOffset: 4);
    final originalValue = source.value;
    addTearDown(source.dispose);

    await _pumpField(
      tester,
      source: source,
      dictionary: _FakeZhDictionaryService(installed: true),
      lookup: TagTranslationLookup.fromResolver((tags) async {
        return {'best_quality': '极高质量'};
      }),
    );

    final button = find.byKey(const ValueKey('quick-translate-button'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    final preview = find.byKey(const ValueKey('quick-translate-preview-input'));
    expect(preview, findsOneWidget);
    expect(find.text('1.20::极高质量::, unknown_artist'), findsOneWidget);
    final previewEditable = tester.widget<EditableText>(
      find.descendant(of: preview, matching: find.byType(EditableText)),
    );
    expect(previewEditable.controller, isA<NaiSyntaxController>());
    final highlighted = previewEditable.controller.buildTextSpan(
      context: tester.element(preview),
      style: const TextStyle(),
      withComposing: false,
    );
    expect(highlighted.children, hasLength(greaterThan(1)));
    expect(
      highlighted.children!.where((span) => span.style != null),
      isNotEmpty,
    );
    expect(source.value, originalValue);
    expect(find.byIcon(Icons.translate), findsOneWidget);

    await tester.enterText(
      find.descendant(of: preview, matching: find.byType(TextField)),
      '仅修改汉化预览',
    );
    expect(source.value, originalValue);

    await tester.tap(button);
    await tester.pump();
    expect(preview, findsNothing);
    expect(source.value, originalValue);
    expect(find.byIcon(Icons.translate_outlined), findsOneWidget);
  });

  testWidgets('原输入被外部更新时自动关闭旧快照', (tester) async {
    final source = TextEditingController(text: 'best_quality');
    addTearDown(source.dispose);
    await _pumpField(
      tester,
      source: source,
      dictionary: _FakeZhDictionaryService(installed: true),
      lookup: TagTranslationLookup.fromResolver(
        (tags) async => {'best_quality': '极高质量'},
      ),
    );

    await tester.tap(find.byKey(const ValueKey('quick-translate-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('quick-translate-preview-input')),
      findsOneWidget,
    );

    source.text = 'new_prompt';
    await tester.pump();

    expect(
      find.byKey(const ValueKey('quick-translate-preview-input')),
      findsNothing,
    );
    expect(source.text, 'new_prompt');
  });

  testWidgets('完整混合语法提示词可翻译且短标签不会触发模糊查找越界', (tester) async {
    const reportedPrompt =
        r'''ultra\_complexity, year\_2026, year\_2024, year\_2025, 20::best\_quality::, 30::very\_aesthetic::, 2::amazing\_quality, masterpiece, ultra-detailed, absurdres::, 1.2::*digital\_illustration::, -2::simple\_illustration::, artist:sweetonedollar, artist:modare, artist:mx2j, artist:shycocoa, artist:1=2, artist:bacheally, artist:kanzarin, artist:wlop, artist:rido*(ridograph), 1.45::todder::, 1.40::artist:mx2j::, 1.3::blender (medium), 3d::, 1.3::realistic, photorealistic, photo (medium)::, [[greasy\_skin]], {shiny\_skin, shiny, skindentation, curvy}, detailed\_skin, 1.4::handmade, octane\_render, c4d::, perfect\_rendering, realistic\_rendering, detailed\_textures, steam, heavy\_breath, steaming\_body, fine\_fabric\_emphasis,
-3::unfinished\_small\_objects, chibi::,
ultra\_complexity, perfect\_rendering, realistic\_rendering, detailed\_textures, intricate\_details, depth\_of\_field, -3::oiled\_skin, shiny\_skin::, 3::realistic\_skin::''';
    final source = TextEditingController(text: reportedPrompt);
    addTearDown(source.dispose);
    await _pumpField(
      tester,
      source: source,
      dictionary: _FakeZhDictionaryService(installed: true),
      lookup: TagTranslationLookup.fromResolver(
        (tags) async => {
          if (tags.contains('rido_(ridograph)')) 'rido_(ridograph)': 'Rido（画师）',
          if (tags.contains('3d')) '3d': '3D',
        },
        fuzzyResolver: (tags) async => {
          if (tags.contains('todder')) 'todder': '幼儿',
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('quick-translate-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quick-translate-preview-input')),
      findsOneWidget,
    );
    final previewText = tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(const ValueKey('quick-translate-preview-input')),
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text;
    expect(previewText, contains('artist:wlop, Rido（画师）, 1.45::幼儿::'));
    expect(previewText, contains('3D::'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('未安装词库时确认后跳转数据设置并开始下载', (tester) async {
    final source = TextEditingController(text: 'best_quality');
    final dictionary = _FakeZhDictionaryService(installed: false);
    addTearDown(source.dispose);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => _FieldHost(source: source),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => Scaffold(
            body: Text('settings:${state.uri.queryParameters['section']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          zhDictionaryServiceProvider.overrideWith((ref) => dictionary),
        ],
        child: MaterialApp.router(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('quick-translate-button')));
    await tester.pumpAndSettle();
    expect(find.text('需要汉化词库'), findsOneWidget);

    await tester.tap(find.text('前往并下载'));
    await tester.pumpAndSettle();

    expect(find.text('settings:storage'), findsOneWidget);
    expect(dictionary.installCalled, isTrue);
  });

  testWidgets('紧凑触屏与桌面宽度均保持右下角入口和安全命中区', (tester) async {
    for (final scenario in [
      (size: const Size(360, 640), policy: InteractionPolicy.touchFirst),
      (size: const Size(1180, 800), policy: InteractionPolicy.neutral),
    ]) {
      await tester.binding.setSurfaceSize(scenario.size);
      final source = TextEditingController(text: 'best_quality');
      await _pumpField(
        tester,
        source: source,
        dictionary: _FakeZhDictionaryService(installed: true),
        lookup: TagTranslationLookup.fromResolver((tags) async => const {}),
        policy: scenario.policy,
      );

      final fieldRect = tester.getRect(
        find.byKey(const ValueKey('quick-translate-field')),
      );
      final buttonRect = tester.getRect(
        find.byKey(const ValueKey('quick-translate-button')),
      );
      expect(buttonRect.right, lessThanOrEqualTo(fieldRect.right - 4));
      expect(buttonRect.bottom, lessThanOrEqualTo(fieldRect.bottom - 4));
      expect(buttonRect.width, greaterThanOrEqualTo(40));
      expect(buttonRect.height, greaterThanOrEqualTo(40));
      expect(tester.takeException(), isNull);
      source.dispose();
    }
    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _pumpField(
  WidgetTester tester, {
  required TextEditingController source,
  required _FakeZhDictionaryService dictionary,
  required TagTranslationLookup lookup,
  InteractionPolicy policy = InteractionPolicy.neutral,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        zhDictionaryServiceProvider.overrideWith((ref) => dictionary),
        tagTranslationLookupProvider.overrideWithValue(lookup),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: const ValueKey('quick-translate-field'),
              width: 320,
              height: 180,
              child: InteractionPolicyScope(
                initialPolicy: policy,
                child: QuickTranslatePromptField(
                  controller: source,
                  child: ThemedInput(
                    controller: source,
                    maxLines: null,
                    expands: true,
                    contentPadding: EdgeInsets.fromLTRB(
                      12,
                      10,
                      12,
                      QuickTranslatePromptField.contentBottomClearance(policy),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FieldHost extends StatelessWidget {
  const _FieldHost({required this.source});

  final TextEditingController source;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SizedBox(
      width: 320,
      height: 180,
      child: QuickTranslatePromptField(
        controller: source,
        child: ThemedInput(controller: source, maxLines: null, expands: true),
      ),
    ),
  );
}

class _FakeZhDictionaryService extends ZhDictionaryService {
  _FakeZhDictionaryService({required bool installed})
    : _state = ZhDictionaryState(isInstalled: installed);

  ZhDictionaryState _state;
  bool installCalled = false;

  @override
  ZhDictionaryState get state => _state;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> installOrUpdate() async {
    installCalled = true;
    _state = const ZhDictionaryState(isInstalled: true);
    notifyListeners();
  }
}
