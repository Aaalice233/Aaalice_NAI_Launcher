import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../../core/agent/resources/agent_chat_resource_drag_format.dart';
import '../../../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/tag_library/tag_library_entry_order.dart';
import '../../../../providers/tag_library_page_provider.dart';
import '../../../../utils/card_drag_format.dart';
import '../../../../utils/native_drop_callback.dart';
import '../../../../widgets/common/app_toast.dart';
import 'reorder_edge_auto_scroller.dart';

/// 条目在命中路径上的身份标记，由 EntryReorderItem 挂在卡片外层
@immutable
class EntryReorderTarget {
  const EntryReorderTarget({
    required this.scope,
    required this.entryId,
    required this.axis,
    required this.textDirection,
  });

  final EntryReorderScopeState scope;
  final String entryId;

  /// 网格按左右半区判定前后，列表按上下半区
  final Axis axis;
  final TextDirection textDirection;
}

/// 词库条目拖拽重排：判定落点、驱动边缘自动滚动并提交移动
///
/// 桌面经原生拖放会话，触屏经长按拖动；落点都按真实命中判定，
/// 被吸顶标题遮住的卡片不会成为落点。
class EntryReorderScope extends ConsumerStatefulWidget {
  const EntryReorderScope({
    super.key,
    required this.enabled,
    required this.controller,
    required this.child,
    this.groupedByCategory = false,
  });

  /// 仅自定义排序下启用；停用时结构不变，子树不会重挂
  final bool enabled;

  /// 分组视图：在落点所在分类组内排列，跨组时移入该分类
  final bool groupedByCategory;

  final ScrollController controller;
  final Widget child;

  static EntryReorderScopeState? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_EntryReorderScopeMarker>()
      ?.state;

  @override
  ConsumerState<EntryReorderScope> createState() => EntryReorderScopeState();
}

