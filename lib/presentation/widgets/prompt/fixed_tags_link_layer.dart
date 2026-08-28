import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_link.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'fixed_tags_dialog_controller.dart';
import 'fixed_tags_dialog_models.dart';

const fixedTagColumnGap = 28.0;
const _anchorInset = 31.0;
const _rowHeight = 64.0;
const _topOffset = 136.0;
const _bottomPadding = 16.0;

class FixedTagLinkAnchor extends StatelessWidget {
  const FixedTagLinkAnchor({
    super.key,
    required this.entry,
    required this.data,
    required this.commands,
    required this.controller,
    required this.mobile,
  });

  final FixedTagEntry entry;
  final FixedTagsDialogViewData data;
  final FixedTagsDialogCommands commands;
  final FixedTagsDialogController controller;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkedEntries = entry.promptType == FixedTagPromptType.positive
        ? data.state.linkedNegativesOf(entry.id)
        : data.state.linkedPositivesOf(entry.id);
    final tooltip = linkedEntries.isEmpty
        ? context.l10n.fixedTags_dragToLink
        : context.l10n.fixedTags_linkedToNames(
            linkedEntries.map((item) => item.displayName).join(', '),
          );
    final visual = SizedBox(
      width: mobile ? 40 : 22,
      height: mobile ? 40 : 22,
      child: Center(
        child: GestureDetector(
          onTap: () => commands.showLinkManager(entry),
          child: Tooltip(
            message: mobile ? context.l10n.fixedTags_manageLinks : tooltip,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 17,
                  color: linkedEntries.isNotEmpty
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.outline,
                ),
                if (linkedEntries.isNotEmpty)
                  Positioned(
                    right: -6,
                    top: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        linkedEntries.length.toString(),
                        style: TextStyle(
                          fontSize: 8,
                          color: theme.colorScheme.onSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mobile) {
      return KeyedSubtree(
        key: ValueKey('fixed-tag-mobile-link-${entry.id}'),
        child: visual,
      );
    }
    if (entry.promptType == FixedTagPromptType.positive) {
      return _FixedTagAnchorMarker(
        key: ValueKey('fixed-tag-link-anchor-${entry.id}'),
        controller: controller,
        promptType: entry.promptType,
        entryId: entry.id,
        child: Draggable<String>(
          data: entry.id,
          feedback: Material(
            color: Colors.transparent,
            child: Icon(
              Icons.link_rounded,
              color: theme.colorScheme.secondary,
              size: 22,
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: visual),
          child: visual,
        ),
      );
    }
    return _FixedTagAnchorMarker(
      key: ValueKey('fixed-tag-link-anchor-${entry.id}'),
      controller: controller,
      promptType: entry.promptType,
      entryId: entry.id,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => data.state.entries.any(
          (candidate) =>
              candidate.id == details.data &&
              candidate.promptType == FixedTagPromptType.positive,
        ),
        onAcceptWithDetails: (details) =>
            commands.createLink(details.data, entry.id),
        builder: (_, candidates, _) => AnimatedScale(
          scale: candidates.isNotEmpty ? 1.25 : 1,
          duration: const Duration(milliseconds: 120),
          child: visual,
        ),
      ),
    );
  }
}

class FixedTagsLinkLayer extends StatelessWidget {
  const FixedTagsLinkLayer({
    super.key,
    required this.positiveEntries,
    required this.negativeEntries,
    required this.data,
    required this.controller,
  });

  final List<FixedTagEntry> positiveEntries;
  final List<FixedTagEntry> negativeEntries;
  final FixedTagsDialogViewData data;
  final FixedTagsDialogController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columnWidth = (constraints.maxWidth - fixedTagColumnGap) / 2;
      return IgnorePointer(
        child: RepaintBoundary(
          child: _FixedTagsLinkLayerMarker(
            controller: controller,
            child: CustomPaint(
              painter: FixedTagLinkPainter(
                positiveEntries: positiveEntries,
                negativeEntries: negativeEntries,
                links: data.state.links,
                isMismatched: data.state.isMismatched,
                color: Theme.of(context).colorScheme.secondary,
                positiveAnchors: controller.collectAnchorCenters(
                  FixedTagPromptType.positive,
                ),
                negativeAnchors: controller.collectAnchorCenters(
                  FixedTagPromptType.negative,
                ),
                positiveAnchorX: columnWidth - _anchorInset,
                negativeAnchorX: columnWidth + fixedTagColumnGap + _anchorInset,
                positiveScrollOffset:
                    controller.positiveListController.hasClients
                    ? controller.positiveListController.offset
                    : 0,
                negativeScrollOffset:
                    controller.negativeListController.hasClients
                    ? controller.negativeListController.offset
                    : 0,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _FixedTagAnchorMarker extends SingleChildRenderObjectWidget {
  const _FixedTagAnchorMarker({
    super.key,
    required this.controller,
    required this.promptType,
    required this.entryId,
    required super.child,
  });

  final FixedTagsDialogController controller;
  final FixedTagPromptType promptType;
  final String entryId;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _FixedTagAnchorRenderBox(controller, promptType, entryId);

  @override
  void updateRenderObject(
    BuildContext context,
    _FixedTagAnchorRenderBox renderObject,
  ) {
    renderObject.update(controller, promptType, entryId);
  }
}

class _FixedTagAnchorRenderBox extends RenderProxyBox {
  _FixedTagAnchorRenderBox(this._controller, this._promptType, this._entryId);

  FixedTagsDialogController _controller;
  FixedTagPromptType _promptType;
  String _entryId;

  void update(
    FixedTagsDialogController controller,
    FixedTagPromptType promptType,
    String entryId,
  ) {
    if (identical(_controller, controller) &&
        _promptType == promptType &&
        _entryId == entryId) {
      return;
    }
    if (attached) _unregister();
    _controller = controller;
    _promptType = promptType;
    _entryId = entryId;
    if (attached) _register();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _register();
  }

  @override
  void detach() {
    _unregister();
    super.detach();
  }

  void _register() => _controller.registerAnchor(_promptType, _entryId, this);

  void _unregister() =>
      _controller.unregisterAnchor(_promptType, _entryId, this);
}

class _FixedTagsLinkLayerMarker extends SingleChildRenderObjectWidget {
  const _FixedTagsLinkLayerMarker({
    required this.controller,
    required super.child,
  });

  final FixedTagsDialogController controller;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _FixedTagsLinkLayerRenderBox(controller);

  @override
  void updateRenderObject(
    BuildContext context,
    _FixedTagsLinkLayerRenderBox renderObject,
  ) {
    renderObject.controller = controller;
  }
}

class _FixedTagsLinkLayerRenderBox extends RenderProxyBox {
  _FixedTagsLinkLayerRenderBox(this._controller);

  FixedTagsDialogController _controller;

  set controller(FixedTagsDialogController value) {
    if (identical(_controller, value)) return;
    if (attached) _controller.unregisterLinkLayer(this);
    _controller = value;
    if (attached) _controller.registerLinkLayer(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.registerLinkLayer(this);
  }

  @override
  void detach() {
    _controller.unregisterLinkLayer(this);
    super.detach();
  }
}

class FixedTagLinkPainter extends CustomPainter {
  const FixedTagLinkPainter({
    required this.positiveEntries,
    required this.negativeEntries,
    required this.links,
    required this.isMismatched,
    required this.color,
    required this.positiveAnchors,
    required this.negativeAnchors,
    required this.positiveAnchorX,
    required this.negativeAnchorX,
    required this.positiveScrollOffset,
    required this.negativeScrollOffset,
  });

  final List<FixedTagEntry> positiveEntries;
  final List<FixedTagEntry> negativeEntries;
  final List<FixedTagLink> links;
  final bool Function(FixedTagLink link) isMismatched;
  final Color color;
  final Map<String, Offset> positiveAnchors;
  final Map<String, Offset> negativeAnchors;
  final double positiveAnchorX;
  final double negativeAnchorX;
  final double positiveScrollOffset;
  final double negativeScrollOffset;

  @override
  void paint(Canvas canvas, Size size) {
    if (positiveEntries.isEmpty || negativeEntries.isEmpty || links.isEmpty) {
      return;
    }
    const clipTop = _topOffset - _rowHeight / 2;
    final clipBottom = size.height - _bottomPadding;
    if (clipBottom <= clipTop) return;
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, clipTop, size.width, clipBottom));
    final positiveIndex = {
      for (var i = 0; i < positiveEntries.length; i++) positiveEntries[i].id: i,
    };
    final negativeIndex = {
      for (var i = 0; i < negativeEntries.length; i++) negativeEntries[i].id: i,
    };
    for (final link in links) {
      final startIndex = positiveIndex[link.positiveEntryId];
      final endIndex = negativeIndex[link.negativeEntryId];
      if (startIndex == null || endIndex == null) continue;
      final start =
          positiveAnchors[link.positiveEntryId] ??
          Offset(
            positiveAnchorX,
            _topOffset + startIndex * _rowHeight - positiveScrollOffset,
          );
      final end =
          negativeAnchors[link.negativeEntryId] ??
          Offset(
            negativeAnchorX,
            _topOffset + endIndex * _rowHeight - negativeScrollOffset,
          );
      if (!_visible(start.dy, size.height) && !_visible(end.dy, size.height)) {
        continue;
      }
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx + 28, start.dy, end.dx - 28, end.dy, end.dx, end.dy);
      final paint = Paint()
        ..color = color.withValues(alpha: isMismatched(link) ? 0.35 : 0.65)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      if (isMismatched(link)) {
        _drawDashedPath(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  bool _visible(double y, double height) =>
      y >= _topOffset - _rowHeight / 2 && y <= height - _bottomPadding;

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 5;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length).toDouble()),
          paint,
        );
        distance = next + 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant FixedTagLinkPainter oldDelegate) =>
      oldDelegate.positiveEntries != positiveEntries ||
      oldDelegate.negativeEntries != negativeEntries ||
      oldDelegate.links != links ||
      oldDelegate.color != color ||
      oldDelegate.positiveAnchors != positiveAnchors ||
      oldDelegate.negativeAnchors != negativeAnchors ||
      oldDelegate.positiveAnchorX != positiveAnchorX ||
      oldDelegate.negativeAnchorX != negativeAnchorX ||
      oldDelegate.positiveScrollOffset != positiveScrollOffset ||
      oldDelegate.negativeScrollOffset != negativeScrollOffset;
}
