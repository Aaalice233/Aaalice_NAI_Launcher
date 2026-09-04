import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/handlers/vibe_import_handler.dart';

void main() {
  test('单个来自库的 Vibe 会匹配到可覆盖的原始条目', () {
    final imageBytes = Uint8List.fromList(const [1, 2, 3, 4]);
    final entry = VibeLibraryEntry(
      id: 'library-entry',
      name: 'Library Vibe',
      vibeDisplayName: 'Library Vibe',
      vibeEncoding: 'encoded-before',
      thumbnail: imageBytes,
      rawImageData: imageBytes,
      strength: 0.6,
      infoExtracted: 0.2,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      createdAt: DateTime(2026, 4, 15),
    );

    final candidate = findOriginalLibraryEntryForOverwrite(
      [entry.toVibeReference()],
      [entry],
    );

    expect(candidate?.id, 'library-entry');
  });

  test('多个 Vibe 保存到库时不会显示覆盖原条目的入口', () {
    final entries = [
      VibeLibraryEntry(
        id: 'library-entry',
        name: 'Library Vibe',
        vibeDisplayName: 'Library Vibe',
        vibeEncoding: 'encoded-before',
        thumbnail: Uint8List.fromList(const [1, 2, 3, 4]),
        rawImageData: Uint8List.fromList(const [1, 2, 3, 4]),
        strength: 0.6,
        infoExtracted: 0.2,
        sourceTypeIndex: VibeSourceType.naiv4vibe.index,
        createdAt: DateTime(2026, 4, 15),
      ),
    ];

    final candidate = findOriginalLibraryEntryForOverwrite([
      entries.first.toVibeReference(),
      entries.first.toVibeReference().copyWith(displayName: 'Other'),
    ], entries);

    expect(candidate, isNull);
  });

  test('只要存在无法重编码的 Vibe，保存到库时就不显示信息提取调节项', () {
    final imageBytes = Uint8List.fromList(const [1, 2, 3, 4]);
    final withRaw = VibeReference(
      displayName: 'With Raw',
      vibeEncoding: 'encoded-before',
      rawImageData: imageBytes,
      thumbnail: imageBytes,
      strength: 0.6,
      infoExtracted: 0.2,
      sourceType: VibeSourceType.naiv4vibe,
    );
    final encodedOnly = VibeReference(
      displayName: 'Encoded Only',
      vibeEncoding: 'encoded-before',
      thumbnail: imageBytes,
      strength: 0.6,
      infoExtracted: 0.2,
      sourceType: VibeSourceType.naiv4vibe,
    );

    expect(shouldShowInfoExtractedForLibrarySave([withRaw]), isTrue);
    expect(
      shouldShowInfoExtractedForLibrarySave([withRaw, encodedOnly]),
      isFalse,
    );
    expect(shouldShowInfoExtractedForLibrarySave([encodedOnly]), isFalse);
  });

  test('外部图片立即编码后仍保留原图以支持后续信息提取调节', () {
    final imageBytes = Uint8List.fromList(const [9, 8, 7, 6]);
    final rawVibe = VibeReference(
      displayName: 'raw-image.png',
      vibeEncoding: '',
      thumbnail: imageBytes,
      rawImageData: imageBytes,
      strength: 0.42,
      infoExtracted: 0.33,
      sourceType: VibeSourceType.rawImage,
    );

    final encoded = buildEncodedImportVibe(
      rawVibe,
      'encoded-after',
      model: ImageModels.animeDiffusionV45Full,
    );

    expect(encoded.vibeEncoding, 'encoded-after');
    expect(encoded.sourceType, VibeSourceType.naiv4vibe);
    expect(encoded.rawImageData, imageBytes);
    expect(encoded.canReencodeFromRawSource, isTrue);
    expect(encoded.infoExtracted, 0.33);
    expect(encoded.encodingModel, ImageModels.animeDiffusionV45Full);
    expect(shouldShowInfoExtractedForLibrarySave([encoded]), isTrue);
  });

  testWidgets('最窄高字级下完整保存字段可滚动且返回全部参数', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final nameController = TextEditingController(
      text: '很长的 Vibe 保存名称用于验证最坏字段组合',
    );
    addTearDown(nameController.dispose);
    final candidate = VibeLibraryEntry(
      id: 'overwrite-candidate',
      name: '原始库条目名称很长',
      vibeDisplayName: '原始库条目名称很长',
      vibeEncoding: 'encoded-before',
      strength: 0.61,
      infoExtracted: 0.27,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      createdAt: DateTime(2026, 4, 15),
    );
    VibeLibrarySaveFormResult? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                unawaited(
                  showVibeLibrarySaveForm(
                    context: context,
                    vibeCount: 16,
                    nameController: nameController,
                    initialStrength: 0.61,
                    initialInfoExtracted: 0.27,
                    showInfoExtractedControl: true,
                    overwriteCandidate: candidate,
                  ).then((value) => result = value),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    final overwrite = find.byKey(const ValueKey('vibe-library-save-overwrite'));
    await tester.ensureVisible(overwrite);
    await tester.tap(overwrite);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vibe-library-save-confirm')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.$1, isTrue);
    expect(result!.$2, 0.61);
    expect(result!.$3, 0.27);
    expect(result!.$4, isTrue);
    expect(nameController.text, '很长的 Vibe 保存名称用于验证最坏字段组合');
    expect(tester.takeException(), isNull);
  });
}
