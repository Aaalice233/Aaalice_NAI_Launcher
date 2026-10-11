import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/single_line_text_width.dart';

/// 标签列中的一行：标签（可带一行说明）、控件与可选的尾随内容
class LabeledControlRow {
  const LabeledControlRow({
    required this.label,
    required this.control,
    this.description,
    this.trailing,
  });

  final String label;
  final String? description;
  final Widget control;
  final Widget? trailing;
}

/// 成组的标签列行
///
/// 标签列按实测最宽标签对齐；控件放不下时整组改为标签独占一行，
/// 尾随内容仍放不下时再另起一行。标签不截断，窄屏下允许换行。
class LabeledControlRows extends StatelessWidget {
  const LabeledControlRows({
    super.key,
    required this.rows,
    this.labelStyle,
    this.descriptionStyle,
    this.trailingWidth = 0,
    this.rowPadding = EdgeInsets.zero,
    this.minLabelWidth = 0,
    this.minControlWidth = 120,
    this.columnGap = 0,
  });

  final List<LabeledControlRow> rows;
  final TextStyle? labelStyle;
  final TextStyle? descriptionStyle;

  /// 尾随列的实际宽度；尾随内容随文字缩放时由调用方换算
  final double trailingWidth;
  final EdgeInsets rowPadding;
  final double minLabelWidth;
  final double minControlWidth;

  /// 标签列、控件与尾随列之间的间距
  final double columnGap;

  @override
  Widget build(BuildContext context) {
    final labelWidth = rows.fold(minLabelWidth, (widest, row) {
      final description = row.description;
      return math.max(
        widest,
        math.max(
          singleLineTextWidth(context, row.label, labelStyle),
          description == null
              ? 0.0
              : singleLineTextWidth(context, description, descriptionStyle),
        ),
      );
    });
    final hasTrailing = rows.any((row) => row.trailing != null);
    final trailingWidth = hasTrailing ? this.trailingWidth : 0.0;
    final trailingExtent = hasTrailing ? trailingWidth + columnGap : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - rowPadding.horizontal;
        final arrangement =
            available - labelWidth - columnGap - trailingExtent >=
                minControlWidth
            ? _Arrangement.inline
            : available - trailingExtent >= minControlWidth
            ? _Arrangement.labelAbove
            : _Arrangement.trailingBelow;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in rows)
              Padding(
                padding: rowPadding,
                child: _LabeledControlRowView(
                  row: row,
                  arrangement: arrangement,
                  label: _RowLabel(
                    row: row,
                    labelStyle: labelStyle,
                    descriptionStyle: descriptionStyle,
                  ),
                  labelWidth: labelWidth,
                  trailingWidth: math.min(trailingWidth, available),
                  columnGap: columnGap,
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _Arrangement { inline, labelAbove, trailingBelow }

class _LabeledControlRowView extends StatelessWidget {
  const _LabeledControlRowView({
    required this.row,
    required this.arrangement,
    required this.label,
    required this.labelWidth,
    required this.trailingWidth,
    required this.columnGap,
  });

  final LabeledControlRow row;
  final _Arrangement arrangement;
  final Widget label;
  final double labelWidth;
  final double trailingWidth;
  final double columnGap;

  @override
  Widget build(BuildContext context) {
    final trailing = row.trailing == null
        ? null
        : SizedBox(width: trailingWidth, child: row.trailing);
    return switch (arrangement) {
      _Arrangement.inline => Row(
        spacing: columnGap,
        children: [
          SizedBox(width: labelWidth, child: label),
          Expanded(child: row.control),
          if (trailing != null) trailing,
        ],
      ),
      _Arrangement.labelAbove => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          const SizedBox(height: 4),
          Row(
            spacing: columnGap,
            children: [
              Expanded(child: row.control),
              if (trailing != null) trailing,
            ],
          ),
        ],
      ),
      _Arrangement.trailingBelow => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label,
          const SizedBox(height: 4),
          row.control,
          if (trailing != null)
            Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
        ],
      ),
    };
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({
    required this.row,
    required this.labelStyle,
    required this.descriptionStyle,
  });

  final LabeledControlRow row;
  final TextStyle? labelStyle;
  final TextStyle? descriptionStyle;

  @override
  Widget build(BuildContext context) {
    final description = row.description;
    final label = Text(row.label, style: labelStyle);
    if (description == null) return label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        Text(description, style: descriptionStyle),
      ],
    );
  }
}
