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
}

const _session = DiscordShareSession(
  token: 'session-token',
  user: DiscordShareUser(id: '42', username: 'alice'),
);

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