class EntryReorderScopeState extends ConsumerState<EntryReorderScope>
    with SingleTickerProviderStateMixin {
  static final _formats = [cardDragFormat, agentChatResourceDragFormat];

  final _hovered = ValueNotifier<TagLibraryEntryAnchor?>(null);
  late final _autoScroller = ReorderEdgeAutoScroller(
    vsync: this,
    controller: () => widget.controller,
    onScrolled: _scheduleRehover,
  );
  List<String>? _draggedIds;
  int? _touchPointer;
  Offset? _pointer;

  bool get enabled => widget.enabled;

  /// 当前落点，卡片据此绘制插入线
  ValueListenable<TagLibraryEntryAnchor?> get hovered => _hovered;

  /// 触屏长按拖动开始，[pointer] 是按住卡片的那根手指
  void beginTouchDrag(List<String> entryIds, {required int pointer}) {
    if (!widget.enabled) return;
    _draggedIds = List.unmodifiable(entryIds);
    _touchPointer = pointer;
  }

  @override
  void didUpdateWidget(EntryReorderScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) _endDrag();
  }

  @override
  void dispose() {
    _autoScroller.dispose();
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EntryReorderScopeMarker(
    state: this,
    enabled: widget.enabled,
    child: Listener(
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: DropRegion(
        formats: _formats,
        hitTestBehavior: HitTestBehavior.translucent,
        onDropOver: _handleDropOver,
        onDropLeave: (_) => _hovered.value = null,
        onPerformDrop: _handlePerformDrop,
        // 区域只在接受过拖放时才收到结束通知，监视器每次会话都会收到
        child: DropMonitor(
          formats: _formats,
          hitTestBehavior: HitTestBehavior.translucent,
          onDropOver: _handleMonitorOver,
          onDropLeave: (_) => _autoScroller.stop(),
          onDropEnded: (_) => _endDrag(),
          child: widget.child,
        ),
      ),
    ),
  );

  DropOperation _handleDropOver(DropOverEvent event) {
    final ids = widget.enabled ? _readEntryIds(event.session.items) : null;
    _draggedIds = ids;
    final anchor = _anchorAt(event.position.global);
    _hovered.value = anchor;
    return anchor == null ? DropOperation.none : DropOperation.copy;
  }

  void _handleMonitorOver(MonitorDropOverEvent event) {
    if (!event.isInside ||
        !widget.enabled ||
        _readEntryIds(event.session.items) == null) {
      _autoScroller.stop();
      return;
    }
    _pointer = event.position.global;
    _autoScroller.update(event.position.global, _viewport());
  }

  Future<void> _handlePerformDrop(PerformDropEvent event) {
    final ids = _draggedIds;
    final anchor = _anchorAt(event.position.global);
    _endDrag();
    return releaseNativeDropCallback(
      () => _commit(ids, anchor),
      library: 'EntryReorderScope',
    );
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _touchPointer) return;
    _pointer = event.position;
    _hovered.value = _anchorAt(event.position);
    _autoScroller.update(event.position, _viewport());
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _touchPointer) return;
    final ids = _draggedIds;
    final anchor = _anchorAt(event.position);
    _endDrag();
    unawaited(_commit(ids, anchor));
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer == _touchPointer) _endDrag();
  }

  void _endDrag() {
    _draggedIds = null;
    _touchPointer = null;
    _pointer = null;
    _hovered.value = null;
    _autoScroller.stop();
  }

  // 滚动在下一帧布局后才生效，之前命中的仍是旧位置
  void _scheduleRehover() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final pointer = _pointer;
      if (!mounted || pointer == null) return;
      _hovered.value = _anchorAt(pointer);
    });
  }

  TagLibraryEntryAnchor? _anchorAt(Offset position) {
    final dragged = _draggedIds;
    if (dragged == null || !mounted) return null;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      position,
      View.of(context).viewId,
    );
    for (final hit in result.path) {
      final target = hit.target;
      if (target is! RenderMetaData) continue;
      final marker = target.metaData;
      if (marker is! EntryReorderTarget || !identical(marker.scope, this)) {
        continue;
      }
      if (dragged.contains(marker.entryId)) return null;
      final local = target.globalToLocal(position);
      final size = target.size;
      final after = switch (marker.axis) {
        Axis.vertical => local.dy > size.height / 2,
        Axis.horizontal =>
          (local.dx > size.width / 2) !=
              (marker.textDirection == TextDirection.rtl),
      };
      return (entryId: marker.entryId, after: after);
    }
    return null;
  }

  Rect _viewport() {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _commit(List<String>? ids, TagLibraryEntryAnchor? anchor) async {
    if (!mounted || ids == null || anchor == null) return;
    final notifier = ref.read(tagLibraryPageNotifierProvider.notifier);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final errorLabel = context.l10n.common_error;
    try {
      final moved = await notifier.moveEntries(
        ids,
        anchor: anchor,
        groupedByCategory: widget.groupedByCategory,
      );
      if (moved) unawaited(HapticFeedback.heavyImpact());
    } catch (error, stack) {
      AppLogger.e('Tag library reorder failed', error, stack, 'TagLibrary');
      AppToast.errorOnOverlay(overlay, '$errorLabel: $error');
    }
  }

  /// 整组都是词库条目才接受，混入其他资源时整组拒绝
  static List<String>? _readEntryIds(List<DropItem> items) {
    if (items.isEmpty) return null;
    final ids = <String>[];
    for (final item in items) {
      final reference = decodeLocalAgentResource(item.localData);
      if (reference == null ||
          reference.kind != AgentChatResourceKind.tagLibraryEntry) {
        return null;
      }
      ids.add(reference.resourceId);
    }
    return ids;
  }
}

class _EntryReorderScopeMarker extends InheritedWidget {
  const _EntryReorderScopeMarker({
    required this.state,
    required this.enabled,
    required super.child,
  });

  final EntryReorderScopeState state;
  final bool enabled;

  @override
  bool updateShouldNotify(_EntryReorderScopeMarker oldWidget) =>
      enabled != oldWidget.enabled || !identical(state, oldWidget.state);
}
