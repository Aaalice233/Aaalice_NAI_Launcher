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
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/danbooru_login_dialog.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/blacklist_settings_panel.dart';

void main() {
  Future<_FakeDanbooruApiService> pumpPanel(
    WidgetTester tester, {
    GallerySourceId? sourceId,
    bool loggedIn = false,
    Size size = const Size(840, 760),
    double textScale = 1,
    List<String> tags = const [],
    List<String> legacyRemoteTags = const [],
    List<String> remoteRules = const [],
    InteractionPolicy? interactionPolicy,
  }) async {
    final storage = _MemoryStorage()
      ..values[StorageKeys.onlineGalleryBlacklistAutoSync] = false
      ..values[StorageKeys.onlineGalleryBlacklistTags] = tags
      ..values[StorageKeys.onlineGalleryRemoteBlacklistTags] = legacyRemoteTags;
    final apiService = _FakeDanbooruApiService(remoteRules);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        key: ValueKey(
          'blacklist-panel-$sourceId-$loggedIn-${tags.length}-${legacyRemoteTags.length}-$interactionPolicy',
        ),
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          danbooruApiServiceProvider.overrideWithValue(apiService),
          danbooruAuthProvider.overrideWith(
            () => _FakeDanbooruAuth(loggedIn: loggedIn),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: InteractionPolicyScope(
            initialPolicy: interactionPolicy,
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OnlineGalleryBlacklistSettingsPanel(
                    sourceId: sourceId,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    return apiService;
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
    expect(find.byType(Dialog), findsNothing);
    final login = tester.widget<DanbooruLoginDialog>(
      find.byType(DanbooruLoginDialog),
    );
    expect(login.embedded, isTrue);
    expect(login.scrollController, isNotNull);
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
    final review = find.byKey(
      const ValueKey('online-gallery-blacklist-push-review-scroll'),
    );
    expect(review, findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    final confirm = find.byKey(
      const ValueKey('online-gallery-blacklist-push-review-submit'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(
      find.descendant(of: review, matching: find.byType(Checkbox)),
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
    expect(
      find.byKey(const ValueKey('online-gallery-blacklist-push-review-scroll')),
      findsOneWidget,
    );
    final confirm = find.byKey(
      const ValueKey('online-gallery-blacklist-push-review-submit'),
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
    expect(
      find.byKey(const ValueKey('online-gallery-blacklist-push-review-scroll')),
      findsOneWidget,
    );
    final confirm = find.byKey(
      const ValueKey('online-gallery-blacklist-push-review-submit'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.textContaining('无法确认账号归属'));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
  });

  testWidgets(
    'worst-case cloud review keeps both gates reachable in a short viewport',
    (tester) async {
      final apiService = await pumpPanel(
        tester,
        sourceId: GallerySourceId.danbooru,
        loggedIn: true,
        size: const Size(320, 480),
        textScale: 2,
        legacyRemoteTags: const ['unknown_account_tag'],
        remoteRules: const ['furry -rating:g'],
      );

      await tester.ensureVisible(find.text('清除'));
      await tester.tap(find.text('清除'));
      await tester.pumpAndSettle();
      final clearDialog = find.byType(AlertDialog);
      expect(clearDialog, findsOneWidget);
      await tester.tap(
        find.descendant(
          of: clearDialog,
          matching: find.widgetWithText(FilledButton, '清除'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('推送到云端'));
      await tester.tap(find.text('推送到云端'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final review = find.byKey(
        const ValueKey('online-gallery-blacklist-push-review-scroll'),
      );
      expect(review, findsOneWidget);
      final checkboxes = find.descendant(
        of: review,
        matching: find.byType(Checkbox),
      );
      expect(checkboxes, findsNWidgets(2));
      final confirm = find.byKey(
        const ValueKey('online-gallery-blacklist-push-review-submit'),
      );
      expect(confirm.hitTestable(), findsOneWidget);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      for (var index = 0; index < 2; index++) {
        final checkbox = checkboxes.at(index);
        await tester.ensureVisible(checkbox);
        await tester.pump();
        await tester.tap(checkbox);
        await tester.pump();
      }
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(review, findsNothing);
      expect(apiService.rules, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets('320 wide large-text panel keeps every local action reachable', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      sourceId: GallerySourceId.quickTagCloud,
      size: const Size(320, 480),
      textScale: 2,
      tags: const ['one'],
    );

    expect(find.text('导入'), findsOneWidget);
    expect(find.text('清除'), findsOneWidget);
    await tester.ensureVisible(find.text('清除'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('blacklist dialog stays in a short 360 viewport', (tester) async {
    final storage = _MemoryStorage()
      ..values[StorageKeys.onlineGalleryBlacklistAutoSync] = false
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['one'];
    tester.view.physicalSize = const Size(360, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: FilledButton(
                onPressed: () => showOnlineGalleryBlacklistDialog(
                  context,
                  ref,
                  sourceId: GallerySourceId.quickTagCloud,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-full-screen-form'));
    final surfaceRect = tester.getRect(surface);
    expect(find.byType(AlertDialog), findsNothing);
    expect(surfaceRect.left, greaterThanOrEqualTo(0));
    expect(surfaceRect.top, greaterThanOrEqualTo(0));
    expect(surfaceRect.right, lessThanOrEqualTo(360));
    expect(surfaceRect.bottom, lessThanOrEqualTo(420));
    expect(
      find.byKey(const ValueKey('online-gallery-blacklist-form-scroll')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('导入'));
    await tester.pump();
    expect(find.text('导入'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact large-text import stays reachable with keyboard and preserves tags',
    (tester) async {
      final storage = _MemoryStorage()
        ..values[StorageKeys.onlineGalleryBlacklistAutoSync] = false
        ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>['one'];
      tester.view.physicalSize = const Size(320, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageServiceProvider.overrideWithValue(storage)],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 160),
              ),
              child: child!,
            ),
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: FilledButton(
                  onPressed: () => showOnlineGalleryBlacklistDialog(
                    context,
                    ref,
                    sourceId: GallerySourceId.quickTagCloud,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('导入'));
      await tester.pump();
      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();

      final importScroll = find.byKey(
        const ValueKey('online-gallery-blacklist-import-scroll'),
      );
      expect(importScroll, findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final input = find.descendant(
        of: importScroll,
        matching: find.byType(TextField),
      );
      await tester.enterText(input, 'two\nthree');
      final importAction = find.byKey(
        const ValueKey('online-gallery-blacklist-import-submit'),
      );
      expect(importAction.hitTestable(), findsOneWidget);
      await tester.tap(importAction);
      await tester.pumpAndSettle();

      expect(importScroll, findsNothing);
      expect(
        storage.values[StorageKeys.onlineGalleryBlacklistTags],
        containsAll(<String>['one', 'two', 'three']),
      );
      expect(
        (storage.values[StorageKeys.onlineGalleryBlacklistTags] as List).length,
        3,
      );
      expect(find.text('one'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('blacklist form is bounded on expanded width', (tester) async {
    final storage = _MemoryStorage()
      ..values[StorageKeys.onlineGalleryBlacklistAutoSync] = false
      ..values[StorageKeys.onlineGalleryBlacklistTags] = <String>[];
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: FilledButton(
                onPressed: () => showOnlineGalleryBlacklistDialog(
                  context,
                  ref,
                  sourceId: GallerySourceId.quickTagCloud,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-side-sheet'));
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface).width, lessThanOrEqualTo(728));
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blacklist rows and delete actions follow input hit targets', (
    tester,
  ) async {
    const tag = 'touch_target';
    await pumpPanel(
      tester,
      sourceId: GallerySourceId.quickTagCloud,
      tags: const [tag],
      interactionPolicy: InteractionPolicy.touchFirst,
    );

    final item = find.byKey(
      const ValueKey('online-gallery-blacklist-item-$tag'),
    );
    final delete = find.byKey(
      const ValueKey('online-gallery-blacklist-delete-$tag'),
    );
    expect(tester.getSize(item).height, 48);
    expect(tester.getSize(delete), const Size.square(48));

    await pumpPanel(
      tester,
      sourceId: GallerySourceId.quickTagCloud,
      tags: const [tag],
      interactionPolicy: const InteractionPolicy(
        modality: InteractionModality.pointer,
        touchAvailable: false,
        precisePointerAvailable: true,
      ),
    );

    expect(tester.getSize(item).height, 40);
    expect(tester.getSize(delete).height, 40);
    expect(tester.getSize(delete).width, lessThanOrEqualTo(48));
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
