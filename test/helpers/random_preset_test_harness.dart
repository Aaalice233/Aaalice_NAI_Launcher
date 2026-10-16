import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/tag_library.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_provider.dart';

import 'viewport_scenarios.dart';

/// 只有一个选中预设的随机词库状态；保存只更新内存，不触碰持久化存储
class TestRandomPresetNotifier extends RandomPresetNotifier {
  TestRandomPresetNotifier([
    this._preset = const RandomPreset(id: 'preset', name: 'Preset'),
  ]);

  TestRandomPresetNotifier.categories(
    List<RandomCategory> categories, {
    bool isDefault = false,
  }) : _preset = RandomPreset(
         id: 'preset',
         name: 'Preset',
         isDefault: isDefault,
         categories: categories,
       );

  final RandomPreset _preset;

  @override
  RandomPresetState build() =>
      RandomPresetState(presets: [_preset], selectedPresetId: _preset.id);

  @override
  Future<void> updateCategory(RandomCategory category) async {
    state = state.copyWith(
      presets: [state.selectedPreset!.updateCategory(category)],
    );
  }

  RandomTagGroup savedGroup(String id) => state.selectedPreset!.categories
      .expand((category) => category.groups)
      .firstWhere((group) => group.id == id);
}

/// 不读本地存储的空词库
class EmptyTagLibraryNotifier extends TagLibraryNotifier {
  @override
  TagLibraryState build() => TagLibraryState(
    library: TagLibrary(
      id: 'catalog',
      name: 'Catalog',
      lastUpdated: DateTime.utc(2026),
      source: TagLibrarySource.catalog,
      dataVersion: 'test',
      sourceUrl: 'https://example.com/catalog.csv',
      sourceCommit: 'test',
      sourceLicense: 'Unlicense',
      sourceVersionDate: DateTime.utc(2026),
      sourceCatalogTagCount: 1,
      sourceCatalogAliasCount: 0,
      categories: const {},
    ),
  );
}

/// 按给定视口装配随机词库界面：预设与词库状态、标签翻译、本地化、触屏交互策略和文字缩放
///
/// 先卸载上一次装配的整棵树，同一用例内逐个尺寸重建时不沿用弹窗与展开状态。
Future<void> pumpRandomManager(
  WidgetTester tester, {
  required Widget home,
  required RandomPresetNotifier Function() presets,
  Size size = const Size(1180, 900),
  double textScale = 1,
  FakeViewPadding padding = FakeViewPadding.zero,
  Locale locale = const Locale('en'),
  InteractionPolicy interactionPolicy = InteractionPolicy.touchFirst,
  List<Override> overrides = const [],
}) async {
  applyViewport(tester, (size: size, keyboard: 0, padding: padding));
  tester.view.viewPadding = padding;

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomPresetNotifierProvider.overrideWith(presets),
        tagLibraryNotifierProvider.overrideWith(EmptyTagLibraryNotifier.new),
        tagTranslationLookupProvider.overrideWithValue(
          TagTranslationLookup.fromResolver((_) async => const {}),
        ),
        ...overrides,
      ],
      child: localizedTestApp(
        home: home,
        locale: locale,
        textScale: textScale,
        interactionPolicy: interactionPolicy,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
