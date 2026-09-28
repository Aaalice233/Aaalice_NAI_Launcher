import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_metadata_panel.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';

void main() {
  testWidgets('minimum-width panel keeps labels and values aligned', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image = GeneratedImageDetailData(
      imageBytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      metadata: const NaiImageMetadata(
        source: 'NovelAI Diffusion V4.5 Full',
        prompt: '1girl, detailed background',
        negativePrompt: 'lowres',
        seed: 123456789,
        steps: 28,
        width: 1024,
        height: 1024,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DetailMetadataPanel(
              currentImage: image,
              expandedWidth: 320,
              collapsible: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final seedLabel = tester.getRect(find.text('Seed'));
    final seedValue = tester.getRect(find.text('123456789'));
    expect(seedValue.left, greaterThan(seedLabel.right));
    expect(seedValue.top, closeTo(seedLabel.top, 0.01));
    final modelLabel = tester.getRect(find.text('Model'));
    expect(modelLabel.left, closeTo(seedLabel.left, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow metadata panel stacks values at three-times text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image = GeneratedImageDetailData(
      imageBytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      metadata: const NaiImageMetadata(
        source: 'NovelAI Diffusion V4.5 Full',
        prompt: '1girl, detailed background',
        negativePrompt: 'lowres',
        seed: 123456789,
        steps: 28,
        width: 1024,
        height: 1024,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: Scaffold(
            body: DetailMetadataPanel(
              currentImage: image,
              expandedWidth: 320,
              collapsible: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('123456789'), findsOneWidget);
    final seedLabel = tester.getRect(find.text('Seed'));
    final seedValue = tester.getRect(find.text('123456789'));
    expect(seedValue.top, greaterThanOrEqualTo(seedLabel.bottom));
    expect(tester.takeException(), isNull);
  });
}
