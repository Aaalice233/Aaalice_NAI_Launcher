import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/proxy_settings_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/network_settings_section.dart';

void main() {
  testWidgets(
    'proxy settings disclose that authenticated API traffic uses the configured proxy',
    (tester) async {
      final storage = _MemoryLocalStorageService({
        StorageKeys.proxyEnabled: true,
        StorageKeys.proxyMode: 'manual',
        StorageKeys.proxyManualHost: '127.0.0.1',
        StorageKeys.proxyManualPort: 7890,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
            detectedSystemProxyProvider.overrideWith((ref) => null),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: NetworkSettingsSection()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('127.0.0.1:7890'), findsWidgets);
      expect(find.textContaining('认证请求'), findsOneWidget);
      expect(find.textContaining('系统代理或手动代理'), findsOneWidget);
    },
  );
}

class _MemoryLocalStorageService extends LocalStorageService {
  _MemoryLocalStorageService(this.values);

  final Map<String, Object?> values;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return values.containsKey(key) ? values[key] as T? : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    values.remove(key);
  }
}
