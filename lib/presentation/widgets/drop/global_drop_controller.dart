import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/utils/app_logger.dart';
import '../../utils/dropped_file_reader.dart';
import '../../utils/internal_drag_protocol.dart';

class GlobalDropController extends ChangeNotifier {
  GlobalDropController({
    required Future<List<DroppedFileData>> Function(PerformDropEvent event)
    readDrop,
    required Future<void> Function(DroppedFileData file) processFile,
  }) : _readDrop = readDrop,
       _processFile = processFile;

  final Future<List<DroppedFileData>> Function(PerformDropEvent event)
  _readDrop;
  final Future<void> Function(DroppedFileData file) _processFile;

  bool _isDragging = false;
  bool _isProcessing = false;
  bool _isReadingClipboard = false;
  bool _isDisposed = false;

  bool get isDragging => _isDragging;
  bool get isProcessing => _isProcessing;
  bool get isReadingClipboard => _isReadingClipboard;

  DropOperation onDropOver(DropOverEvent event) {
    final isGalleryInternalDrag = event.session.items.any(
      (item) => isGalleryInternalDragLocalData(item.localData),
    );
    if (isGalleryInternalDrag) return DropOperation.none;
    if (!event.session.allowedOperations.contains(DropOperation.copy)) {
      return DropOperation.none;
    }
    _setDragging(true);
    return DropOperation.copy;
  }

  void onDropLeave(DropEvent event) => _setDragging(false);

  Future<void> onPerformDrop(PerformDropEvent event) async {
    _setDragging(false);
    _setProcessing(true);
    try {
      // The native reader belongs to the drop session. Finish taking all data
      // before returning, but release the OS drag loop before opening dialogs.
      final files = await _readDrop(event);
      unawaited(Future<void>(() => _processDroppedFiles(files)));
    } catch (_) {
      _setProcessing(false);
      rethrow;
    }
  }

  Future<void> handlePasteShortcut(VoidCallback? fallbackTextPaste) async {
    if (_isReadingClipboard || _isProcessing) {
      fallbackTextPaste?.call();
      return;
    }

    _setReadingClipboard(true);
    try {
      final pastedFile = await _safeReadClipboardFile();
      if (pastedFile == null) {
        fallbackTextPaste?.call();
        return;
      }
      await runProcessing(() => _processFile(pastedFile));
    } finally {
      _setReadingClipboard(false);
    }
  }

  Future<void> runProcessing(Future<void> Function() operation) async {
    _setProcessing(true);
    try {
      await operation();
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> _processDroppedFiles(List<DroppedFileData> files) async {
    try {
      for (final file in files) {
        if (_isDisposed) return;
        await _processFile(file);
      }
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'GlobalDropController',
          context: ErrorDescription('while processing acquired dropped images'),
        ),
      );
    } finally {
      _setProcessing(false);
    }
  }

  Future<DroppedFileData?> _safeReadClipboardFile() async {
    try {
      return await _readClipboardFile();
    } catch (error) {
      AppLogger.d(
        'Failed to inspect clipboard for pasted image: $error',
        'ClipboardPaste',
      );
      return null;
    }
  }

  Future<DroppedFileData?> _readClipboardFile() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return null;
    final clipboardReader = await clipboard.read();
    for (final item in clipboardReader.items) {
      final fileData = await DroppedFileReader.read(
        item,
        allowVibeFiles: true,
        allowRemoteImages: false,
        logTag: 'ClipboardPaste',
      );
      if (fileData != null) return fileData;
    }
    return null;
  }

  void _setDragging(bool value) {
    if (_isDragging == value) return;
    _isDragging = value;
    if (!_isDisposed) notifyListeners();
  }

  void _setProcessing(bool value) {
    if (_isProcessing == value) return;
    _isProcessing = value;
    if (!_isDisposed) notifyListeners();
  }

  void _setReadingClipboard(bool value) {
    if (_isReadingClipboard == value) return;
    _isReadingClipboard = value;
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
