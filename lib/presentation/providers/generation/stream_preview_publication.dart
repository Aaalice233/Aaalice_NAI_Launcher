import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/image/image_stream_chunk.dart';
import 'stream_preview_decode.dart';

typedef StreamPreviewLifecycleReader = AppLifecycleState? Function();

final streamPreviewLifecycleReaderProvider =
    Provider<StreamPreviewLifecycleReader>(
      (ref) =>
          () => WidgetsBinding.instance.lifecycleState,
    );

class StreamPreviewPublication {
  StreamPreviewPublication({required this.resolve, required this.lifecycle});

  final StreamPreviewImageResolver resolve;
  final StreamPreviewLifecycleReader lifecycle;
  final _slots = <Object, _PreviewSlot>{};
  final _closed = <Object>{};
  var _arrival = 0;
  var _published = 0;
  var _releaseScheduled = false;

  bool get _visible => switch (lifecycle()) {
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
    _ => true,
  };

  void add({
    required Object slot,
    required StreamPreviewFrame? frame,
    required bool Function() isCurrent,
    required void Function(bool latest) publish,
  }) {
    if (_closed.contains(slot) || !isCurrent()) return;
    final entry = _slots.putIfAbsent(slot, _PreviewSlot.new);
    _start(entry, _Publication(slot, ++_arrival, frame, isCurrent, publish));
  }

  void _start(_PreviewSlot slot, _Publication publication) {
    final frame = publication.frame;
    if (frame == null || !_visible) {
      slot.waiting = null;
      _publish(slot, publication, null);
    } else if (slot.pending.length == 2) {
      // 不取消较早的解码，避免慢机器上被连续到达的分块饿死。
      slot.waiting = publication;
    } else {
      final decoded = StreamPreviewDecode(frame, resolve);
      slot.pending.add(decoded);
      unawaited(_decoded(slot, publication, decoded));
    }
  }

  Future<void> _decoded(
    _PreviewSlot slot,
    _Publication publication,
    StreamPreviewDecode decoded,
  ) async {
    await decoded.ready;
    slot.pending.remove(decoded);
    _publish(slot, publication, decoded);
    final waiting = slot.waiting;
    slot.waiting = null;
    if (identical(_slots[publication.slot], slot) && waiting != null) {
      _start(slot, waiting);
    }
  }

  void _publish(
    _PreviewSlot slot,
    _Publication publication,
    StreamPreviewDecode? decoded,
  ) {
    if (!identical(_slots[publication.slot], slot) ||
        !publication.isCurrent() ||
        publication.sequence <= slot.published) {
      decoded?.dispose();
      return;
    }
    slot.published = publication.sequence;
    final latest = publication.sequence > _published;
    if (latest) _published = publication.sequence;
    slot.held?.dispose();
    slot.held = decoded;
    publication.publish(latest);
    if (decoded != null) _releaseAfterFrame();
  }

  void _releaseAfterFrame() {
    if (_releaseScheduled) return;
    _releaseScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _releaseScheduled = false;
      for (final slot in _slots.values) {
        slot.held?.dispose();
        slot.held = null;
      }
    });
  }

  void closeSlot(Object key) {
    _closed.add(key);
    _slots.remove(key)?.dispose();
  }

  void markGlobalPublished() => _published = _arrival;

  void clear() {
    final slots = _slots.values.toList();
    _slots.clear();
    _closed.clear();
    for (final slot in slots) {
      slot.dispose();
    }
  }
}

class _PreviewSlot {
  var published = 0;
  final pending = <StreamPreviewDecode>{};
  StreamPreviewDecode? held;
  _Publication? waiting;

  void dispose() {
    held?.dispose();
    held = null;
    waiting = null;
    for (final decoded in pending) {
      decoded.dispose();
    }
    pending.clear();
  }
}

class _Publication {
  _Publication(
    this.slot,
    this.sequence,
    this.frame,
    this.isCurrent,
    this.publish,
  );

  final Object slot;
  final int sequence;
  final StreamPreviewFrame? frame;
  final bool Function() isCurrent;
  final void Function(bool latest) publish;
}
