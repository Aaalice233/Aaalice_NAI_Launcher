import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/online_gallery_detail_coordinator.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/quick_tag_cloud_gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/artist_chain.dart';
import 'package:nai_launcher/data/models/online_gallery/danbooru_post.dart';
import 'package:nai_launcher/data/models/online_gallery/gelbooru_credentials.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
import 'package:nai_launcher/data/services/gelbooru_auth_service.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_remote_catalog_service.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_user_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/danbooru_suggestion_provider.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/quick_tag_cloud_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_screen.dart';
import 'package:nai_launcher/presentation/widgets/app_branch_visibility.dart';
import 'package:nai_launcher/presentation/widgets/danbooru_post_card.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  for (final width in [360.0, 700.0, 840.0, 1180.0, 1600.0]) {
    testWidgets('Gelbooru search uses its API account entry at width $width', (
      tester,
    ) async {
      await _setViewSize(tester, width);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineGalleryNotifierProvider.overrideWith(
              _GelbooruSearchGalleryNotifier.new,
            ),
            danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
            gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
            danbooruSuggestionNotifierProvider.overrideWith(
              _EmptyDanbooruSuggestionNotifier.new,
            ),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pump();

      expect(
        _selectedModeColor(tester, 'online-gallery-mode-search'),
        const Color(0xFF2563EB),
      );
      final avatar = find.byKey(
        const ValueKey('online-gallery-account-avatar'),
      );
      expect(avatar, findsOneWidget);
      expect(
        find.descendant(of: avatar, matching: find.byIcon(Icons.key)),
        findsOneWidget,
      );
      expect(find.text('Login'), findsNothing);
      if (width == 1600) {
        expect(
          find.byKey(const ValueKey('online-gallery-primary-search')),
          findsOneWidget,
        );
        final primaryCenter = tester
            .getCenter(
              find.byKey(const ValueKey('online-gallery-toolbar-primary-row')),
            )
            .dy;
        expect(
          (tester
                      .getCenter(
                        find.byKey(
                          const ValueKey('online-gallery-primary-search'),
                        ),
                      )
                      .dy -
                  primaryCenter)
              .abs(),
          lessThan(1),
        );
        expect(find.text('Refresh'), findsOneWidget);
        expect(find.text('Multi-select'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('online-gallery-source-filters')),
          findsNothing,
        );
        final searchRect = tester.getRect(
          find.byKey(const ValueKey('online-gallery-primary-search')),
        );
        final blacklistRect = tester.getRect(
          find.byKey(const ValueKey('online-gallery-blacklist')),
        );
        final accountRect = tester.getRect(
          find.byKey(const ValueKey('online-gallery-account-avatar')),
        );
        final primaryRect = tester.getRect(
          find.byKey(const ValueKey('online-gallery-toolbar-primary-row')),
        );
        expect(blacklistRect.left - searchRect.right, closeTo(8, 0.1));
        expect(accountRect.right, closeTo(primaryRect.right, 0.1));
      }
      final collapsed = width < 1100;
      expect(
        find.byKey(const ValueKey('online-gallery-blacklist')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('online-gallery-source-filters')),
        collapsed ? findsOneWidget : findsNothing,
      );
      final primaryRow = tester.getRect(
        find.byKey(const ValueKey('online-gallery-toolbar-primary-row')),
      );
      final secondaryRow = tester.getRect(
        find.byKey(const ValueKey('online-gallery-toolbar-secondary-row')),
      );
      final expectedPrimaryHeight = PlatformCapabilities.current.isMobile
          ? 48.0
          : 40.0;
      final expectedSecondaryHeight = PlatformCapabilities.current.isMobile
          ? 56.0
          : 40.0;
      expect(primaryRow.height, expectedPrimaryHeight);
      expect(secondaryRow.height, expectedSecondaryHeight);
      expect(secondaryRow.top - primaryRow.bottom, 8);
      final visibleKeys = <String>[
        'online-gallery-source-selector',
        'online-gallery-mode-search',
        'online-gallery-mode-popular',
        'online-gallery-mode-favorites',
        'online-gallery-rating-filter',
        'online-gallery-primary-search',
        'online-gallery-blacklist',
        'online-gallery-output-filter',
        'online-gallery-random-toggle',
        'online-gallery-refresh',
        'online-gallery-multi-select',
        'online-gallery-account-avatar',
      ];
      expect(
        find.byKey(const ValueKey('online-gallery-primary-controls-scroll')),
        width < 1400 ? findsOneWidget : findsNothing,
      );
      for (final key in visibleKeys) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(
          (rect.center.dy - primaryRow.center.dy).abs(),
          lessThan(1),
          reason: '$key must stay in the primary row at width $width',
        );
      }
      if (width == 700) {
        await tester.tap(
          find.byKey(const ValueKey('online-gallery-source-filters')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final filterPanel = find.byType(DraggableScrollableSheet);
        expect(filterPanel, findsOneWidget);
        expect(
          find.descendant(
            of: filterPanel,
            matching: find.byKey(const ValueKey('online-gallery-blacklist')),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: filterPanel,
            matching: find.byKey(
              const ValueKey('online-gallery-output-filter'),
            ),
          ),
          findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Gelbooru does not silently switch sites for popular mode', (
    tester,
  ) async {
    await _setViewSize(tester, 1200);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _GelbooruSearchGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();

    final popularButton = find.byKey(
      const ValueKey('online-gallery-mode-popular'),
    );
    final inkWell = tester.widget<InkWell>(
      find.descendant(of: popularButton, matching: find.byType(InkWell)),
    );
    expect(inkWell.onTap, isNull);
    expect(find.text('Gelbooru'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Safebooru search has no account entry', (tester) async {
    await _setViewSize(tester, 1600);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _SafebooruSearchGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Configure Gelbooru API'), findsNothing);
    expect(find.text('Login'), findsNothing);
    final avatar = find.byKey(const ValueKey('online-gallery-account-avatar'));
    expect(
      find.descendant(
        of: avatar,
        matching: find.byIcon(Icons.person_off_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('popular mode remains a Danbooru account surface', (
    tester,
  ) async {
    await _setViewSize(tester, 1600);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _PopularGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();

    expect(
      _selectedModeColor(tester, 'online-gallery-mode-popular'),
      const Color(0xFFC2410C),
    );
    final secondaryRow = tester.getRect(
      find.byKey(const ValueKey('online-gallery-toolbar-secondary-row')),
    );
    final secondaryControls = tester.getRect(
      find.byKey(const ValueKey('online-gallery-secondary-controls')),
    );
    expect(secondaryControls.left, secondaryRow.left);

    final avatar = find.byKey(const ValueKey('online-gallery-account-avatar'));
    expect(avatar, findsOneWidget);
    expect(
      find.descendant(of: avatar, matching: find.byIcon(Icons.login)),
      findsOneWidget,
    );
    expect(find.text('Configure Gelbooru API'), findsNothing);
  });

  for (final entry in {
    GallerySourceId.safebooru: _SafebooruPopularGalleryNotifier.new,
    GallerySourceId.aiTag: _AiTagPopularGalleryNotifier.new,
  }.entries) {
    testWidgets('${entry.key.label} popular mode has no account entry', (
      tester,
    ) async {
      await _setViewSize(tester, 1600);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineGalleryNotifierProvider.overrideWith(entry.value),
            danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
            gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
            danbooruSuggestionNotifierProvider.overrideWith(
              _EmptyDanbooruSuggestionNotifier.new,
            ),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pump();

      expect(find.text('Login'), findsNothing);
      expect(find.text('Configure Gelbooru API'), findsNothing);
      final avatar = find.byKey(
        const ValueKey('online-gallery-account-avatar'),
      );
      expect(
        find.descendant(
          of: avatar,
          matching: find.byIcon(Icons.person_off_outlined),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'Gelbooru favorites identify read-only ID ordering on narrow UI',
    (tester) async {
      await _setViewSize(tester, 700);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineGalleryNotifierProvider.overrideWith(
              _GelbooruFavoritesGalleryNotifier.new,
            ),
            danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
            gelbooruAuthProvider.overrideWith(_AuthenticatedGelbooruAuth.new),
            danbooruSuggestionNotifierProvider.overrideWith(
              _EmptyDanbooruSuggestionNotifier.new,
            ),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pump();
      expect(
        _selectedModeColor(tester, 'online-gallery-mode-favorites'),
        const Color(0xFFBE185D),
      );
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('online-gallery-source-filters')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Read-only favorites'), findsWidgets);
      expect(find.textContaining('Sorted by post ID'), findsOneWidget);
      expect(find.text('Local favorites'), findsNothing);
      expect(find.text('Cloud favorites'), findsNothing);
      final avatar = find.byKey(
        const ValueKey('online-gallery-account-avatar'),
      );
      expect(
        find.descendant(of: avatar, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [700.0, 840.0, 1180.0, 1600.0]) {
    testWidgets('unified favorites stay aligned at width $width', (
      tester,
    ) async {
      await _setViewSize(tester, width);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineGalleryNotifierProvider.overrideWith(
              _GelbooruFavoritesGalleryNotifier.new,
            ),
            danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
            gelbooruAuthProvider.overrideWith(_AuthenticatedGelbooruAuth.new),
            danbooruSuggestionNotifierProvider.overrideWith(
              _EmptyDanbooruSuggestionNotifier.new,
            ),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pump();

      expect(find.text('Local favorites'), findsNothing);
      expect(find.text('Cloud favorites'), findsNothing);
      final primaryRow = tester.getRect(
        find.byKey(const ValueKey('online-gallery-toolbar-primary-row')),
      );
      for (final key in [
        'online-gallery-source-selector',
        'online-gallery-mode-favorites',
        'online-gallery-rating-filter',
        'online-gallery-primary-search',
        'online-gallery-blacklist',
        'online-gallery-output-filter',
        'online-gallery-random-toggle',
        'online-gallery-refresh',
        'online-gallery-multi-select',
        'online-gallery-account-avatar',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(
          (rect.center.dy - primaryRow.center.dy).abs(),
          lessThan(1),
          reason: '$key must stay in the primary row at width $width',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [700.0, 840.0, 1180.0, 1600.0]) {
    testWidgets('AI TAG controls adapt without overflow at width $width', (
      tester,
    ) async {
      await _setViewSize(tester, width);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onlineGalleryNotifierProvider.overrideWith(
              _AiTagSearchGalleryNotifier.new,
            ),
            danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
            gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
            danbooruSuggestionNotifierProvider.overrideWith(
              _EmptyDanbooruSuggestionNotifier.new,
            ),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pump();

      expect(
        find.widgetWithText(
          TextField,
          'Search works, artists, titles, tags, or models',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('AI Prompt search'), findsOneWidget);
      if (width < 1100) {
        await tester.tap(
          find.byKey(const ValueKey('online-gallery-source-filters')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }
      final artistHuntToggle = find.byKey(
        const ValueKey('online-gallery-artist-hunt-toggle'),
      );
      expect(artistHuntToggle, findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find
            .ancestor(of: artistHuntToggle, matching: find.byType(Semantics))
            .first,
      );
      expect(semantics.properties.label, 'Artist chains only');
      expect(find.text('Artist chains only'), findsOneWidget);
      expect(semantics.properties.toggled, isFalse);
      await tester.tap(artistHuntToggle);
      await tester.pump();
      expect(
        tester
            .widget<Semantics>(
              find
                  .ancestor(
                    of: artistHuntToggle,
                    matching: find.byType(Semantics),
                  )
                  .first,
            )
            .properties
            .toggled,
        isTrue,
      );
      if (width < 1100) {
        Navigator.of(tester.element(artistHuntToggle)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }

      final card = find.byType(DanbooruPostCard);
      final viewIcon = find.descendant(
        of: card,
        matching: find.byIcon(Icons.visibility_outlined),
      );
      final favoriteIcon = find.descendant(
        of: card,
        matching: find.byIcon(Icons.favorite),
      );
      final viewCount = find.descendant(of: card, matching: find.text('123'));
      final favoriteCount = find.descendant(
        of: card,
        matching: find.text('45'),
      );
      expect(viewIcon, findsOneWidget);
      expect(favoriteIcon, findsOneWidget);
      final viewIconRect = tester.getRect(viewIcon);
      final favoriteIconRect = tester.getRect(favoriteIcon);
      final viewCountRect = tester.getRect(viewCount);
      final favoriteCountRect = tester.getRect(favoriteCount);
      expect(
        viewCountRect.left - viewIconRect.right,
        greaterThanOrEqualTo(3.5),
      );
      expect(
        favoriteCountRect.left - favoriteIconRect.right,
        greaterThanOrEqualTo(3.5),
      );
      expect(viewIconRect.center.dy, closeTo(viewCountRect.center.dy, 1));
      expect(
        favoriteIconRect.center.dy,
        closeTo(favoriteCountRect.center.dy, 1),
      );
      expect(viewIconRect.left, closeTo(tester.getRect(card).left + 6, 1));

      expect(find.text('Login'), findsNothing);
      expect(find.byIcon(Icons.tune), findsNothing);
      expect(find.byIcon(Icons.blur_on), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('AI TAG detail exposes multi-image metadata actions', (
    tester,
  ) async {
    await _setViewSize(tester, 1200);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _AiTagDetailGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
          replicationQueueNotifierProvider.overrideWith(
            _TestReplicationQueueNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(DanbooruPostCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('AI TAG'), findsWidgets);
    expect(find.text('3 images'), findsOneWidget);
    expect(find.byTooltip('Copy Prompt'), findsAtLeastNWidgets(1));
    expect(find.widgetWithText(OutlinedButton, 'Copy'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.widgetWithText(MenuItemButton, 'Copy Prompt'), findsNothing);
    expect(
      find.widgetWithText(MenuItemButton, 'Copy full metadata'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(MenuItemButton, 'Copy full metadata'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Download all images in this work'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsAtLeastNWidgets(4));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add to Queue'));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Dialog)),
    );
    final queuedTask = container
        .read(replicationQueueNotifierProvider)
        .tasks
        .single;
    expect(queuedTask.prompt, '1girl, solo');
    expect(queuedTask.negativePrompt, 'lowres');
    expect(queuedTask.applyNegativePrompt, isTrue);
    expect(queuedTask.characterPrompts, hasLength(1));
    expect(queuedTask.characterPrompts!.single.prompt, 'red hair');
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI TAG filtered work targets its representative media', (
    tester,
  ) async {
    await _setViewSize(tester, 1200);
    String? clipboardText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _AiTagHuntGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('ai_tag:801')), findsOneWidget);
    expect(find.text('1 artists'), findsOneWidget);

    final card = find.byType(DanbooruPostCard);
    final directCopyAction = find.byTooltip('Copy artist chain');
    if (directCopyAction.evaluate().isNotEmpty) {
      await tester.tap(directCopyAction);
    } else {
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.more_vert_rounded),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Copy artist chain'));
    }
    await tester.pump();
    expect(clipboardText, '1.2::artist:target::');
    await tester.pump(const Duration(seconds: 3));

    await tester.pump();
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.widgetWithText(MenuItemButton, 'Copy artist chain'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(MenuItemButton, 'Copy full Prompt'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(MenuItemButton, 'Copy original artist fragments'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(MenuItemButton, 'Copy artist chain'));
    await tester.pump();
    expect(clipboardText, '1.2::artist:target::');
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(MenuItemButton, 'Copy full Prompt'));
    await tester.pump();
    expect(
      clipboardText,
      'landscape, 1.2::artist:target::\n\nNegative Prompt:\nlowres\n\n'
      'Hero:\nred hair\nNegative Prompt: bad hands',
    );
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byIcon(Icons.chevron_right),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('No artist chain'), findsOneWidget);
    expect(
      tester
          .widget<MenuItemButton>(
            find.widgetWithText(MenuItemButton, 'No artist chain'),
          )
          .onPressed,
      isNull,
    );
    await tester.tapAt(const Offset(200, 400));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty filtered page automatically continues pagination', (
    tester,
  ) async {
    await _setViewSize(tester, 1200);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _EmptyFilteredGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('danbooru:401')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('underfilled grid automatically appends the next page', (
    tester,
  ) async {
    await _setViewSize(tester, 1200);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _UnderfilledGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('danbooru:401')), findsOneWidget);
    expect(find.byKey(const ValueKey('danbooru:402')), findsOneWidget);
    expect(find.text('2 images'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused random miss requires an explicit continue action', (
    tester,
  ) async {
    _PausedRandomGalleryNotifier.loadMoreCalls = 0;
    await _setViewSize(tester, 1200);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _PausedRandomGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(_PausedRandomGalleryNotifier.loadMoreCalls, 0);
    expect(find.text('Continue scanning'), findsOneWidget);

    await tester.tap(find.text('Continue scanning'));
    await tester.pump();
    expect(_PausedRandomGalleryNotifier.loadMoreCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page replacement renders the second page URL with stable keys', (
    tester,
  ) async {
    await _setViewSize(tester, 1200);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(_PagedGalleryNotifier.new),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('danbooru:401')), findsOneWidget);
    expect(
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first)
          .imageUrl,
      contains('page-1'),
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(find.byKey(const ValueKey('danbooru:401')), findsNothing);
    expect(find.byKey(const ValueKey('danbooru:402')), findsOneWidget);
    expect(
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first)
          .imageUrl,
      contains('page-2'),
    );
    expect(
      tester.widget<DanbooruPostCard>(find.byType(DanbooruPostCard)).post.id,
      402,
    );
  });

  testWidgets('favorites source selector switches back to Danbooru', (
    tester,
  ) async {
    await _setViewSize(tester, 1600);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _GelbooruFavoritesGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_AuthenticatedGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(PopupMenuButton<GallerySourceId>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Danbooru').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final avatar = find.byKey(const ValueKey('online-gallery-account-avatar'));
    expect(
      find.descendant(of: avatar, matching: find.byIcon(Icons.login)),
      findsOneWidget,
    );
    expect(find.text('Configure Gelbooru API'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden gallery does not auto-load an underfilled page', (
    tester,
  ) async {
    _HiddenUnderfilledGalleryNotifier.loadMoreCalls = 0;
    await _setViewSize(tester, 1200);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _HiddenUnderfilledGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _HiddenTestApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(_HiddenUnderfilledGalleryNotifier.loadMoreCalls, 0);
  });

  testWidgets('random mode replaces pagination and restores it when disabled', (
    tester,
  ) async {
    await _setViewSize(tester, 1600);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _RandomUiGalleryNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('online-gallery-pagination-bar')),
      findsOneWidget,
    );
    final primaryCenter = tester
        .getCenter(
          find.byKey(const ValueKey('online-gallery-toolbar-primary-row')),
        )
        .dy;
    for (final key in const [
      ValueKey('online-gallery-blacklist'),
      ValueKey('online-gallery-output-filter'),
      ValueKey('online-gallery-random-toggle'),
      ValueKey('online-gallery-refresh'),
      ValueKey('online-gallery-multi-select'),
      ValueKey('online-gallery-account-avatar'),
    ]) {
      expect(
        (tester.getCenter(find.byKey(key)).dy - primaryCenter).abs(),
        lessThan(1),
      );
    }
    await tester.ensureVisible(
      find.byKey(const ValueKey('online-gallery-random-toggle')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey('online-gallery-random-toggle')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('online-gallery-random-status-bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('online-gallery-pagination-bar')),
      findsNothing,
    );
    expect(find.text('Draw again'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('online-gallery-random-toggle')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('online-gallery-pagination-bar')),
      findsOneWidget,
    );
  });

  for (final width in [700.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      'QuickTagCloud toolbar keeps every global control in row one at $width',
      (tester) async {
        await _setViewSize(tester, width);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onlineGalleryNotifierProvider.overrideWith(
                _QuickTagCloudGalleryNotifier.new,
              ),
              quickTagCloudGallerySourceAdapterProvider.overrideWithValue(
                _TrackingQuickTagCloudAdapter(),
              ),
              quickTagCloudCatalogProvider.overrideWith(
                (ref) async => _quickTagCloudCatalog(),
              ),
              quickTagCloudFilterProvider.overrideWith(
                _QuickTagCloudFilterNotifier.new,
              ),
              danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
              gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
              danbooruSuggestionNotifierProvider.overrideWith(
                _EmptyDanbooruSuggestionNotifier.new,
              ),
            ],
            child: const _TestApp(locale: Locale('zh')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        if (width >= 1400) {
          for (final icon in const [
            Icons.shuffle,
            Icons.refresh,
            Icons.checklist,
          ]) {
            expect(find.byIcon(icon), findsOneWidget);
          }
        }
        for (final key in const [
          'online-gallery-source-selector',
          'online-gallery-mode-search',
          'online-gallery-rating-filter',
          'online-gallery-primary-search',
          'online-gallery-blacklist',
          'online-gallery-output-filter',
          'online-gallery-random-toggle',
          'online-gallery-refresh',
          'online-gallery-multi-select',
          'online-gallery-account-avatar',
        ]) {
          expect(find.byKey(ValueKey(key)), findsOneWidget);
        }
        final searchRect = tester.getRect(
          find.byKey(const ValueKey('online-gallery-primary-search')),
        );
        final counterRect = tester.getRect(
          find.byKey(const ValueKey('online-gallery-tag-count')),
        );
        final blacklistRect = tester.getRect(
          find.byKey(const ValueKey('online-gallery-blacklist')),
        );
        final accountRect = tester.getRect(
          find.byKey(const ValueKey('online-gallery-account-avatar')),
        );
        final primaryRect = tester.getRect(
          find.byKey(const ValueKey('online-gallery-toolbar-primary-row')),
        );
        expect(searchRect.width, greaterThanOrEqualTo(280));
        expect(counterRect.center.dy, closeTo(searchRect.center.dy, 0.1));
        expect(blacklistRect.left - searchRect.right, closeTo(8, 0.1));
        expect(
          accountRect.right,
          greaterThanOrEqualTo(primaryRect.right - 0.1),
        );
        for (final key in const [
          'online-gallery-primary-search',
          'online-gallery-blacklist',
          'online-gallery-output-filter',
          'online-gallery-random-toggle',
          'online-gallery-refresh',
          'online-gallery-multi-select',
          'online-gallery-account-avatar',
        ]) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(
            (rect.center.dy - primaryRect.center.dy).abs(),
            lessThan(1),
            reason: '$key must stay in the primary row at width $width',
          );
        }
        if (width == 1600) {
          expect(accountRect.right, closeTo(primaryRect.right, 0.1));
          final searchField = find.descendant(
            of: find.byKey(const ValueKey('online-gallery-primary-search')),
            matching: find.byType(TextField),
          );
          await tester.enterText(searchField, 'a b c d e f g');
          await tester.pump();
          expect(find.text('7/6'), findsOneWidget);
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pump();
          expect(find.text('最多可组合搜索 6 个标签'), findsOneWidget);
          await tester.pump(const Duration(seconds: 4));
        }
        expect(find.text('Leaf category'), findsOneWidget);
        expect(find.text('Fallback codex title'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('QuickTagCloud reuses rating filter and refresh update check', (
    tester,
  ) async {
    await _setViewSize(tester, 1600);
    final adapter = _TrackingQuickTagCloudAdapter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineGalleryNotifierProvider.overrideWith(
            _QuickTagCloudGalleryNotifier.new,
          ),
          quickTagCloudGallerySourceAdapterProvider.overrideWithValue(adapter),
          quickTagCloudCatalogProvider.overrideWith(
            (ref) async => _quickTagCloudCatalog(),
          ),
          quickTagCloudFilterProvider.overrideWith(
            _QuickTagCloudFilterNotifier.new,
          ),
          danbooruAuthProvider.overrideWith(_LoggedOutDanbooruAuth.new),
          gelbooruAuthProvider.overrideWith(_UnconfiguredGelbooruAuth.new),
          danbooruSuggestionNotifierProvider.overrideWith(
            _EmptyDanbooruSuggestionNotifier.new,
          ),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('quick-tag-cloud-check-updates')),
      findsNothing,
    );
    final sourceSelector = find.byKey(
      const ValueKey('online-gallery-source-selector'),
    );
    expect(sourceSelector, findsOneWidget);
    final ratingFilter = find.byKey(
      const ValueKey('online-gallery-rating-filter'),
    );
    expect(ratingFilter, findsOneWidget);
    final primaryCenter = tester
        .getCenter(
          find.byKey(const ValueKey('online-gallery-toolbar-primary-row')),
        )
        .dy;
    for (final key in const [
      ValueKey('online-gallery-primary-search'),
      ValueKey('online-gallery-rating-filter'),
      ValueKey('online-gallery-blacklist'),
      ValueKey('online-gallery-output-filter'),
      ValueKey('online-gallery-random-toggle'),
      ValueKey('online-gallery-refresh'),
      ValueKey('online-gallery-multi-select'),
      ValueKey('online-gallery-account-avatar'),
    ]) {
      expect(
        (tester.getCenter(find.byKey(key)).dy - primaryCenter).abs(),
        lessThan(1),
      );
    }
    expect(
      tester
          .getSize(find.byKey(const ValueKey('online-gallery-blacklist')))
          .width,
      lessThan(150),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('online-gallery-output-filter')))
          .width,
      lessThan(180),
    );
    await tester.tap(ratingFilter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('General'), findsWidgets);
    expect(find.text('Questionable'), findsOneWidget);
    expect(find.text('Explicit'), findsOneWidget);
    expect(find.text('Sensitive'), findsNothing);
    await tester.tap(find.text('Questionable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnlineGalleryScreen)),
    );
    expect(container.read(onlineGalleryNotifierProvider).selectedRatings, {
      'g',
      'q',
    });

    await tester.ensureVisible(
      find.byKey(const ValueKey('online-gallery-refresh')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('online-gallery-refresh')));
    await tester.pump();
    expect(adapter.invalidationCount, 1);

    await tester.ensureVisible(sourceSelector);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(sourceSelector);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Danbooru').last);
    await tester.pump();
    expect(
      (container.read(onlineGalleryNotifierProvider.notifier)
              as _QuickTagCloudGalleryNotifier)
          .selectedSource,
      GallerySourceId.danbooru,
    );
  });
}

Future<void> _setViewSize(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Color? _selectedModeColor(WidgetTester tester, String key) {
  final material = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(Material),
  );
  return tester.widget<Material>(material).color;
}

class _TestApp extends StatelessWidget {
  final Locale locale;

  const _TestApp({this.locale = const Locale('en')});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const OnlineGalleryScreen(),
    );
  }
}

class _HiddenTestApp extends StatelessWidget {
  const _HiddenTestApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppBranchVisibility(isVisible: false, child: OnlineGalleryScreen()),
    );
  }
}

const _gelbooruPost = DanbooruPost(
  id: 301,
  site: 'gelbooru',
  width: 1200,
  height: 800,
  rating: 'g',
  previewFileUrl: 'https://img4.gelbooru.com/thumbnail.jpg',
  tagString: 'solo',
);

const _danbooruPost = DanbooruPost(
  id: 302,
  site: 'danbooru',
  width: 1200,
  height: 800,
  rating: 'g',
  previewFileUrl: 'https://cdn.donmai.us/preview.jpg',
  tagStringGeneral: 'solo',
);

const _aiTagPost = GalleryItem(
  id: 801,
  sourceId: GallerySourceId.aiTag,
  createdAt: '2026-07-01',
  uploaderId: 88,
  title: 'AI work',
  author: 'Alice',
  aiType: 'NAI',
  mediaCount: 3,
  viewCount: 123,
  favoriteCount: 45,
  rank: 3,
  tags: ['1girl'],
  cover: GalleryMedia(
    id: '801_p0',
    previewUrl: 'https://cdn.example/NAI/88/801_p0.webp',
    displayUrl: 'https://cdn.example/NAI/88/801_p0.webp',
    downloadUrl: 'https://cdn.example/NAI/88/801_p0.webp',
    width: 768,
    height: 1024,
  ),
);

const _pageOnePost = DanbooruPost(
  id: 401,
  site: 'danbooru',
  width: 1200,
  height: 800,
  rating: 'g',
  previewFileUrl: 'https://cdn.example/page-1.jpg',
  tagStringGeneral: 'solo',
);

const _pageTwoPost = DanbooruPost(
  id: 402,
  site: 'danbooru',
  width: 1200,
  height: 800,
  rating: 'g',
  previewFileUrl: 'https://cdn.example/page-2.jpg',
  tagStringGeneral: 'solo',
);

class _RandomUiGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      searchCache: ModeCache(posts: [_danbooruPost], hasMore: false),
    );
  }

  @override
  Future<void> setRandomEnabled(bool enabled) async {
    state = state.copyWith(
      randomEnabled: enabled,
      randomSession: enabled
          ? const RandomGallerySession(
              scopeKey: 'test',
              cache: ModeCache(posts: [_danbooruPost], hasMore: false),
              drawRevision: 1,
              exhausted: true,
            )
          : state.randomSession,
    );
  }
}

class _QuickTagCloudGalleryNotifier extends OnlineGalleryNotifier {
  GallerySourceId? selectedSource;

  @override
  OnlineGalleryState build() => const OnlineGalleryState(
    sourceId: GallerySourceId.quickTagCloud,
    selectedRatings: {'g'},
    searchCache: ModeCache(
      posts: [
        GalleryItem(
          id: 0,
          workId: 'book/text-entry',
          sourceId: GallerySourceId.quickTagCloud,
          title: 'Text entry',
          mediaCount: 0,
          rawSourceMetadata: {
            'codexTitle': 'Fallback codex title',
            'categoryPath': ['Parent category', 'Leaf category'],
          },
        ),
      ],
      hasMore: false,
    ),
  );

  @override
  void clearDetailCache() {}

  @override
  void syncQuickTagCloudFilterKey() {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> setRatings(Set<String> selectedRatings) async {
    state = state.copyWith(selectedRatings: selectedRatings);
  }

  @override
  Future<void> setSource(Object source) async {
    selectedSource = source as GallerySourceId;
  }
}

class _QuickTagCloudFilterNotifier extends QuickTagCloudFilterNotifier {
  @override
  QuickTagCloudGalleryQuery build() => const QuickTagCloudGalleryQuery();

  @override
  Future<bool> initializeContentAccess() async => false;

  @override
  Future<void> applyFilters({
    required String codexId,
    required String updateFilterId,
    required QuickTagCloudBrowseScope scope,
    required QuickTagCloudMediaFilter mediaFilter,
    required bool allowNsfw,
    required bool allowR18g,
  }) async {
    state = QuickTagCloudGalleryQuery(
      codexId: codexId,
      updateFilterId: updateFilterId,
      scope: scope,
      mediaFilter: mediaFilter,
      allowNsfw: allowNsfw,
      allowR18g: allowR18g,
    );
  }
}

class _TrackingQuickTagCloudAdapter extends QuickTagCloudGallerySourceAdapter {
  _TrackingQuickTagCloudAdapter()
    : super(
        catalogService: QuickTagCloudRemoteCatalogService(),
        userService: QuickTagCloudUserService(LocalStorageService()),
        queryReader: () => const QuickTagCloudGalleryQuery(),
      );

  int invalidationCount = 0;

  @override
  void invalidateCatalog() {
    invalidationCount++;
    super.invalidateCatalog();
  }
}

QuickTagCloudCatalog _quickTagCloudCatalog() => QuickTagCloudCatalog(
  config: QuickTagCloudDataSourceConfig(
    schemaVersion: 1,
    baseUrl: Uri.https('example.test', '/data'),
    pointer: 'current.json',
  ),
  pointer: const QuickTagCloudReleasePointer(
    schemaVersion: 1,
    release: 'r-0123456789abcdef0123',
    manifest: 'manifest.json',
  ),
  manifest: QuickTagCloudReleaseManifest(
    schemaVersion: 1,
    release: 'r-0123456789abcdef0123',
    files: const {},
  ),
  codexes: const [],
  media: const QuickTagCloudMediaConfig(),
);

class _GelbooruSearchGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      sourceId: GallerySourceId.gelbooru,
      searchCache: ModeCache(posts: [_gelbooruPost], hasMore: false),
    );
  }
}

class _SafebooruSearchGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      sourceId: GallerySourceId.safebooru,
      searchCache: ModeCache(posts: [_danbooruPost], hasMore: false),
    );
  }
}

class _AiTagSearchGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return OnlineGalleryState(
      sourceId: GallerySourceId.aiTag,
      aiTagConfig: AiTagSourceConfig(
        assetBaseUrl: 'https://cdn.example/',
        pageSize: 60,
        availableYears: const [2026, 2025],
        availableMonths: const ['2026-07'],
        fetchedAt: DateTime(2026, 8, 9),
      ),
      searchCache: const ModeCache(posts: [_aiTagPost], hasMore: false),
    );
  }

  @override
  Future<void> setArtistHuntEnabled(bool enabled) async {
    final cache = state.currentCache;
    state = state
        .copyWith(artistHuntEnabled: enabled)
        .updateCurrentCache(cache);
  }

  @override
  Future<void> loadPosts({bool refresh = false}) async {}

  @override
  Future<void> loadMore() async {}
}

class _AiTagDetailGalleryNotifier extends _AiTagSearchGalleryNotifier {
  @override
  Future<GalleryDetail> loadDetail(
    GalleryItem item, {
    bool forceRefresh = false,
    GalleryDetailPriority priority = GalleryDetailPriority.interactive,
  }) async {
    const media = [
      GalleryMedia(
        id: '801_p0',
        previewUrl: 'https://cdn.example/NAI/88/801_p0.webp',
        displayUrl: 'https://cdn.example/NAI/88/801_p0.webp',
        downloadUrl: 'https://cdn.example/NAI/88/801_p0.webp',
        prompt: '1girl, solo',
        negativePrompt: 'lowres',
        rawMetadata: '{"prompt":"1girl"}',
      ),
      GalleryMedia(
        id: '801_p1',
        previewUrl: 'https://cdn.example/NAI/88/801_p1.webp',
        displayUrl: 'https://cdn.example/NAI/88/801_p1.webp',
        downloadUrl: 'https://cdn.example/NAI/88/801_p1.webp',
        prompt: 'landscape, 1.2::artist:target::',
      ),
      GalleryMedia(
        id: '801_p2',
        previewUrl: 'https://cdn.example/NAI/88/801_p2.webp',
        displayUrl: 'https://cdn.example/NAI/88/801_p2.webp',
        downloadUrl: 'https://cdn.example/NAI/88/801_p2.webp',
        prompt: 'portrait',
      ),
    ];
    return const GalleryDetail(
      item: _aiTagPost,
      media: media,
      prompt: '1girl, solo',
      negativePrompt: 'lowres',
      description: 'Description',
      characterPrompts: [
        GalleryCharacterPrompt(
          label: 'Hero',
          prompt: 'red hair',
          negativePrompt: 'bad hands',
        ),
      ],
    );
  }
}

class _AiTagHuntGalleryNotifier extends _AiTagDetailGalleryNotifier {
  @override
  OnlineGalleryState build() {
    final base = super.build().copyWith(artistHuntEnabled: true);
    const focusedMedia = GalleryMedia(
      id: '801_p1',
      previewUrl: 'https://cdn.example/NAI/88/801_p1.webp',
      displayUrl: 'https://cdn.example/NAI/88/801_p1.webp',
      downloadUrl: 'https://cdn.example/NAI/88/801_p1.webp',
      width: 768,
      height: 1024,
      prompt: 'landscape, 1.2::artist:target::',
    );
    final focusedItem = _aiTagPost.copyWith(
      cover: focusedMedia,
      focusedMediaId: focusedMedia.id,
      focusedMediaIndex: 1,
      artistChain: const ArtistChainExtraction(
        formattedText: '1.2::artist:target::',
        rawFragments: ['artist:target'],
        artistNames: ['target'],
      ),
    );
    return base.updateCurrentCache(
      ModeCache(posts: [focusedItem], hasMore: false),
    );
  }
}

class _EmptyFilteredGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      searchCache: ModeCache(posts: [], page: 5, nextCursor: 'b500'),
    );
  }

  @override
  Future<void> loadPosts({bool refresh = false}) async {}

  @override
  Future<void> loadMore() async {
    state = const OnlineGalleryState(
      searchCache: ModeCache(
        posts: [_pageOnePost],
        page: 6,
        nextCursor: null,
        hasMore: false,
      ),
    );
  }
}

class _HiddenUnderfilledGalleryNotifier extends OnlineGalleryNotifier {
  static int loadMoreCalls = 0;

  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      searchCache: ModeCache(posts: [_pageOnePost], nextCursor: '2'),
    );
  }

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
  }
}

class _UnderfilledGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      searchCache: ModeCache(posts: [_pageOnePost], page: 1, nextCursor: '2'),
    );
  }

  @override
  Future<void> loadMore() async {
    state = const OnlineGalleryState(
      searchCache: ModeCache(
        posts: [_pageOnePost, _pageTwoPost],
        page: 2,
        nextCursor: null,
        hasMore: false,
      ),
    );
  }
}

class _PausedRandomGalleryNotifier extends OnlineGalleryNotifier {
  static int loadMoreCalls = 0;

  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      randomEnabled: true,
      randomSession: RandomGallerySession(
        cache: ModeCache(
          nextCursor: 'random',
          hasMore: true,
          queryScanPaused: true,
        ),
      ),
    );
  }

  @override
  Future<void> loadPosts({bool refresh = false}) async {}

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
  }
}

class _PagedGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      searchCache: ModeCache(posts: [_pageOnePost], page: 1, nextCursor: '2'),
    );
  }

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> goToPage(int page) async {
    state = const OnlineGalleryState(
      searchCache: ModeCache(
        posts: [_pageTwoPost],
        page: 2,
        nextCursor: null,
        hasMore: false,
      ),
    );
  }
}

class _PopularGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      viewMode: GalleryViewMode.popular,
      popularCache: ModeCache(posts: [_danbooruPost], hasMore: false),
    );
  }
}

