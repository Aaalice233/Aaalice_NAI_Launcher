import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Reveals the active search area after layout without mutating scroll state
/// from a parent build method.
class OnlineGallerySearchReveal extends StatefulWidget {
  const OnlineGallerySearchReveal({
    super.key,
    required this.enabled,
    required this.signature,
    required this.revealKey,
    required this.child,
  });

  final bool enabled;
  final String signature;
  final GlobalKey revealKey;
  final Widget child;

  @override
  State<OnlineGallerySearchReveal> createState() =>
      _OnlineGallerySearchRevealState();
}

class _OnlineGallerySearchRevealState extends State<OnlineGallerySearchReveal> {
  String? _scheduledSignature;

  @override
  void initState() {
    super.initState();
    _scheduleIfNeeded();
  }

  @override
  void didUpdateWidget(covariant OnlineGallerySearchReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleIfNeeded();
  }

  void _scheduleIfNeeded() {
    if (!widget.enabled || _scheduledSignature == widget.signature) return;
    _scheduledSignature = widget.signature;
    _revealAfterLayout(2);
  }

  void _revealAfterLayout(int attemptsRemaining) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled) return;
      final searchContext = widget.revealKey.currentContext;
      if (searchContext == null) return;
      final scrollable = Scrollable.maybeOf(searchContext);
      final searchBox = searchContext.findRenderObject() as RenderBox?;
      final viewport = searchBox == null
          ? null
          : RenderAbstractViewport.maybeOf(searchBox);
      if (scrollable == null ||
          searchBox == null ||
          viewport == null ||
          !scrollable.position.hasContentDimensions) {
        if (attemptsRemaining > 0) {
          _revealAfterLayout(attemptsRemaining - 1);
        }
        return;
      }
      final position = scrollable.position;
      final centeredOffset = viewport.getOffsetToReveal(searchBox, 0.5).offset;
      position.jumpTo(
        centeredOffset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
