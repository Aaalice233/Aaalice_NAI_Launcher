import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/data/models/precise_ref/precise_ref_library_entry.dart';
import 'package:nai_launcher/data/services/precise_ref_library_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/precise_ref_library_provider.dart';
import 'package:nai_launcher/presentation/screens/precise_ref_library/precise_ref_library_screen.dart';
import 'package:nai_launcher/presentation/screens/precise_ref_library/widgets/precise_ref_entry_edit_dialog.dart';
import 'package:nai_launcher/presentation/screens/precise_ref_library/widgets/precise_ref_selector_dialog.dart';

void main() {
  setUp(() {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
  });
  tearDown(() => PlatformCapabilities.debugOverride = null);

  test('precise reference grid becomes one-column at narrow 3x text', () {
    final compact = computePreciseRefGridLayout(320, 3);
    final medium = computePreciseRefGridLayout(600, 1);
    final wide = computePreciseRefGridLayout(1180, 1);

    expect(compact.columns, 1);
    expect(wide.columns, greaterThan(medium.columns));
    expect(compact.mainAxisExtent, greaterThan(300));
    expect(compact.padding, 12);
  });

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      'non-empty precise reference library keeps search, filters and edit reachable at ${width.toInt()}px',
      (tester) async {
        await _setViewport(tester, Size(width, 800));
        await _pumpLibrary(tester);

        expect(find.text('目标参考'), findsOneWidget);
        expect(
          find.byKey(const Key('precise-ref-library-search')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('precise-ref-library-favorites-toggle')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('precise-ref-type-filter-all')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('precise-ref-library-search')),
          '目标',
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('目标参考'), findsOneWidget);
        expect(find.text('其他参考'), findsNothing);

        await tester.tap(
          find.byKey(const Key('precise-ref-card-more-target-ref')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithIcon(ListTile, Icons.edit_outlined));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('precise-ref-edit-dialog')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('precise-ref-edit-confirm')),
          findsOneWidget,
        );
        final surfaceKey = switch (width) {
          < 600 => 'adaptive-full-screen-form',
          < 840 => 'adaptive-centered-form',
          _ => 'adaptive-side-sheet',
        };
        final surface = find.byKey(ValueKey(surfaceKey));
        expect(surface, findsOneWidget);
        if (width >= 840) {
          expect(tester.getSize(surface).width, lessThanOrEqualTo(440));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    '320px 3x text selector remains searchable and confirms a local selection above IME',
    (tester) async {
      await _setViewport(
        tester,
        const Size(320, 720),
        padding: const FakeViewPadding(top: 24, bottom: 24),
        viewInsets: const FakeViewPadding(bottom: 180),
      );
      List<PreciseRefLibraryEntry>? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preciseRefLibraryNotifierProvider.overrideWith(
              _PopulatedPreciseRefNotifier.new,
            ),
            preciseRefLibraryStorageServiceProvider.overrideWithValue(
              _ThumbnailFreeStorage(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await PreciseRefSelectorDialog.show(context);
                  },
                  child: const Text('打开选择器'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开选择器'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('precise-ref-selector-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('precise-ref-selector-type-scroll')),
        findsOneWidget,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('adaptive-full-screen-form')))
            .dy,
        greaterThanOrEqualTo(24),
      );
      expect(
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );

      final search = find.byKey(const Key('precise-ref-selector-search'));
      await tester.enterText(search, '参考');
      await tester.pump(const Duration(milliseconds: 250));
      final combinedTypeFilter = find.byKey(
        const Key('precise-ref-type-filter-characterAndStyle'),
      );
      await tester.ensureVisible(combinedTypeFilter);
      await tester.tap(combinedTypeFilter);
      await tester.pump();
      expect(
        find.byKey(const Key('precise-ref-selector-item-other-ref')),
        findsNothing,
      );

      final item = find.byKey(
        const Key('precise-ref-selector-item-target-ref'),
      );
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pump();
      final confirm = find.byKey(const Key('precise-ref-selector-confirm'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result?.map((entry) => entry.id), ['target-ref']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width, surfaceKey) in [
    (700.0, 'adaptive-centered-form'),
    (1200.0, 'adaptive-side-sheet'),
  ]) {
    testWidgets('${width.toInt()}px selector uses a bounded adaptive surface', (
      tester,
    ) async {
      await _setViewport(tester, Size(width, 900));
      await _pumpSelectorHost(tester);

      await tester.tap(find.text('打开选择器'));
      await tester.pumpAndSettle();

      final surface = find.byKey(ValueKey(surfaceKey));
      expect(surface, findsOneWidget);
      expect(tester.getSize(surface).width, lessThan(width));
      expect(
        find.byKey(const Key('precise-ref-selector-search')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('precise-ref-selector-type-scroll')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    '320px 3x text with SafeArea and IME keeps the edit form scrollable and submittable',
    (tester) async {
      await _setViewport(
        tester,
        const Size(320, 720),
        padding: const FakeViewPadding(top: 24, bottom: 24),
        viewInsets: const FakeViewPadding(bottom: 220),
      );
      PreciseRefEntryEditResult? result;
      final entry = _PopulatedPreciseRefNotifier.entries.first;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await PreciseRefEntryEditDialog.show(context, entry);
                },
                child: const Text('打开编辑'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开编辑'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('precise-ref-edit-type-selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('precise-ref-edit-strength-field')),
        findsOneWidget,
      );
      expect(find.text('取消'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      final confirm = find.byKey(const Key('precise-ref-edit-confirm'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result?.name, entry.name);
      expect(result?.type, entry.type);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320px 3x text with SafeArea and IME keeps filtering and edit fields reachable',
    (tester) async {
      await _setViewport(
        tester,
        const Size(320, 720),
        padding: const FakeViewPadding(top: 24, bottom: 24),
        viewInsets: const FakeViewPadding(bottom: 220),
      );
      await _pumpLibrary(tester, textScale: 3);

      final search = find.byKey(const Key('precise-ref-library-search'));
      await tester.tap(search);
      await tester.enterText(search, '目标');
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('目标参考'), findsOneWidget);
      expect(
        find.byKey(const Key('precise-ref-library-import-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('precise-ref-type-filter-all')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _setViewport(
  WidgetTester tester,
  Size size, {
  FakeViewPadding? padding,
  FakeViewPadding? viewInsets,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding ?? const FakeViewPadding();
  tester.view.viewInsets = viewInsets ?? const FakeViewPadding();
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
  });
}

Future<void> _pumpSelectorHost(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preciseRefLibraryNotifierProvider.overrideWith(
          _PopulatedPreciseRefNotifier.new,
        ),
        preciseRefLibraryStorageServiceProvider.overrideWithValue(
          _ThumbnailFreeStorage(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => PreciseRefSelectorDialog.show(context),
              child: const Text('打开选择器'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpLibrary(WidgetTester tester, {double textScale = 1}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preciseRefLibraryNotifierProvider.overrideWith(
          _PopulatedPreciseRefNotifier.new,
        ),
        preciseRefLibraryStorageServiceProvider.overrideWithValue(
          _ThumbnailFreeStorage(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const InteractionPolicyScope(
          initialPolicy: InteractionPolicy(
            modality: InteractionModality.touch,
            touchAvailable: true,
            precisePointerAvailable: false,
          ),
          child: PreciseRefLibraryScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _PopulatedPreciseRefNotifier extends PreciseRefLibraryNotifier {
  static final entries = [
    PreciseRefLibraryEntry(
      id: 'target-ref',
      name: '目标参考',
      imagePath: 'target.png',
      typeIndex: PreciseRefType.characterAndStyle.index,
      isFavorite: true,
      createdAt: DateTime(2026),
    ),
    PreciseRefLibraryEntry(
      id: 'other-ref',
      name: '其他参考',
      imagePath: 'other.png',
      typeIndex: PreciseRefType.style.index,
      createdAt: DateTime(2026),
    ),
  ];

  @override
  PreciseRefLibraryState build() =>
      PreciseRefLibraryState(entries: entries, filteredEntries: entries);

  @override
  Future<void> initialize() async {}
}

class _ThumbnailFreeStorage extends PreciseRefLibraryStorageService {
  @override
  Uint8List? peekDisplayThumbnail(String id) => null;

  @override
  Future<Uint8List?> getDisplayThumbnail(
    String id, {
    bool Function()? isCancelled,
  }) async => null;
}
