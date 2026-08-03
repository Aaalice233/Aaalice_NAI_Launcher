import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/gelbooru_api_service.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/models/online_gallery/gelbooru_credentials.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/widgets/gelbooru_credentials_dialog.dart';

void main() {
  testWidgets('validates positive User ID and non-empty API Key', (
    tester,
  ) async {
    final storage = _FakeSecureStorage();
    await tester.pumpWidget(_testApp(storage: storage));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'User ID *'),
      '0',
    );
    await tester.tap(find.text('Verify and Save'));
    await tester.pump();

    expect(find.text('Enter a valid positive numeric User ID'), findsOneWidget);
    expect(find.text('Enter an API Key'), findsOneWidget);
    expect(storage.gelbooru, isNull);
  });

  testWidgets('masks, verifies, and saves Gelbooru credentials', (
    tester,
  ) async {
    final storage = _FakeSecureStorage();
    final api = _FakeGelbooruApiService();
    await tester.pumpWidget(_testApp(storage: storage, api: api));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'User ID *'),
      '24680',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'API Key *'),
      'secret-key',
    );
    await tester.tap(find.text('Verify and Save'));
    await tester.pumpAndSettle();

    expect(api.lastVerified?.userId, 24680);
    expect(storage.gelbooru, contains('secret-key'));
    await tester.pump(const Duration(seconds: 4));
  });
}

Widget _testApp({
  required _FakeSecureStorage storage,
  _FakeGelbooruApiService? api,
}) {
  return ProviderScope(
    overrides: [
      secureStorageServiceProvider.overrideWithValue(storage),
      gelbooruApiServiceProvider.overrideWithValue(
        api ?? _FakeGelbooruApiService(),
      ),
      onlineGalleryNotifierProvider.overrideWith(
        _FakeOnlineGalleryNotifier.new,
      ),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GelbooruCredentialsDialog(),
    ),
  );
}

class _FakeSecureStorage extends SecureStorageService {
  String? gelbooru;

  @override
  Future<String?> getGelbooruCredentials() async => gelbooru;

  @override
  Future<void> saveGelbooruCredentials(String credentialsJson) async {
    gelbooru = credentialsJson;
  }

  @override
  Future<void> deleteGelbooruCredentials() async {
    gelbooru = null;
  }
}

class _FakeGelbooruApiService extends GelbooruApiService {
  _FakeGelbooruApiService() : super(Dio());

  GelbooruCredentials? lastVerified;

  @override
  Future<void> verifyCredentials(GelbooruCredentials credentials) async {
    lastVerified = credentials;
  }
}

class _FakeOnlineGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() => const OnlineGalleryState(
    searchCache: ModeCache(
      posts: [
        DanbooruPost(
          id: 1,
          previewFileUrl: 'https://cdn.donmai.us/preview.jpg',
        ),
      ],
      hasMore: false,
    ),
  );

  @override
  Future<void> refresh() async {}
}