class _SafebooruPopularGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      viewMode: GalleryViewMode.popular,
      popularSourceId: GallerySourceId.safebooru,
      popularCache: ModeCache(posts: [_danbooruPost], hasMore: false),
    );
  }
}

class _AiTagPopularGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      viewMode: GalleryViewMode.popular,
      popularSourceId: GallerySourceId.aiTag,
      popularCache: ModeCache(posts: [_aiTagPost], hasMore: false),
    );
  }
}

class _GelbooruFavoritesGalleryNotifier extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() {
    return const OnlineGalleryState(
      viewMode: GalleryViewMode.favorites,
      favoritesSourceId: GallerySourceId.gelbooru,
      favoritedPostKeys: {'gelbooru:301'},
      remoteFavoritedPostKeys: {'gelbooru:301'},
    ).updateFavoritesCache(
      GallerySourceId.gelbooru,
      const ModeCache(posts: [_gelbooruPost], hasMore: false),
    );
  }
}

class _LoggedOutDanbooruAuth extends DanbooruAuth {
  @override
  DanbooruAuthState build() => const DanbooruAuthState();

  @override
  Future<void> ensureInitialized() async {}
}

class _UnconfiguredGelbooruAuth extends GelbooruAuth {
  @override
  GelbooruAuthState build() =>
      const GelbooruAuthState(status: GelbooruAuthStatus.unconfigured);

  @override
  Future<void> ensureInitialized() async {}
}

class _AuthenticatedGelbooruAuth extends GelbooruAuth {
  @override
  GelbooruAuthState build() => const GelbooruAuthState(
    credentials: GelbooruCredentials(userId: 99, apiKey: 'key'),
    status: GelbooruAuthStatus.authenticated,
  );

  @override
  Future<void> ensureInitialized() async {}
}

class _TestReplicationQueueNotifier extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() =>
      const ReplicationQueueState(isLoading: false);

  @override
  Future<bool> add(ReplicationTask task) async {
    state = state.copyWith(tasks: [...state.tasks, task]);
    return true;
  }
}

class _EmptyDanbooruSuggestionNotifier extends DanbooruSuggestionNotifier {
  @override
  TagSuggestionState build() => const TagSuggestionState();
}
