import 'dart:async';

import 'package:flutter/foundation.dart';

/// Native drops finish only after `onPerformDrop` completes, and on Windows that
/// wait never pumps window input. [handling] must issue every native read in
/// its synchronous part: the session disposes its readers once this returns.
Future<void> releaseNativeDropCallback(
  Future<void> Function() handling, {
  required String library,
}) {
  unawaited(
    Future<void>.sync(handling).catchError((Object error, StackTrace stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: library,
          context: ErrorDescription(
            'while handling a drop after its native callback returned',
          ),
        ),
      );
    }),
  );
  return Future<void>.value();
}
