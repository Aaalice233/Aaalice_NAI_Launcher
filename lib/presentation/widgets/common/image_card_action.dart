import 'dart:async';

import 'package:flutter/material.dart';

typedef ImageCardCallback = FutureOr<void> Function();

enum ImageCardActionGroup { view, use, manage, danger }

enum ImageCardActionId {
  viewDetail,
  save,
  copy,
  copyPrompt,
  copyPath,
  copySeed,
  importMetadata,
  addToAgent,
  shareDiscord,
  createWatermark,
  createMosaic,
  saveToLibrary,
  openFolder,
  reversePrompt,
  imageToImage,
  vibeTransfer,
  preciseReference,
  saveToPreciseRefLibrary,
  editImage,
  inpaint,
  generateVariations,
  directorTools,
  enhance,
  dlssEnhance,
  upscale,
  sendToKrita,
  sendToGeneration,
  addToQueue,
  favorite,
  export,
  edit,
  classify,
  addToAlbum,
  removeFromAlbum,
  select,
  delete,
  enable,
  replace,
  markEncodingModel,
}

/// One business action, independent of its button, menu or batch presentation.
@immutable
class ImageCardAction {
  const ImageCardAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.invoke,
    String? menuLabel,
    this.key,
    this.iconColor,
    this.semanticLabel,
    this.visible = true,
    this.enabled = true,
    bool isLoading = false,
    this.disabledReason,
    this.showOnHover = true,
    this.isPrimary = false,
    this.isDanger = false,
    this.supportsBatch = false,
    ImageCardActionGroup? group,
    ImageCardActionRunner? runner,
  }) : _menuLabel = menuLabel,
       _isLoading = isLoading,
       _group = group,
       _runner = runner;

  final ImageCardActionId id;
  final IconData icon;
  final String label;
  final String? _menuLabel;
  final ImageCardCallback invoke;
  final Key? key;
  final Color? iconColor;
  final String? semanticLabel;
  final bool visible;
  final bool enabled;
  final bool _isLoading;
  final String? disabledReason;
  final bool showOnHover;
  final bool isPrimary;
  final bool isDanger;
  final bool supportsBatch;
  final ImageCardActionGroup? _group;
  final ImageCardActionRunner? _runner;

  String get menuLabel => _menuLabel ?? label.split('\n').first;
  bool get isLoading => _isLoading || (_runner?.isRunning(id) ?? false);
  bool get canInvoke => visible && enabled && !isLoading;
  ImageCardActionGroup get group =>
      _group ??
      switch (id) {
        ImageCardActionId.viewDetail ||
        ImageCardActionId.copy ||
        ImageCardActionId.copyPrompt ||
        ImageCardActionId.copyPath ||
        ImageCardActionId.copySeed ||
        ImageCardActionId.openFolder ||
        ImageCardActionId.select => ImageCardActionGroup.view,
        ImageCardActionId.save ||
        ImageCardActionId.saveToLibrary ||
        ImageCardActionId.saveToPreciseRefLibrary ||
        ImageCardActionId.favorite ||
        ImageCardActionId.export ||
        ImageCardActionId.classify ||
        ImageCardActionId.addToAlbum ||
        ImageCardActionId.removeFromAlbum => ImageCardActionGroup.manage,
        ImageCardActionId.delete => ImageCardActionGroup.danger,
        _ => isDanger ? ImageCardActionGroup.danger : ImageCardActionGroup.use,
      };

  ImageCardAction bind(ImageCardActionRunner runner) => ImageCardAction(
    id: id,
    icon: icon,
    label: label,
    menuLabel: _menuLabel,
    invoke: () => runner.run(this),
    key: key,
    iconColor: iconColor,
    semanticLabel: semanticLabel,
    visible: visible,
    enabled: enabled,
    isLoading: _isLoading,
    disabledReason: disabledReason,
    showOnHover: showOnHover,
    isPrimary: isPrimary,
    isDanger: isDanger,
    supportsBatch: supportsBatch,
    group: group,
    runner: runner,
  );
}

/// Owned by a mounted card, never shared between unrelated resources.
class ImageCardActionRunner extends ChangeNotifier {
  final Set<ImageCardActionId> _running = {};
  bool _disposed = false;

  bool isRunning(ImageCardActionId id) => _running.contains(id);

  Future<void> run(ImageCardAction action) async {
    // Closing a menu may rebuild its source card. Its captured, confirmed
    // operation must still run; only notifications depend on widget lifetime.
    if (!action.canInvoke || !_running.add(action.id)) return;
    if (!_disposed) notifyListeners();
    try {
      await action.invoke();
    } finally {
      _running.remove(action.id);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

List<ImageCardAction> orderedImageCardActions(
  Iterable<ImageCardAction> actions,
) {
  final visible = actions.where((action) => action.visible).toList();
  assert(
    visible.map((a) => a.id).toSet().length == visible.length,
    'A card must define each action only once.',
  );
  return [
    for (final group in ImageCardActionGroup.values)
      ...visible.where((action) => action.group == group),
  ];
}

class ImageCardBatchResult<T> {
  const ImageCardBatchResult({required this.succeeded, required this.failures});

  final List<T> succeeded;
  final Map<T, ({Object error, StackTrace stackTrace})> failures;

  void requireComplete() {
    if (failures.isNotEmpty) throw ImageCardBatchException(this);
  }

  static Future<ImageCardBatchResult<T>> execute<T>(
    Iterable<T> targets,
    Future<void> Function(T) operation,
  ) async {
    final succeeded = <T>[];
    final failures = <T, ({Object error, StackTrace stackTrace})>{};
    for (final target in List<T>.of(targets)) {
      try {
        await operation(target);
        succeeded.add(target);
      } catch (error, stackTrace) {
        failures[target] = (error: error, stackTrace: stackTrace);
      }
    }
    return ImageCardBatchResult(
      succeeded: List.unmodifiable(succeeded),
      failures: Map.unmodifiable(failures),
    );
  }
}

class ImageCardBatchException<T> implements Exception {
  const ImageCardBatchException(this.result);
  final ImageCardBatchResult<T> result;

  @override
  String toString() =>
      '${result.failures.length}/${result.succeeded.length + result.failures.length}: '
      '${result.failures.values.map((failure) => failure.error).join('; ')}';
}
