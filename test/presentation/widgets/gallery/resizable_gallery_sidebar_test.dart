import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_sidebar.dart';

const _pane = ValueKey('gallery-resizable-sidebar');
const _handle = ValueKey('gallery-sidebar-resize-handle');
const _storageKey = StorageKeys.localGallerySidebarWidth;

Color _handleBackground(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find
          .ancestor(of: find.byKey(_handle), matching: find.byType(ColoredBox))
          .first,
    )
    .color;

void main() {
  for (final storageKey in [
    StorageKeys.localGallerySidebarWidth,
    StorageKeys.vibeLibrarySidebarWidth,
    StorageKeys.preciseRefSidebarWidth,
    StorageKeys.tagLibrarySidebarWidth,
  ]) {
    for (final cancel in [false, true]) {
      testWidgets(
        '$storageKey clears pointer focus highlight (cancel: $cancel)',
        (tester) async {
          final storage = _Storage();
          await tester.binding.setSurfaceSize(const Size(1180, 700));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(_app(storage, storageKey: storageKey));
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(_handleBackground(tester), isNot(Colors.transparent));
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(_handle)),
            kind: PointerDeviceKind.mouse,
          );
          await gesture.moveBy(const Offset(40, 0));
          await tester.pump();
          await gesture.moveBy(const Offset(20, 0));
          await tester.pump();
          if (cancel) {
            await gesture.cancel();
          } else {
            await gesture.up();
          }
          await tester.pumpAndSettle();
          expect(_handleBackground(tester), Colors.transparent);
          final width = tester.getSize(find.byKey(_pane)).width;
          expect(width, greaterThan(250));
          expect(storage.values[storageKey], width);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();
          expect(tester.getSize(find.byKey(_pane)).width, width - 16);
          expect(_handleBackground(tester), isNot(Colors.transparent));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'drag relayouts stable children and persists only after release',
    (tester) async {
      final storage = _Storage();
      var sidebarBuilds = 0;
      var bodyBuilds = 0;
      final scroll = ScrollController(initialScrollOffset: 160);
      addTearDown(scroll.dispose);
      await tester.binding.setSurfaceSize(const Size(1180, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          storage,
          sidebar: _BuildCounter(
            onBuild: () => sidebarBuilds++,
            child: GallerySidebarSurface(
              child: ListView.builder(
                controller: scroll,
                itemExtent: 48,
                itemCount: 80,
                itemBuilder: (_, i) => Text('Folder $i'),
              ),
            ),
          ),
          body: _BuildCounter(
            onBuild: () => bodyBuilds++,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(_pane)).width, 250);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_handle)),
      );
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump();
      final initialSidebarBuilds = sidebarBuilds;
      final initialBodyBuilds = bodyBuilds;
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump();
        expect(sidebarBuilds, initialSidebarBuilds);
        expect(bodyBuilds, initialBodyBuilds);
        expect(storage.writes, 0);
      }
      final width = tester.getSize(find.byKey(_pane)).width;
      expect(width, greaterThan(330));
      expect(scroll.offset, 160);
      await gesture.up();
      await tester.pump();
      expect(storage.writes, 1);
      expect(storage.values[_storageKey], width);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(storage));
      expect(tester.getSize(find.byKey(_pane)).width, width);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('temporary constraints do not overwrite the saved preference', (
    tester,
  ) async {
    final storage = _Storage()..values[_storageKey] = 480.0;
    await tester.binding.setSurfaceSize(const Size(1180, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(storage));
    expect(tester.getSize(find.byKey(_pane)).width, 480);
    await tester.binding.setSurfaceSize(const Size(840, 700));
    await tester.pump();
    expect(tester.getSize(find.byKey(_pane)).width, lessThanOrEqualTo(480));
    await tester.binding.setSurfaceSize(const Size(1180, 700));
    await tester.pump();
    expect(tester.getSize(find.byKey(_pane)).width, 480);
    expect(storage.writes, 0);
  });

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets('$width wide with 3x text respects content bounds', (
      tester,
    ) async {
      final storage = _Storage()..values[_storageKey] = 900.0;
      await tester.binding.setSurfaceSize(Size(width, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(storage, textScale: 3, touch: true));
      if (width >= 840) {
        expect(
          tester.getSize(find.byKey(const ValueKey('body'))).width,
          greaterThanOrEqualTo(320),
        );
        expect(
          tester.getSize(find.byKey(_handle)).width,
          greaterThanOrEqualTo(44),
        );
      } else {
        expect(find.byKey(_handle), findsNothing);
      }
      expect(storage.writes, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'keyboard adjusts and resets width; pages keep independent values',
    (tester) async {
      final storage = _Storage()
        ..values[StorageKeys.vibeLibrarySidebarWidth] = 420.0;
      await tester.binding.setSurfaceSize(const Size(1180, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(storage));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(tester.getSize(find.byKey(_pane)).width, 266);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(tester.getSize(find.byKey(_pane)).width, 250);
      expect(storage.values[StorageKeys.vibeLibrarySidebarWidth], 420);
    },
  );

  test(
    'sidebar widths are neither exported nor accepted from cloud snapshots',
    () async {
      final storage = _Storage();
      final adapter = SettingsCloudSyncAdapter(storage);
      for (final key in [
        StorageKeys.localGallerySidebarWidth,
        StorageKeys.vibeLibrarySidebarWidth,
        StorageKeys.preciseRefSidebarWidth,
        StorageKeys.tagLibrarySidebarWidth,
      ]) {
        storage.values[key] = 360.0;
        expect(adapter.exportedKeys, isNot(contains(key)));
        expect(
          () => adapter.validateRecord(
            PortableSyncRecord(
              adapterId: adapter.id,
              id: key,
              kind: 'setting',
              data: {'key': key, 'value': 900.0},
            ),
          ),
          throwsA(isA<CloudSyncPreflightException>()),
        );
      }
      expect(await adapter.exportRecords().toList(), isEmpty);
    },
  );
}

Widget _app(
  _Storage storage, {
  Widget? sidebar,
  Widget? body,
  double textScale = 1,
  bool touch = false,
  String storageKey = _storageKey,
}) => ProviderScope(
  overrides: [localStorageServiceProvider.overrideWithValue(storage)],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: InteractionPolicyScope(
        initialPolicy: InteractionPolicy(
          modality: touch
              ? InteractionModality.touch
              : InteractionModality.pointer,
          touchAvailable: touch,
          precisePointerAvailable: !touch,
        ),
        child: child!,
      ),
    ),
    home: Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => GalleryCollectionWorkspace(
          sidebarWidthKey: storageKey,
          toolbar: const SizedBox(height: 72),
          sidebar: constraints.maxWidth >= 840
              ? sidebar ?? const GallerySidebarSurface(child: SizedBox.expand())
              : null,
          body: SizedBox(
            key: const ValueKey('body'),
            child: body ?? const SizedBox.expand(),
          ),
        ),
      ),
    ),
  ),
);

class _Storage extends LocalStorageService {
  final values = <String, Object?>{};
  int writes = 0;
  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] ?? defaultValue) as T?;
  @override
  Future<void> setSetting<T>(String key, T value) async {
    writes++;
    values[key] = value;
  }
}

class _BuildCounter extends StatelessWidget {
  const _BuildCounter({required this.onBuild, required this.child});
  final VoidCallback onBuild;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}
