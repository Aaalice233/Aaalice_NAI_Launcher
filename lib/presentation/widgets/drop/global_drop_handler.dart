import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/platform/platform_capabilities.dart';
import 'global_drop_action_coordinator.dart';
import 'global_drop_controller.dart';
import 'global_drop_overlay.dart';

export 'dropped_image_inspector.dart'
    show
        DroppedImageInspection,
        DroppedImageInspector,
        DroppedImageMetadataDetection,
        detectDroppedImageMetadata,
        detectImportableDroppedImageMetadata,
        imageDestinationRequiresOriginalBytes;
export 'global_drop_action_coordinator.dart'
    show GlobalDropActionCoordinator, appendDroppedCharacterReference;
export 'global_drop_controller.dart' show GlobalDropController;

class _PasteImageIntent extends Intent {
  const _PasteImageIntent();
}

/// 包装应用内容并提供全局图片拖放与粘贴入口。
class GlobalDropHandler extends ConsumerStatefulWidget {
  const GlobalDropHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GlobalDropHandler> createState() => _GlobalDropHandlerState();
}

class _GlobalDropHandlerState extends ConsumerState<GlobalDropHandler> {
  late final GlobalDropActionCoordinator _actionCoordinator;
  late final GlobalDropController _controller;

  @override
  void initState() {
    super.initState();
    _actionCoordinator = GlobalDropActionCoordinator(
      context: context,
      ref: ref,
    );
    _controller = GlobalDropController(
      readDrop: _actionCoordinator.readDrop,
      processFile: _actionCoordinator.processDroppedFile,
    )..addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  VoidCallback? _createTextPasteFallback(BuildContext? focusedContext) {
    if (focusedContext == null) return null;
    return () {
      if (!focusedContext.mounted) return;
      Actions.maybeInvoke(
        focusedContext,
        const PasteTextIntent(SelectionChangedCause.keyboard),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        widget.child,
        if (_controller.isDragging) const GlobalDropOverlay(),
        if (_controller.isProcessing) const GlobalDropProcessingOverlay(),
      ],
    );
    final dropTarget = PlatformCapabilities.current.supportsExternalFileDrop
        ? DropRegion(
            formats: Formats.standardFormats,
            hitTestBehavior: HitTestBehavior.opaque,
            onDropOver: _controller.onDropOver,
            onDropLeave: _controller.onDropLeave,
            onPerformDrop: _controller.onPerformDrop,
            child: content,
          )
        : content;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _PasteImageIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, meta: true):
            _PasteImageIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _PasteImageIntent: CallbackAction<_PasteImageIntent>(
            onInvoke: (intent) {
              final fallbackTextPaste = _createTextPasteFallback(
                FocusManager.instance.primaryFocus?.context,
              );
              unawaited(_controller.handlePasteShortcut(fallbackTextPaste));
              return null;
            },
          ),
        },
        child: dropTarget,
      ),
    );
  }
}
