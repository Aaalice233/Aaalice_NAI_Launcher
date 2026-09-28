import 'dart:typed_data';

import '../../../providers/generation/image_workflow_controller.dart';
import '../../../providers/generation/generation_params_selectors.dart';

/// Immutable snapshot consumed by the img2img presentation widgets.
final class Img2ImgPanelData {
  const Img2ImgPanelData({required this.params, required this.workflow});

  final Img2ImgPanelViewData params;
  final ImageWorkflowState workflow;

  Uint8List? get sourceImage => params.sourceImage;
  Uint8List? get maskImage => params.maskImage;
  bool get hasSourceImage => sourceImage != null;
  bool get isInpaintReady => workflow.isInpaint && maskImage != null;
}
