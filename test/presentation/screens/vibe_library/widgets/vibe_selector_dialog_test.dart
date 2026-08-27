import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_selector_dialog.dart';

void main() {
  testWidgets('手机宽度下筛选工具栏完整布局且不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vibeLibraryNotifierProvider.overrideWith(
            _EmptyVibeLibraryNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => VibeSelectorDialog.show(context: context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('全部类型'), findsOneWidget);
    expect(find.text('创建时间'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('热门标签只基于有限样本计算，避免打开选择器时整库聚合', () {
    final entries = [
      for (var i = 0; i < 80; i++)
        _buildEntry(
          id: 'entry-$i',
          tags: i < 40 ? ['focus', 'common'] : ['late-$i'],
        ),
    ];

    final topTags = computeInitialTopTags(entries);

    expect(topTags, containsAll(['focus', 'common']));
    expect(
      topTags.any((tag) => tag.startsWith('late-')),
      isFalse,
      reason: '首屏热门标签不应为整库扫描所有条目付出同步开销',
    );
  });
}

class _EmptyVibeLibraryNotifier extends VibeLibraryNotifier {
  @override
  VibeLibraryState build() => const VibeLibraryState();

  @override
  Future<void> loadFromCache({bool showLoading = false}) async {}
}

VibeLibraryEntry _buildEntry({required String id, required List<String> tags}) {
  return VibeLibraryEntry(
    id: id,
    name: id,
    vibeDisplayName: id,
    vibeEncoding: 'encoding-$id',
    strength: 0.6,
    infoExtracted: 0.7,
    sourceTypeIndex: VibeSourceType.naiv4vibe.index,
    tags: tags,
    createdAt: DateTime(2026, 4, 14),
  );
}
