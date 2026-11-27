import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/theme_provider.dart';
import 'package:nai_launcher/presentation/themes/app_theme.dart';

import '../../helpers/memory_local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('all 16 theme presets declare accurate light/dark brightness support', (tester) async {
    for (final style in AppStyle.values) {
      final lightTheme = AppTheme.getTheme(style, Brightness.light);
      final darkTheme = AppTheme.getTheme(style, Brightness.dark);

      expect(
        style.supportsLightMode,
        lightTheme.brightness == Brightness.light,
        reason: '${style.name} light brightness mismatch',
      );
      expect(
        style.supportsDarkMode,
        darkTheme.brightness == Brightness.dark,
        reason: '${style.name} dark brightness mismatch',
      );
      expect(
        style.supportsLightMode || style.supportsDarkMode,
        isTrue,
        reason: '${style.name} must support at least one brightness',
      );
    }

    final lightStyles = AppTheme.stylesForBrightness(Brightness.light);
    final darkStyles = AppTheme.stylesForBrightness(Brightness.dark);

    expect(lightStyles, hasLength(11));
    expect(darkStyles, hasLength(12));
    expect(lightStyles.first, AppStyle.grungeCollage);
    expect(darkStyles.first, AppStyle.grungeCollage);
    expect(lightStyles.every((s) => s.supportsLightMode), isTrue);
    expect(darkStyles.every((s) => s.supportsDarkMode), isTrue);
  });

  test('defaults to dark mode with grungeCollage on both styles', () {
    final storage = _ThemeMemoryStorage();
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(themeNotifierProvider),
      const ThemeSettings(
        themeMode: ThemeMode.dark,
        lightStyle: AppStyle.grungeCollage,
        darkStyle: AppStyle.grungeCollage,
      ),
    );
  });

  group('legacy theme_type migration', () {
    test('migrates dark-only legacy style to dark mode with grunge light fallback', () {
      final storage = _ThemeMemoryStorage()
        ..values[StorageKeys.themeType] = AppStyle.neoDark.index;
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(themeNotifierProvider),
        const ThemeSettings(
          themeMode: ThemeMode.dark,
          lightStyle: AppStyle.grungeCollage,
          darkStyle: AppStyle.neoDark,
        ),
      );
    });

    test('migrates dual-mode legacy style to dark mode and preserves style for both', () {
      final storage = _ThemeMemoryStorage()
        ..values[StorageKeys.themeType] = AppStyle.materialYou.index;
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(themeNotifierProvider),
        const ThemeSettings(
          themeMode: ThemeMode.dark,
          lightStyle: AppStyle.materialYou,
          darkStyle: AppStyle.materialYou,
        ),
      );
    });

    test('migrates light-only legacy style to light mode without visual jump', () {
      final storage = _ThemeMemoryStorage()
        ..values[StorageKeys.themeType] = AppStyle.appleLight.index;
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(themeNotifierProvider),
        const ThemeSettings(
          themeMode: ThemeMode.light,
          lightStyle: AppStyle.appleLight,
          darkStyle: AppStyle.grungeCollage,
        ),
      );
    });
  });

  test('persists mode and per-brightness styles while ignoring unsupported styles', () async {
    final storage = _ThemeMemoryStorage();
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(themeNotifierProvider.notifier);

    await notifier.setLightStyle(AppStyle.appleLight);
    expect(container.read(themeNotifierProvider).lightStyle, AppStyle.appleLight);
    expect(storage.values[StorageKeys.lightThemeType], AppStyle.appleLight.index);
    expect(storage.values[StorageKeys.themeType], isNull);

    await notifier.setDarkStyle(AppStyle.neoDark);
    expect(container.read(themeNotifierProvider).darkStyle, AppStyle.neoDark);
    expect(storage.values[StorageKeys.darkThemeType], AppStyle.neoDark.index);
    expect(storage.values[StorageKeys.themeType], AppStyle.neoDark.index);

    await notifier.setLightStyle(AppStyle.neoDark);
    expect(container.read(themeNotifierProvider).lightStyle, AppStyle.appleLight);

    await notifier.setDarkStyle(AppStyle.appleLight);
    expect(container.read(themeNotifierProvider).darkStyle, AppStyle.neoDark);

    await notifier.setThemeMode(ThemeMode.light);
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.light);
    expect(storage.values[StorageKeys.themeMode], 'light');
    expect(storage.values[StorageKeys.themeType], AppStyle.appleLight.index);

    await notifier.setThemeMode(ThemeMode.system);
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.system);
    expect(storage.values[StorageKeys.themeMode], 'system');
    expect(storage.values[StorageKeys.themeType], AppStyle.neoDark.index);
  });

  test('toggleBrightness and nextStyle respect effective brightness including system mode', () async {
    final storage = _ThemeMemoryStorage();
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(themeNotifierProvider.notifier);

    await notifier.toggleBrightness(Brightness.dark);
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.light);

    await notifier.toggleBrightness(Brightness.light);
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.dark);

    await notifier.setThemeMode(ThemeMode.system);
    await notifier.toggleBrightness(Brightness.light);
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.dark);

    await notifier.setThemeMode(ThemeMode.system);
    await notifier.toggleBrightness(Brightness.dark);
    expect(container.read(themeNotifierProvider).themeMode, ThemeMode.light);

    await notifier.setThemeMode(ThemeMode.system);
    await notifier.nextStyle(Brightness.light);
    final lightStyles = AppTheme.stylesForBrightness(Brightness.light);
    expect(container.read(themeNotifierProvider).lightStyle, lightStyles[1]);
    expect(container.read(themeNotifierProvider).darkStyle, AppStyle.grungeCollage);

    await notifier.nextStyle(Brightness.dark);
    final darkStyles = AppTheme.stylesForBrightness(Brightness.dark);
    expect(container.read(themeNotifierProvider).darkStyle, darkStyles[1]);
  });

  testWidgets('MaterialApp follows system brightness using separate light and dark styles', (tester) async {
    final storage = _ThemeMemoryStorage();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
        child: Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(themeNotifierProvider);
            return MaterialApp(
              theme: AppTheme.getTheme(settings.lightStyle, Brightness.light),
              darkTheme: AppTheme.getTheme(settings.darkStyle, Brightness.dark),
              themeMode: settings.themeMode,
              home: Scaffold(
                body: Builder(
                  builder: (innerContext) => Text(
                    Theme.of(innerContext).brightness.name,
                    key: const Key('active-brightness'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('active-brightness'))),
    );
    final notifier = container.read(themeNotifierProvider.notifier);
    await notifier.setLightStyle(AppStyle.appleLight);
    await notifier.setDarkStyle(AppStyle.neoDark);
    await notifier.setThemeMode(ThemeMode.system);
    await tester.pumpAndSettle();

    final lightContext = tester.element(find.byKey(const Key('active-brightness')));
    expect(Theme.of(lightContext).brightness, Brightness.light);
    expect(
      Theme.of(lightContext).colorScheme.primary,
      AppTheme.getTheme(AppStyle.appleLight, Brightness.light).colorScheme.primary,
    );

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();

    final darkContext = tester.element(find.byKey(const Key('active-brightness')));
    expect(Theme.of(darkContext).brightness, Brightness.dark);
    expect(
      Theme.of(darkContext).colorScheme.primary,
      AppTheme.getTheme(AppStyle.neoDark, Brightness.dark).colorScheme.primary,
    );
  });
}

class _ThemeMemoryStorage extends MemoryLocalStorage {
  @override
  int getThemeIndex() => getSetting<int>(StorageKeys.themeType, defaultValue: 0) ?? 0;

  @override
  Future<void> setThemeIndex(int index) => setSetting(StorageKeys.themeType, index);
}
