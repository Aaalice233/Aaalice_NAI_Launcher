import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/focused_inpaint_input_exception.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/image/image_params.dart';
import 'generation_params_notifier.dart';
import 'generation_request_preparation_service.dart';
import 'image_workflow_controller.dart';

typedef FocusedRequestInput = ({
  Uint8List source,
  Uint8List mask,
  Rect? selection,
  Rect? crop,
  double padding,
});

extension FocusedRequestInputForGeneration on GenerationFocusedSnapshot {
  FocusedRequestInput? inputFor(ImageParams params) =>
      !enabled || !params.isInpainting
      ? null
      : (
          source: params.sourceImage!,
          mask: params.maskImage!,
          selection: selectionRect,
          crop: contextCrop,
          padding: minimumContextMegaPixels,
        );
}

Future<FocusedInpaintGeometry?> resolveFocusedRequestGeometry(
  FocusedRequestInput input,
) async {
  final geometry = await FocusedInpaintUtils.resolveRequestGeometryAsync(
    sourceImage: input.source,
    maskImage: input.mask,
    focusedSelectionRect: input.selection,
    contextCrop: input.crop,
    minContextMegaPixels: input.padding,
  );
  if (geometry == null && input.crop != null) {
    throw const FocusedInpaintInputException.invalidCrop();
  }
  return geometry;
}

NaiGenerationResolutionIssue? validateRequestResolution(
  int width,
  int height,
  FocusedInpaintGeometry? geometry,
) => NaiResolutionAdapter.validateGenerationResolution(
  geometry?.requestWidth ?? width,
  geometry?.requestHeight ?? height,
);

final focusedRequestGeometryProvider = Provider.autoDispose
    .family<Future<FocusedInpaintGeometry?>, FocusedRequestInput>(
      (ref, input) => resolveFocusedRequestGeometry(input),
    );

final generationPageRequestGeometryProvider =
    FutureProvider.autoDispose<FocusedInpaintGeometry?>((ref) {
      final focused = ref
          .watch(imageWorkflowControllerProvider)
          .focusedSnapshot;
      final input = ref.watch(
        generationParamsNotifierProvider.select(focused.inputFor),
      );
      return input == null
          ? null
          : ref.watch(focusedRequestGeometryProvider(input));
    });
