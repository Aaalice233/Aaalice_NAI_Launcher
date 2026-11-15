import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../utils/card_drop_reader.dart';
import '../../../utils/native_drop_callback.dart';
import '../../common/app_toast.dart';
import '../core/editor_state.dart';
import '../image_editor_controller.dart';
import '../widgets/editor_image_import.dart';

/// 承接桌面端外部图片与卡片拖放区域，将拖入的图片导入为图层。
class EditorImageDropRegion extends StatelessWidget {
  const EditorImageDropRegion({
    super.key,
    required this.disableDropRegion,
    required this.isImporting,
    required this.onPerformDrop,
    required this.child,
  });

  final bool disableDropRegion;
  final bool Function() isImporting;
  final Future<void> Function(PerformDropEvent event) onPerformDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (disableDropRegion ||
        !PlatformCapabilities.current.supportsExternalFileDrop) {
      return child;
    }

    return DropRegion(
      formats: cardDropFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        if (isImporting()) {
          return DropOperation.none;
        }

        if (!const CardDropPolicy().accepts(event.session.items)) {
          return DropOperation.none;
        }

        return event.session.allowedOperations.contains(DropOperation.copy)
            ? DropOperation.copy
            : DropOperation.none;
      },
      onPerformDrop: (event) => releaseNativeDropCallback(
        () => onPerformDrop(event),
        library: 'ImageEditorWorkspace',
      ),
      child: child,
    );
  }
}

Future<void> handleDroppedImageLayerDrop(
  BuildContext context,
  PerformDropEvent event, {
  required ImageEditorController session,
  required EditorState state,
  required bool Function() isMounted,
  required void Function(VoidCallback fn) updateState,
}) async {
  if (session.isImportingDroppedImage) {
    return;
  }

  updateState(() => session.isImportingDroppedImage = true);
  try {
    final resources = await readCardDrop(context, event.session.items);
    for (final resource in resources) {
      if (!isMounted() || !context.mounted) return;
      await importDroppedImageLayer(
        context,
        resource.image.fileName,
        resource.image.bytes,
        state: state,
        isMounted: isMounted,
        updateState: updateState,
      );
    }
  } catch (error, stack) {
    AppLogger.e('Image layer drop failed', error, stack, 'ImageEditorDrop');
    if (isMounted() && context.mounted) {
      AppToast.error(
        context,
        '${context.l10n.toast_unreadableDroppedImageSource}: $error',
      );
    }
  } finally {
    if (isMounted()) {
      updateState(() => session.isImportingDroppedImage = false);
    } else {
      session.isImportingDroppedImage = false;
    }
  }
}

Future<void> importDroppedImageLayer(
  BuildContext context,
  String fileName,
  Uint8List imageBytes, {
  required EditorState state,
  required bool Function() isMounted,
  required void Function(VoidCallback fn) updateState,
}) async {
  if (!isMounted() || !context.mounted) {
    return;
  }

  // 保留原图作为图片层插在当前图层上方，并带着变换框等待摆放
  final placed = await importImageAsLayer(
    context,
    state,
    bytes: imageBytes,
    layerName: droppedImageLayerName(fileName),
  );
  if (!placed || !isMounted()) {
    return;
  }
  state.clearPreview();
  state.requestUiUpdate();
  updateState(() {});
}

String droppedImageLayerName(String fileName) {
  final trimmed = fileName.trim();
  return trimmed.isEmpty ? 'dropped_image.png' : trimmed;
}
