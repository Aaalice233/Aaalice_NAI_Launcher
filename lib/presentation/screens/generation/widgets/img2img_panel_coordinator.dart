import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/generation/generation_params_notifier.dart';
import '../../../providers/generation/image_workflow_controller.dart';
import '../../../providers/precise_ref_library_provider.dart';
import '../../../services/image_workflow_launcher.dart';
import '../../../utils/precise_ref_library_import_helper.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/image_editor/image_editor_screen.dart';
import '../../precise_ref_library/widgets/precise_ref_selector_dialog.dart';
import '../../../../data/services/precise_ref_library_storage_service.dart';
import '../../../../core/utils/localization_extension.dart';

final img2ImgPanelCoordinatorProvider = Provider(Img2ImgPanelCoordinator.new);

/// Owns img2img commands. It only reads providers at command boundaries and
/// never depends on a Widget State object.
final class Img2ImgPanelCoordinator {
  Img2ImgPanelCoordinator(this.ref);

  final Ref ref;

  ImageWorkflowController get _workflow =>
      ref.read(imageWorkflowControllerProvider.notifier);

  Future<void> replaceSource(Uint8List bytes) =>
      _workflow.replaceSourceImageAsync(bytes);

  Future<void> pickSource(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes =
          file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes != null) await replaceSource(bytes);
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.img2img_selectFailed('$error'));
      }
    }
  }

  Future<void> saveSourceToLibrary(
    BuildContext context,
    WidgetRef widgetRef,
  ) async {
    final source = ref.read(generationParamsNotifierProvider).sourceImage;
    if (source != null) {
      await saveBytesToPreciseRefLibrary(widgetRef, context, source);
    }
  }

  Future<void> importSourceFromLibrary(BuildContext context) async {
    final selected = await PreciseRefSelectorDialog.show(
      context,
      multiSelect: false,
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;
    final entry = selected.first;
    final bytes = await ref
        .read(preciseRefLibraryStorageServiceProvider)
        .readImageBytes(entry.id);
    if (!context.mounted) return;
    if (bytes == null) {
      AppToast.error(context, context.l10n.preciseRefLib_imageMissing);
      return;
    }
    unawaited(replaceSource(bytes));
    unawaited(
      ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .recordUsage(entry.id),
    );
  }

  Future<void> openBlankCanvas(BuildContext context) async {
    final params = ref.read(generationParamsNotifierProvider);
    final result = await ImageEditorScreen.show(
      context,
      initialSize: Size(params.width.toDouble(), params.height.toDouble()),
      mode: ImageEditorMode.edit,
      title: context.l10n.img2img_drawSketch,
    );
    final image = result?.modifiedImage;
    if (image == null || !context.mounted) return;
    _workflow
      ..replaceSourceImage(image)
      ..setPanelExpanded(true);
  }

  void openEditor(
    BuildContext context,
    WidgetRef widgetRef,
    Uint8List source,
    ImageEditorMode mode,
  ) {
    ImageWorkflowLauncher.openEditor(context, widgetRef, source, mode: mode);
  }

  void generateVariations(
    BuildContext context,
    WidgetRef widgetRef,
    Uint8List source,
  ) {
    ImageWorkflowLauncher.generateVariations(context, widgetRef, source);
  }

  void openDirectorTools(
    BuildContext context,
    WidgetRef widgetRef,
    Uint8List source,
  ) {
    ImageWorkflowLauncher.openDirectorTools(context, widgetRef, source);
  }

  void toggleEnhance(ImageWorkflowState workflow) {
    workflow.isEnhance
        ? _workflow.exitEnhanceMode()
        : _workflow.enterEnhanceMode();
  }

  void toggleUpscale(ImageWorkflowState workflow) {
    workflow.isUpscale
        ? _workflow.exitUpscaleMode()
        : _workflow.enterUpscaleMode();
  }

  void clear() => _workflow.clearSourceImage();
}
