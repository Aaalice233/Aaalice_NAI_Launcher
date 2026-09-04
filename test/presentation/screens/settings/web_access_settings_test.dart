import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/network/web_access/web_access_models.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/web_access_settings.dart';

void main() {
  testWidgets('reveals backend settings after web access is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: 480, child: WebAccessSettings()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agent Web Access'), findsOneWidget);
    expect(find.text('Search backend'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Search backend'), findsOneWidget);
    expect(find.text('SearXNG Base URL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('API key dialog stays usable on narrow screen with IME', (
    tester,
  ) async {
    final secureStorage = _MemorySecureStorage();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.padding = const FakeViewPadding(
      left: 8,
      top: 24,
      right: 8,
      bottom: 16,
    );
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            _MemoryLocalStorage(initialMode: WebSearchMode.exaApi),
          ),
          secureStorageServiceProvider.overrideWithValue(secureStorage),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(3),
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 16),
              viewPadding: const EdgeInsets.fromLTRB(8, 24, 8, 16),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: WebAccessSettings(showEnableControl: false, enabled: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Configure'));
    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(panel, findsOneWidget);
    expect(find.text('Exa API Key'), findsWidgets);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.byType(Wrap), findsWidgets);
    final editor = find.descendant(of: panel, matching: find.byType(TextField));
    await tester.enterText(editor, 'reachable-key');
    await tester.ensureVisible(find.text('Save'));
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    final panelRect = tester.getRect(panel);
    expect(panelRect.left, greaterThanOrEqualTo(8));
    expect(panelRect.top, greaterThanOrEqualTo(24));
    expect(panelRect.right, lessThanOrEqualTo(312));
    expect(panelRect.bottom, lessThanOrEqualTo(388));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(secureStorage.key, 'reachable-key');
    expect(panel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('API key 编辑器保留保存、空值不改动与清除语义', (tester) async {
    final secureStorage = _MemorySecureStorage(initialKey: 'existing-key');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            _MemoryLocalStorage(initialMode: WebSearchMode.exaApi),
          ),
          secureStorageServiceProvider.overrideWithValue(secureStorage),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: WebAccessSettings(showEnableControl: false, enabled: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> openEditor() async {
      await tester.tap(find.text('Configure'));
      await tester.pumpAndSettle();
    }

    await openEditor();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(secureStorage.key, 'existing-key');

    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    final editor = find.descendant(of: panel, matching: find.byType(TextField));
    await tester.enterText(editor, '  replacement-key  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(secureStorage.key, 'replacement-key');

    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear key'));
    await tester.pumpAndSettle();
    expect(secureStorage.key, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('can use Agent settings as the authoritative enable control', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(_MemoryLocalStorage()),
          secureStorageServiceProvider.overrideWithValue(
            _MemorySecureStorage(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: WebAccessSettings(
                  showEnableControl: false,
                  enabled: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agent Web Access'), findsNothing);
    expect(find.text('Search backend'), findsOneWidget);
    expect(find.text('SearXNG Base URL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryLocalStorage extends LocalStorageService {
  _MemoryLocalStorage({WebSearchMode? initialMode}) {
    if (initialMode != null) {
      _values[StorageKeys.agentWebAccessConfigJson] = WebAccessConfig(
        mode: initialMode,
      ).encode();
    }
  }

  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    return value == null ? defaultValue : value as T;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }
}

class _MemorySecureStorage extends SecureStorageService {
  _MemorySecureStorage({String? initialKey}) : key = initialKey;

  String? key;

  @override
  Future<String?> getAgentWebAccessExaApiKey() async => key;

  @override
  Future<void> saveAgentWebAccessExaApiKey(String apiKey) async {
    final value = apiKey.trim();
    key = value.isEmpty ? null : value;
  }

  @override
  Future<void> deleteAgentWebAccessExaApiKey() async {
    key = null;
  }
}
