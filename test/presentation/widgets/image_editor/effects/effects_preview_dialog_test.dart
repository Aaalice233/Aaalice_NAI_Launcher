import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/effects/editor_effects.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/effects/effects_preview_dialog.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_processing_service.dart';

void main() {
  late Uint8List sourceBytes;
  late _RecordingProcessingService processingService;

  setUp(() {
    sourceBytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4)),
    );
    processingService = _RecordingProcessingService(sourceBytes);
  });

  testWidgets(
    'removing the dialog immediately does not setState after dispose',
    (tester) async {
      await tester.pumpWidget(_wrapDialog(sourceBytes, processingService));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(processingService.applyCalls, 0);
    },
  );

  testWidgets(
    'the first frame matches the source preview before showing loading',
    (tester) async {
      await tester.pumpWidget(_wrapDialog(sourceBytes, processingService));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(processingService.applyCalls, 0);

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(processingService.applyCalls, 0);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Widget _wrapDialog(
  Uint8List sourceBytes,
  ImageEditorProcessingService processingService,
) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: EffectsPreviewDialog(
        sourceBytes: sourceBytes,
        cropRect: null,
        processingService: processingService,
      ),
    ),
  );
}

class _RecordingProcessingService extends ImageEditorProcessingService {
  _RecordingProcessingService(this.bytes);

  final Uint8List bytes;
  int applyCalls = 0;

  @override
  Future<EditorEffectResult> applyEffect(EditorEffectJob job) async {
    applyCalls++;
    return EditorEffectResult(bytes: bytes, width: 4, height: 4);
  }
}
