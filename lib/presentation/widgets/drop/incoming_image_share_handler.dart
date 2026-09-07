import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/incoming_image_share_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../services/incoming_image_share_reader.dart';
import '../../utils/dropped_file_reader.dart';
import '../common/app_toast.dart';
import 'global_drop_action_coordinator.dart';
import 'global_drop_overlay.dart';

class IncomingImageShareHandler extends ConsumerStatefulWidget {
  const IncomingImageShareHandler({
    super.key,
    required this.child,
    this.service,
    this.reader,
    this.processImage,
  });

  final Widget child;
  final IncomingImageShareService? service;
  final IncomingImageShareReader? reader;
  final Future<void> Function(DroppedFileData image)? processImage;

  @override
  ConsumerState<IncomingImageShareHandler> createState() =>
      _IncomingImageShareHandlerState();
}

class _IncomingImageShareHandlerState
    extends ConsumerState<IncomingImageShareHandler>
    with WidgetsBindingObserver {
  late final IncomingImageShareService _service;
  late final IncomingImageShareReader _reader;
  late final StreamSubscription<void> _subscription;
  late final Future<void> Function(DroppedFileData) _processImage;
  bool _draining = false;
  bool _requested = false;
  bool _reading = false;
  Completer<bool>? _resumeWaiter;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? IncomingImageShareService();
    _reader = widget.reader ?? IncomingImageShareReader();
    _processImage =
        widget.processImage ??
        GlobalDropActionCoordinator(
          context: context,
          ref: ref,
          openGenerationAfterAction: true,
          respectCurrentRouteDropTarget: false,
        ).processDroppedFile;
    WidgetsBinding.instance.addObserver(this);
    _subscription = _service.available.listen((_) => _requestDrain());
    _service.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestDrain());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeWaiter?.complete(true);
      _resumeWaiter = null;
      _requestDrain();
    }
  }

  bool get _canPresent =>
      mounted &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  void _requestDrain() {
    _requested = true;
    if (_canPresent && !_draining) unawaited(_drain());
  }

  Future<void> _drain() async {
    _draining = true;
    try {
      do {
        _requested = false;
        while (_canPresent) {
          Map<Object?, Object?>? share;
          try {
            share = await _service.takeNext();
          } catch (error, stackTrace) {
            _reportError(error, stackTrace);
            if (error is PlatformException &&
                error.code == 'image_share_read_failed') {
              continue;
            }
            // A broken platform channel must not become a busy retry loop.
            break;
          }
          if (!mounted || share == null) break;
          await _importShare(share);
        }
      } while (_requested && _canPresent);
    } finally {
      _draining = false;
    }
  }

  Future<void> _importShare(Map<Object?, Object?> share) async {
    setState(() => _reading = true);
    try {
      final image = await _reader.read(share);
      if (!mounted) return;
      if (!_canPresent) {
        _resumeWaiter = Completer<bool>();
        if (!await _resumeWaiter!.future || !mounted) return;
      }
      setState(() => _reading = false);
      await _processImage(image);
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  void _reportError(Object error, StackTrace stackTrace) {
    AppLogger.e(
      'Failed to import shared image',
      error,
      stackTrace,
      'ImageShare',
    );
    if (mounted) {
      AppToast.error(context, context.l10n.metadataImport_processFailed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeWaiter?.complete(false);
    _resumeWaiter = null;
    unawaited(_subscription.cancel());
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [widget.child, if (_reading) const GlobalDropProcessingOverlay()],
  );
}
