import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_launcher/data/models/danbooru/danbooru_user.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/danbooru_login_dialog.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/blacklist_settings_panel.dart';

void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    GallerySourceId? sourceId,
    bool loggedIn = false,
    Size size = const Size(840, 760),
    List<String> tags = const [],
    List<String> legacyRemoteTags = const [],
    List<String> remoteRules = const [],
  }) async {
    final storage = _MemoryStorage()
      ..values[StorageKeys.onlineGalleryBlacklistAutoSync] = false
      ..values[StorageKeys.onlineGalleryBlacklistTags] = tags
      ..values[StorageKeys.onlineGalleryRemoteBlacklistTags] = legacyRemoteTags;
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        key: ValueKey(
          'blacklist-panel-$sourceId-$loggedIn-${tags.length}-${legacyRemoteTags.length}',
        ),
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          danbooruApiServiceProvider.overrideWithValue(
            _FakeDanbooruApiService(remoteRules),
          ),
          danbooruAuthProvider.overrideWith(
            () => _FakeDanbooruAuth(loggedIn: loggedIn),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OnlineGalleryBlacklistSettingsPanel(sourceId: sourceId),
              ),
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('unsupported sources show one local list and no cloud controls', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      sourceId: GallerySourceId.quickTagCloud,
      tags: const ['one', 'two'],
    );

    expect(find.text('本地名单'), findsNothing);
    expect(find.text('Danbooru 云端'), findsNothing);
    expect(find.text('拉取云端'), findsNothing);
    expect(find.text('推送到云端'), findsNothing);
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('global settings retain the Danbooru sync entry', (tester) async {
    await pumpPanel(tester);

    expect(find.text('本地黑名单仍然有效；登录 Danbooru 后可以同步'), findsOneWidget);
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.byType(DanbooruLoginDialog), findsOneWidget);
    expect(find.byType(OnlineGalleryBlacklistSettingsPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Danbooru cloud actions require a verified login', (
    tester,
  ) async {
    await pumpPanel(tester, sourceId: GallerySourceId.danbooru);

    expect(find.text('本地黑名单仍然有效；登录 Danbooru 后可以同步'), findsOneWidget);
    expect(find.text('拉取云端'), findsNothing);
    expect(find.text('推送到云端'), findsNothing);

    await pumpPanel(tester, sourceId: GallerySourceId.danbooru, loggedIn: true);

    expect(find.text('拉取云端'), findsOneWidget);
    expect(find.text('推送到云端'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty cloud replacement requires an extra confirmation', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      sourceId: GallerySourceId.danbooru,
      loggedIn: true,
      remoteRules: const ['remote_tag'],
    );

    await tester.tap(find.text('推送到云端'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final confirm = find.descendant(
      of: dialog,
      matching: find.widgetWithText(FilledButton, '推送到云端'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(
      find.descendant(of: dialog, matching: find.byType(Checkbox)),
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opaque-only cloud clearing requires extra confirmation', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      sourceId: GallerySourceId.danbooru,
      loggedIn: true,
      remoteRules: const ['furry -rating:g'],
    );

    await tester.tap(find.text('推送到云端'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    final confirm = find.descendant(
      of: dialog,
      matching: find.widgetWithText(FilledButton, '推送到云端'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(find.text('确认清空云端黑名单'), findsOneWidget);
  });

  testWidgets('migrated cloud data requires current-account confirmation', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      sourceId: GallerySourceId.danbooru,
      loggedIn: true,
      legacyRemoteTags: const ['unknown_account_tag'],
    );

    await tester.tap(find.text('推送到云端'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    final confirm = find.descendant(
      of: dialog,
      matching: find.widgetWithText(FilledButton, '推送到云端'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.textContaining('无法确认账号归属'));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
  });

  testWidgets('narrow Danbooru sync actions stack without overflow', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      sourceId: GallerySourceId.danbooru,
      loggedIn: true,
      size: const Size(420, 820),
    );

    final pull = tester.getRect(find.text('拉取云端'));
    final push = tester.getRect(find.text('推送到云端'));
    expect(push.top, greaterThan(pull.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large blacklist builds only visible rows without overflow', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      sourceId: GallerySourceId.quickTagCloud,
      size: const Size(700, 700),
      tags: [for (var index = 0; index < 5000; index++) 'tag_$index'],
    );

    expect(
      find.byKey(const ValueKey('online-gallery-blacklist-virtual-list')),
      findsOneWidget,
    );
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
  });
}

class _FakeDanbooruApiService extends DanbooruApiService {
  _FakeDanbooruApiService(this.rules) : super(Dio());

  List<String> rules;

  @override
  Future<List<String>> fetchBlacklistRules({CancelToken? cancelToken}) async =>
      List.of(rules);

  @override
  Future<void> updateBlacklistRules(
    List<String> rules, {
    CancelToken? cancelToken,
    int? expectedUserId,
  }) async {
    this.rules = List.of(rules);
  }
}

class _MemoryStorage extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] ?? defaultValue) as T?;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }

  @override
  Future<void> setSettings(Map<String, Object?> updates) async {
    values.addAll(updates);
  }
}

class _FakeDanbooruAuth extends DanbooruAuth {
  _FakeDanbooruAuth({required this.loggedIn});

  final bool loggedIn;

  @override
  DanbooruAuthState build() {
    if (!loggedIn) return const DanbooruAuthState();
    return DanbooruAuthState(
      credentials: const DanbooruCredentials(
        username: 'tester',
        apiKey: 'api-key',
      ),
      user: const DanbooruUser(id: 1, name: 'tester'),
      lastVerifiedAt: DateTime.now(),
    );
  }
}
