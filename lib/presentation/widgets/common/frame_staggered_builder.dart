import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../app_branch_visibility.dart';

/// Materializes expensive siblings one per rendered frame.
///
/// The surrounding lazy list still owns its complete item set and geometry;
/// only each visible item's expensive subtree is deferred. Hidden branches do
/// not consume admissions, and already-materialized children keep their state.
class FrameStaggerController {
  final Queue<_FrameBuildRequest> _requests = Queue<_FrameBuildRequest>();
  final Set<Object> _queuedKeys = <Object>{};
  bool _frameScheduled = false;
  bool _disposed = false;

  void enqueue({
    required Object key,
    required VoidCallback materialize,
    required bool Function() isCancelled,
  }) {
    if (_disposed || !_queuedKeys.add(key)) return;
    _requests.add(
      _FrameBuildRequest(
        key: key,
        materialize: materialize,
        isCancelled: isCancelled,
      ),
    );
    _scheduleFrame();
  }

  void _scheduleFrame() {
    if (_disposed || _frameScheduled || _requests.isEmpty) return;
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (_disposed) return;

      while (_requests.isNotEmpty) {
        final request = _requests.removeFirst();
        _queuedKeys.remove(request.key);
        if (request.isCancelled()) continue;
        request.materialize();
        break;
      }
      _scheduleFrame();
    });
  }

  void dispose() {
    _disposed = true;
    _requests.clear();
    _queuedKeys.clear();
  }
}

class FrameStaggeredChild extends StatefulWidget {
  const FrameStaggeredChild({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.child,
  });

  final FrameStaggerController controller;
  final Widget placeholder;
  final Widget child;

  @override
  State<FrameStaggeredChild> createState() => _FrameStaggeredChildState();
}

class _FrameStaggeredChildState extends State<FrameStaggeredChild> {
  bool _materialized = false;
  bool _branchVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _branchVisible = AppBranchVisibility.of(context);
    _requestMaterialization();
  }

  @override
  void didUpdateWidget(FrameStaggeredChild oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _requestMaterialization();
    }
  }

  void _requestMaterialization() {
    if (_materialized || !_branchVisible) return;
    widget.controller.enqueue(
      key: this,
      materialize: () {
        if (mounted && _branchVisible && !_materialized) {
          setState(() => _materialized = true);
        }
      },
      isCancelled: () => !mounted || !_branchVisible || _materialized,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _materialized ? widget.child : widget.placeholder;
  }
}

class _FrameBuildRequest {
  const _FrameBuildRequest({
    required this.key,
    required this.materialize,
    required this.isCancelled,
  });

  final Object key;
  final VoidCallback materialize;
  final bool Function() isCancelled;
}
