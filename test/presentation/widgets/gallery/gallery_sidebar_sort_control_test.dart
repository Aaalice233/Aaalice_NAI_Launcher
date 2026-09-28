import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/library_sidebar_sort_provider.dart';
import 'package:nai_launcher/presentation/utils/library_sidebar_sort.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_sidebar.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_sidebar_sort_control.dart';

void main() {
  testWidgets(
    'mouse hover paints feedback above header and shows current mode',
    (tester) async {
      const captureKey = ValueKey('sort-paint');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(_Storage()),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 240,
                  child: GallerySidebarSectionHeader(
                    toggleKey: const ValueKey('hover-section'),
                    icon: Icons.category_outlined,
                    title: '分类',
                    isExpanded: true,
                    onToggle: () {},
                    onCreate: () {},
                    trailing: const RepaintBoundary(
                      key: captureKey,
                      child: GallerySidebarSortControl(
                        section: LibrarySidebarSection.vibeCategories,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<List<int>?> pixels() => tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final result = bytes!.buffer.asUint8List().toList();
        image.dispose();
        return result;
      });
      final before = await pixels();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byKey(captureKey)));
      await tester.pumpAndSettle();
      final after = await pixels();
      expect(
        listEquals(before, after),
        isFalse,
        reason: 'The button itself must paint a visible hover state',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('排序方式: 原有顺序'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('sidebar-sort-vibeCategories')),
      );
      await tester.pumpAndSettle();
      expect(
        find
            .byKey(const ValueKey('sidebar-sort-option-nameAscending'))
            .hitTestable(),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('sidebar-sort-option-original')),
      );
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [200.0, 220.0, 240.0, 250.0, 320.0]) {
    testWidgets('$width sidebar keeps the category title on one line', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(_Storage()),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: GallerySidebarSectionHeader(
                    toggleKey: const ValueKey('category-header'),
                    icon: Icons.category_outlined,
                    title: '分类',
                    isExpanded: true,
                    onToggle: () {},
                    onCreate: () {},
                    trailing: const GallerySidebarSortControl(
                      section: LibrarySidebarSection.vibeCategories,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = tester.getRect(find.text('分类'));
      final create = tester.getRect(find.byTooltip('新建'));
      final sort = tester.getRect(
        find.byKey(const ValueKey('sidebar-sort-vibeCategories')),
      );
      expect(title.height, lessThan(28));
      expect(title.center.dy, closeTo(create.center.dy, 1));
      expect(sort.center.dy, closeTo(title.center.dy, 1));
      expect(
        tester.getSize(find.byKey(const ValueKey('category-header'))).height,
        lessThanOrEqualTo(56),
      );
      expect(find.byTooltip('新建').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sidebar-sort-vibeCategories')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final locale in [const Locale('zh'), const Locale('en')]) {
      testWidgets(
        '$width / $locale / 3x keeps the group and every action reachable',
        (tester) async {
          final storage = _Storage();
          var creates = 0;
          var toggles = 0;
          await tester.binding.setSurfaceSize(Size(width, 500));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                localStorageServiceProvider.overrideWithValue(storage),
              ],
              child: MaterialApp(
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(3),
                    padding: const EdgeInsets.only(top: 24, bottom: 24),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: math.min(width, 250),
                        child: SingleChildScrollView(
                          child: Builder(
                            builder: (context) => GallerySidebarSectionHeader(
                              toggleKey: const ValueKey('section'),
                              icon: Icons.folder_outlined,
                              title: locale.languageCode == 'zh'
                                  ? '文件夹'
                                  : 'Folders',
                              isExpanded: true,
                              onToggle: () => toggles++,
                              onCreate: () => creates++,
                              trailing: const GallerySidebarSortControl(
                                section: LibrarySidebarSection.folders,
                              ),
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
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.text(locale.languageCode == 'zh' ? '文件夹' : 'Folders'),
          );
          expect(toggles, 1);
          await tester.tap(find.byIcon(Icons.add));
          expect(creates, 1);
          await tester.tap(find.byKey(const ValueKey('sidebar-sort-folders')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final sort in LibrarySidebarSort.values) {
            final option = find.byKey(
              ValueKey('sidebar-sort-option-${sort.name}'),
            );
            await tester.ensureVisible(option);
            await tester.pumpAndSettle();
            expect(option.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.tap(
            find.byKey(const ValueKey('sidebar-sort-option-countAscending')),
          );
          await tester.pumpAndSettle();
          expect(
            storage.values[LibrarySidebarSection.folders.storageKey],
            LibrarySidebarSort.countAscending.name,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _Storage extends LocalStorageService {
  final values = <String, Object?>{};
  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] ?? defaultValue) as T?;
  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
