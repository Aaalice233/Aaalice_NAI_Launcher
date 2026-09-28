import 'package:dio/dio.dart';

class OnlineGalleryRequestHandle {
  const OnlineGalleryRequestHandle({
    required this.generation,
    required this.cancelToken,
    this.cacheKey,
  });

  final int generation;
  final CancelToken cancelToken;
  final String? cacheKey;
}

class OnlineGalleryLoadCoordinator {
  int _generation = 0;
  CancelToken? _cancelToken;

  int get generation => _generation;
  CancelToken? get activeCancelToken => _cancelToken;

  OnlineGalleryRequestHandle begin({String? cacheKey}) {
    _generation++;
    final previous = _cancelToken;
    if (previous != null && !previous.isCancelled) {
      previous.cancel('Superseded by a newer gallery request');
    }
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    return OnlineGalleryRequestHandle(
      generation: _generation,
      cancelToken: cancelToken,
      cacheKey: cacheKey,
    );
  }

  void cancel([String reason = 'Online gallery request cancelled']) {
    _generation++;
    final current = _cancelToken;
    if (current != null && !current.isCancelled) current.cancel(reason);
    _cancelToken = null;
  }

  bool isCurrent(OnlineGalleryRequestHandle handle, {String? cacheKey}) {
    return handle.generation == _generation &&
        identical(handle.cancelToken, _cancelToken) &&
        !handle.cancelToken.isCancelled &&
        (cacheKey == null ||
            handle.cacheKey == null ||
            handle.cacheKey == cacheKey);
  }

  void dispose() => cancel('Online gallery coordinator disposed');
}
