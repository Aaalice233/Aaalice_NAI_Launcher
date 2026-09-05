import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/discord_share_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/discord_share/discord_share_dialog.dart';

class _MockDiscordShareService extends Mock implements DiscordShareService {}

void main() {
  testWidgets('uses official pipe chunks and excludes metadata by default', (
    tester,
  ) async {
    final service = _MockDiscordShareService();
    when(() => service.loadPromptCategoryIds()).thenReturn(null);
    when(() => service.loadIncludeMetadataPreference()).thenReturn(false);
    when(() => service.loadLongPromptAsFilePreference()).thenReturn(true);
    when(
      () => service.savePreferences(
        targetIds: any(named: 'targetIds'),
        promptCategoryIds: any(named: 'promptCategoryIds'),
        includeMetadata: any(named: 'includeMetadata'),
        longPromptAsFile: any(named: 'longPromptAsFile'),
      ),
    ).thenAnswer((_) async {});
    when(() => service.loadSession()).thenAnswer((_) async => _session);
    when(
      () => service.verifySession(_session),
    ).thenAnswer((_) async => _session);
    when(() => service.loadTargets(_session)).thenAnswer(
      (_) async => const [
        DiscordShareTarget(
          id: 'showcase',
          label: 'Showcase',
          selectedByDefault: true,
          preferPromptFile: false,
        ),
      ],
    );
    when(() => service.loadSelectedTargetIds(any())).thenReturn({'showcase'});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discordShareServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiscordShareDialog(
            imageBytes: _onePixelPng,
            fileName: 'result.png',
            width: 1,
            height: 1,
            metadata: const NaiImageMetadata(
              prompt: 'fixed pre, scene, fixed post, quality tag',
              fixedPrefixTags: ['fixed pre'],
              fixedSuffixTags: ['fixed post'],
              qualityTags: ['quality tag'],
              characterPrompts: ['alice', 'bob'],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final channelChip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Showcase'),
    );
    expect(channelChip.showCheckmark, isFalse);

    final promptField = tester.widget<TextField>(
      find.widgetWithText(TextField, '发送的提示词'),
    );
    expect(promptField.controller!.text, 'scene\n\n| alice\n\n| bob');
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );

    await tester.ensureVisible(find.text('质量词'));
    await tester.tap(find.text('质量词'));
    await tester.pump();
    await tester.tap(find.text('固定词'));
    await tester.pump();

    expect(
      promptField.controller!.text,
      'fixed pre, scene, fixed post, quality tag\n\n| alice\n\n| bob',
    );
    await tester.pump();
    verify(
      () => service.savePreferences(
        targetIds: any(named: 'targetIds', that: unorderedEquals(['showcase'])),
        promptCategoryIds: any(
          named: 'promptCategoryIds',
          that: unorderedEquals(['main', 'characters', 'quality', 'fixed']),
        ),
        includeMetadata: false,
        longPromptAsFile: true,
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets('hides transport exception details in verification state', (
    tester,
  ) async {
    final service = _MockDiscordShareService();
    when(() => service.loadPromptCategoryIds()).thenReturn(null);
    when(() => service.loadIncludeMetadataPreference()).thenReturn(false);
    when(() => service.loadLongPromptAsFilePreference()).thenReturn(true);
    when(() => service.loadSession()).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: 'https://private-relay.test'),
        message: 'Failed host lookup: private-relay.test',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [discordShareServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiscordShareDialog(
            imageBytes: _onePixelPng,
            fileName: 'result.png',
            metadata: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无法连接 Discord 分享服务，请检查网络后重试'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('private-relay.test'), findsNothing);
  });

  for (final scenario in [
    (
      name: 'Compact 320px、3x、IME 与 SafeArea',
      size: const Size(320, 900),
      scale: 3.0,
      keyboard: 300.0,
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
      surfaceKey: const ValueKey('adaptive-bottom-sheet'),
    ),
    (
      name: 'Expanded',
      size: const Size(1000, 1400),
      scale: 1.0,
      keyboard: 0.0,
      padding: EdgeInsets.zero,
      surfaceKey: const ValueKey('adaptive-centered-form'),
    ),
    for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0])
      for (final scale in [1.0, 3.0])
        (
          name: '$width px / ${scale}x',
          size: Size(width, 900),
          scale: scale,
          keyboard: 300.0,
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          surfaceKey: ValueKey(
            width < 600 ? 'adaptive-bottom-sheet' : 'adaptive-centered-form',
          ),
        ),
  ]) {
    testWidgets('${scenario.name} 可验证并进入分享编辑器', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = scenario.size;
      addTearDown(tester.view.reset);
      final service = _MockDiscordShareService();
      when(() => service.loadPromptCategoryIds()).thenReturn(null);
      when(() => service.loadIncludeMetadataPreference()).thenReturn(false);
      when(() => service.loadLongPromptAsFilePreference()).thenReturn(true);
      when(() => service.loadSession()).thenAnswer((_) async => null);
      when(
        () => service.authenticate(cancelToken: any(named: 'cancelToken')),
      ).thenAnswer((_) async => _session);
      when(() => service.loadTargets(_session)).thenAnswer(
        (_) async => const [
          DiscordShareTarget(
            id: 'showcase',
            label: 'Showcase',
            selectedByDefault: true,
            preferPromptFile: false,
          ),
        ],
      );
      when(() => service.loadSelectedTargetIds(any())).thenReturn({'showcase'});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [discordShareServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: scenario.size,
                textScaler: TextScaler.linear(scenario.scale),
                padding: scenario.padding,
                viewPadding: scenario.padding,
                viewInsets: EdgeInsets.only(bottom: scenario.keyboard),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const ValueKey('open-discord-share'),
                    onPressed: () => DiscordShareDialog.show(
                      context,
                      imageBytes: _onePixelPng,
                      fileName: 'result.png',
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-discord-share')));
      await tester.pumpAndSettle();

      final surface = find.byKey(scenario.surfaceKey);
      expect(surface, findsOneWidget);
      if (scenario.name == 'Expanded') {
        expect(tester.getSize(surface).height, lessThan(700));
      }
      expect(find.byType(Dialog), findsNothing);
      final verify = find.widgetWithText(FilledButton, 'Verify with Discord');
      await tester.ensureVisible(verify);
      await tester.tap(verify);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, 'Showcase'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('discord-share-scroll')),
        findsOneWidget,
      );
      if (scenario.keyboard > 0) {
        expect(tester.getTopLeft(surface).dy, greaterThanOrEqualTo(24));
        expect(tester.getBottomRight(surface).dy, lessThanOrEqualTo(600));
      }
      expect(tester.takeException(), isNull);

      if (scenario.name == 'Expanded') {
        expect(tester.getSize(surface).height, lessThan(900));
        final scrollable = find
            .descendant(
              of: find.byKey(const ValueKey('discord-share-scroll')),
              matching: find.byType(Scrollable),
            )
            .first;
        expect(
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
          0,
        );
      }

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
    });
  }
}

const _session = DiscordShareSession(
  token: 'session-token',
  user: DiscordShareUser(id: '42', username: 'alice'),
);

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
