import 'dart:async';
import 'dart:io';

import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// Receivers ask from inside their drag callbacks while this platform thread
/// pumps a nested loop, so an export must never wait without bound.
const cardOnDemandFileTimeout = Duration(seconds: 30);

/// Offers a real file path whose contents are exported on first request.
///
/// Receivers repeat the request during one gesture; every request shares the
/// first export, including its failure.
void addCardOnDemandFile(
  DragItem item, {
  required Future<File> Function() export,
  required void Function(Object, StackTrace) reportFailure,
  Duration timeout = cardOnDemandFileTimeout,
}) {
  Future<Uri>? exported;
  Future<Uri> resolve() async {
    try {
      return (await export().timeout(timeout)).uri;
    } catch (error, stack) {
      reportFailure(error, stack);
      rethrow;
    }
  }

  item.add(Formats.fileUri.lazy(() => exported ??= resolve()));
}
