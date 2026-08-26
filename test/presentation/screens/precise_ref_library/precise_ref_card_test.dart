import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/precise_ref/precise_ref_library_entry.dart';
import 'package:nai_launcher/data/services/precise_ref_library_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/precise_ref_library/widgets/precise_ref_card.dart';

class _FakeStorage extends PreciseRefLibraryStorageService {
  @override
  Future<Uint8List?> getDisplayThumbnail(String id) async => null;
}

void main() {
  final entry = PreciseRefLibraryEntry(
    id: 'entry-1',
    name: '银发少女',
    imagePath: r'C:\refs\entry-1.png',
    typeIndex: PreciseRefType.character.index,
    strength: 1.0,
    fidelity: 0.85,
    isFavorite: true,
    createdAt: DateTime(2026, 8, 1),
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    VoidCallback? onSendToPreciseRef,
    VoidCallback? onToggleFavorite,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preciseRefLibraryStorageServiceProvider.overrideWithValue(
            _FakeStorage(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 250,
                child: PreciseRefCard(
                  entry: entry,
                  onSendToPreciseRef: onSendToPreciseRef,
                  onToggleFavorite: onToggleFavorite,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('显示名称、参数与类型徽标', (tester) async {
    await pumpCard(tester);

    expect(find.text('银发少女'), findsOneWidget);
    expect(find.text('S 1.0 · F 0.85'), findsOneWidget);
    // 触控布局收起徽标文字，但仍保留可访问名称。
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.semanticLabel == '角色',
      ),
      findsOneWidget,
    );
    // 收藏态显示实心星标
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('点击卡片触发发送回调，点击星标触发收藏回调', (tester) async {
    var sendCount = 0;
    var favoriteCount = 0;
    await pumpCard(
      tester,
      onSendToPreciseRef: () => sendCount++,
      onToggleFavorite: () => favoriteCount++,
    );

    await tester.tap(
      find.byKey(const Key('precise-ref-card-favorite-entry-1')),
    );
    expect(favoriteCount, 1);

    await tester.tap(find.text('银发少女'));
    expect(sendCount, 1);
  });
}
