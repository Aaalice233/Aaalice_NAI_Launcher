import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_output_filter_provider.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/output_filter_settings_panel.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/gallery_tag_rules_editor.dart';

void main() {
  testWidgets('adds multiple output filter tags from one input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryOutputFilterTags] = <String>[];
    late ProviderContainer container;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 720,
                    child: OnlineGalleryOutputFilterSettingsPanel(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    final inputTop = tester.getTopLeft(find.byType(TextField)).dy;
    final addIconCenter = tester.getCenter(find.byIcon(Icons.add)).dy;
    expect(addIconCenter - inputTop, moreOrLessEquals(24));
    expect(find.byType(GalleryTagRulesHeader), findsOneWidget);
    expect(find.byType(GalleryTagRulesInput), findsOneWidget);
    expect(find.byType(GalleryTagRulesList), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Custom Tag，watermark');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(container.read(onlineGalleryOutputFilterProvider).tags, {
      'custom_tag',
      'watermark',
    });
    expect(find.text('Custom Tag', skipOffstage: false), findsNothing);
    expect(find.text('custom tag'), findsOneWidget);
    expect(find.text('watermark'), findsOneWidget);
  });

  testWidgets('output filter dialog fits 320 large-text and short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryOutputFilterTags] = <String>[
        'watermark',
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showOnlineGalleryOutputFilterDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    final surfaceRect = tester.getRect(surface);
    expect(find.byType(AlertDialog), findsNothing);
    expect(surfaceRect.left, greaterThanOrEqualTo(0));
    expect(surfaceRect.top, greaterThanOrEqualTo(0));
    expect(surfaceRect.right, lessThanOrEqualTo(320));
    expect(surfaceRect.bottom, lessThanOrEqualTo(420));
    expect(
      find.byKey(const ValueKey('online-gallery-output-filter-form-scroll')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Restore defaults'));
    await tester.pump();
    expect(find.text('Clear'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('output filter form is bounded on expanded width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _FakeStorage()
      ..values[StorageKeys.onlineGalleryOutputFilterTags] = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showOnlineGalleryOutputFilterDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface).width, lessThanOrEqualTo(768));
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeStorage extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return (values[key] ?? defaultValue) as T?;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
