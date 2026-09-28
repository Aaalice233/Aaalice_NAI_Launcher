import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../core/editor_state.dart';
import '../core/editor_tool_groups.dart';
import '../layers/layer_role.dart';
import 'tool_base.dart';

/// 封闭区域填充：点击蒙版轮廓内部，把整块封闭区域填成蒙版
class ClosedRegionFillTool extends EditorTool {
  static const String toolId = 'closed_region_fill';

  bool _filling = false;

  @override
  String get id => toolId;

  @override
  String get name => 'Closed Region Fill';

  @override
  IconData get icon => Icons.select_all;

  @override
  bool get followsLayerRole => true;

  @override
  bool supportsRole(LayerRole role) => role == LayerRole.mask;

  @override
  bool isEnabledInSession(EditorState state) => state.canFillClosedRegions;

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    // 一次填充要导出整张蒙版，连点时丢弃后续点击
    if (_filling) return;
    _filling = true;
    unawaited(
      state
          .fillClosedRegionAt(event.localPosition)
          .whenComplete(() => _filling = false),
    );
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {}

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {}

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            editorToolLabel(context, this, LayerRole.mask),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.editor_clickInsideClosedRegion,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
