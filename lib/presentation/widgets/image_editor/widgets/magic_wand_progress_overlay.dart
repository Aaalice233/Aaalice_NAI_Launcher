import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/services/efficient_vit_sam_service.dart';
import '../controllers/magic_wand_controller.dart';

class MagicWandProgressOverlay extends StatelessWidget {
  const MagicWandProgressOverlay({super.key, required this.controller});

  final MagicWandController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final snapshot = controller.snapshot;
      if (!snapshot.processing) return const SizedBox.shrink();
      return AbsorbPointer(
        child: ColoredBox(
          color: Colors.black26,
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value:
                              snapshot.progress?.stage ==
                                  EfficientVitSamProgressStage.downloadingModels
                              ? snapshot.progress?.fraction
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(_label(context, snapshot.progress?.stage)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  String _label(BuildContext context, EfficientVitSamProgressStage? stage) =>
      switch (stage) {
        EfficientVitSamProgressStage.checkingModels =>
          context.l10n.editor_magicWandModelPreparing,
        EfficientVitSamProgressStage.downloadingModels =>
          context.l10n.editor_magicWandModelDownloading(
            ((controller.snapshot.progress?.fraction ?? 0) * 100).round(),
          ),
        EfficientVitSamProgressStage.loadingModels =>
          context.l10n.editor_magicWandModelLoading,
        EfficientVitSamProgressStage.encodingImage =>
          context.l10n.editor_magicWandEncoding,
        EfficientVitSamProgressStage.decodingMask =>
          context.l10n.editor_magicWandSegmenting,
        EfficientVitSamProgressStage.postprocessingMask =>
          context.l10n.editor_magicWandPostprocessing,
        null => context.l10n.common_loading,
      };
}
