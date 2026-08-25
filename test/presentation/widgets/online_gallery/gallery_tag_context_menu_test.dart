import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/gallery_tag_context_menu.dart';

void main() {
  testWidgets(
    'failed blacklist persistence does not report a completed action',
    (tester) async {
      OnlineGalleryTagContextAction? result =
          OnlineGalleryTagContextAction.copy;
      var completed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(_FailingStorage()),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await showOnlineGalleryTagContextMenu(
                        context: context,
                        ref: ref,
                        tag: 'blocked_tag',
                        globalPosition: const Offset(100, 100),
                      );
                      completed = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('加入黑名单'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );
}

class _FailingStorage extends LocalStorageService {
  @override
  T? getSetting<T>(String key, {T? defaultValue}) => defaultValue;

  @override
  Future<void> setSettings(Map<String, Object?> updates) async {
    throw StateError('disk full');
  }
}
