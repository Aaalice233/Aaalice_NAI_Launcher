import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_output_filter_provider.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/output_filter_settings_panel.dart';

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
