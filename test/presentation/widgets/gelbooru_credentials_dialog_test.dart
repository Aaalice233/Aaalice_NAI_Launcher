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

  for (final width in [320.0, 1600.0]) {
    testWidgets('form stays scrollable with IME and 3x text at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);
      final storage = _FakeSecureStorage();
      await tester.pumpWidget(
        _testApp(
          storage: storage,
          textScaler: const TextScaler.linear(3),
          viewInsets: const EdgeInsets.only(bottom: 280),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byType(GelbooruCredentialsDialog),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(scrollable, findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Verify and Save'),
        120,
        scrollable: scrollable,
      );
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump();
      expect(
        tester
            .getRect(find.widgetWithText(FilledButton, 'Verify and Save'))
            .bottom,
        lessThanOrEqualTo(900),
      );
      tester.state<FormState>(find.byType(Form)).validate();
      await tester.pump();
      expect(
        tester
            .widgetList<InputDecorator>(find.byType(InputDecorator))
            .where((input) => input.decoration.errorText != null),
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
    });
  }

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
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewInsets = EdgeInsets.zero,
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
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: textScaler, viewInsets: viewInsets),
        child: child!,
      ),
      home: const GelbooruCredentialsDialog(),
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
