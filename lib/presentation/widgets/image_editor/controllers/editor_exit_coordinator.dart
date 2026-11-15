import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../common/app_toast.dart';
import '../core/editor_state.dart';
import '../export/editor_result_exporter.dart';
import '../image_editor_controller.dart';
import '../image_editor_types.dart';
import '../widgets/panels/editor_exit_confirm_dialog.dart';

/// 协调编辑会话的路由退出确认、导出中加载遮罩与结果回传关闭。
class EditorExitCoordinator {
  EditorExitCoordinator({
    required ImageEditorController Function() session,
    required this.resultExporter,
  }) : _session = session;

  final ImageEditorController Function() _session;
  final EditorResultExporter resultExporter;

  ImageEditorController get session => _session();

  EditorState get editorState => session.editorState;

  bool allowRoutePop = false;
  bool _exitDialogVisible = false;

  Future<void> confirmExit(
    BuildContext context, {
    required bool Function() canExportAndClose,
    required bool Function() isMounted,
    required void Function(VoidCallback fn) updateState,
  }) async {
    if (_exitDialogVisible || allowRoutePop) return;

    // 检查是否有修改：检查历史记录或图层内容
    final hasChanges =
        editorState.historyManager.canUndo ||
        editorState.layerManager.layers.any(
          (l) => l.strokes.isNotEmpty || l.baseImage != null,
        );

    if (hasChanges) {
      _exitDialogVisible = true;
      final shouldExit = await EditorExitConfirmDialog.show(
        context,
        canExportAndClose: canExportAndClose,
        onSaveAndExit: () => exportAndClose(
          context,
          canExportAndClose: canExportAndClose,
          isMounted: isMounted,
          updateState: updateState,
        ),
      );
      _exitDialogVisible = false;

      if (shouldExit != true || !context.mounted) return;
    }

    await _completeAndPop(
      context,
      isMounted: isMounted,
      updateState: updateState,
    );
  }

  Future<void> exportAndClose(
    BuildContext context, {
    required bool Function() canExportAndClose,
    required bool Function() isMounted,
    required void Function(VoidCallback fn) updateState,
  }) async {
    if (!isMounted() || !context.mounted) return;
    if (!canExportAndClose()) return;

    bool loadingDialogShown = false;

    try {
      loadingDialogShown = true;
      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (context) => Center(
            child: CircularProgressIndicator(
              value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
            ),
          ),
        ),
      );

      await editorState.pixelReadbacks.idle;
      final result = await resultExporter.exportResult();

      if (isMounted() && context.mounted && loadingDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogShown = false;
      }

      if (isMounted() && context.mounted) {
        await _completeAndPop(
          context,
          isMounted: isMounted,
          updateState: updateState,
          result: result,
        );
      }
    } catch (e, stack) {
      AppLogger.e('Failed to export editor result', e, stack, 'ImageEditor');
      if (isMounted() && context.mounted && loadingDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (isMounted() && context.mounted) {
        AppToast.error(context, context.l10n.editor_exportFailed(e));
      }
    }
  }

  Future<void> _completeAndPop(
    BuildContext context, {
    required bool Function() isMounted,
    required void Function(VoidCallback fn) updateState,
    ImageEditorResult? result,
  }) async {
    if (!isMounted()) return;
    updateState(() => allowRoutePop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (isMounted() && context.mounted) Navigator.of(context).pop(result);
  }
}
