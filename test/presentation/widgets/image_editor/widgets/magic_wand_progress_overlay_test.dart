import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/efficient_vit_sam_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/controllers/magic_wand_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/magic_wand_progress_overlay.dart';

void main() {
  for (final width in [412.0, 320.0]) {
    testWidgets(
      'long Chinese progress fits without overflow at ${width.toInt()}',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final session = ImageEditorController();
        final controller = _ProcessingMagicWandController(session);
        addTearDown(controller.dispose);
        addTearDown(session.dispose);

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MagicWandProgressOverlay(controller: controller),
            ),
          ),
        );
        await tester.pump();

        final constrainedBoxFinder = find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox && widget.constraints.maxWidth == 320,
        );
        expect(constrainedBoxFinder, findsOneWidget);
        final constrainedBox = tester.widget<ConstrainedBox>(
          constrainedBoxFinder,
        );
        expect(constrainedBox.child, isA<Row>());
        expect(find.textContaining('正在下载 EfficientViT-SAM 模型'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _ProcessingMagicWandController extends MagicWandController {
  _ProcessingMagicWandController(ImageEditorController session)
    : super(
        session: session,
        editorState: session.editorState,
        config: const ImageEditorSessionConfig.empty(),
        addMaskLayer: (name) =>
            session.editorState.layerManager.addLayer(name: name),
      );

  @override
  MagicWandSnapshot get snapshot => const MagicWandSnapshot(
    processing: true,
    progress: EfficientVitSamProgress(
      EfficientVitSamProgressStage.downloadingModels,
      fraction: 1,
    ),
  );
}
