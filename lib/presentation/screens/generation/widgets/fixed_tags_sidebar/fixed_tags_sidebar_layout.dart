import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../adaptive/interaction_policy.dart';
import '../../../../providers/layout_state_provider.dart';
import '../../../../widgets/common/tile_action_button.dart';
import '../sidebar_entry_tile.dart';

const uncategorizedSectionId = '__uncategorized__';
const linkDetachDistance = 36.0;
const fixedTagsPanePadding = EdgeInsets.fromLTRB(8, 0, 8, 8);

bool paneHeaderUsesLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) >= 28;

EdgeInsets paneHeaderPadding(BuildContext context) =>
    paneHeaderUsesLargeText(context)
    ? const EdgeInsets.fromLTRB(8, 2, 4, 2)
    : const EdgeInsets.fromLTRB(10, 8, 6, 6);

double scaledLineExtent(BuildContext context, TextStyle? style) {
  final fontSize = MediaQuery.textScalerOf(
    context,
  ).scale(style?.fontSize ?? 14);
  return fontSize * (style?.height ?? 1.45);
}

// 标题行取名称与计数徽标中较高者，徽标另算自身竖向内边距。
double paneHeaderTitleExtent(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;
  return math.max(
    scaledLineExtent(context, textTheme.labelLarge),
    scaledLineExtent(context, textTheme.labelSmall) + 4,
  );
}

// 文字缩放器可能非线性，就地按标题字号取斜率，压缩比才落在标题真实行高上。
double paneHeaderTextScaleFactor(BuildContext context) {
  final fontSize = Theme.of(context).textTheme.labelLarge?.fontSize ?? 14;
  return MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;
}

// 高度预算与 FixedTagsSidebarPaneHeader 的实际布局必须同源：预算低估会让 FixedTagsSidebarPaneCard 的 Column 溢出。
double paneHeaderExtent(BuildContext context) =>
    math.max(
      paneHeaderTitleExtent(context),
      context.interactionPolicy.minimumControlExtent,
    ) +
    paneHeaderPadding(context).vertical;

double gridCardHeight(BuildContext context) {
  final scaledLabelSize = MediaQuery.textScalerOf(context).scale(14);
  // 底行取链接锚点与操作按钮中较高者：前者看有无精确指针，后者看有无触摸，两条规则会错配。
  final footerExtent = math.max(
    SidebarEntryTile.linkAnchorExtentOf(context),
    TileActionButton.extentOf(context),
  );
  // 带缩略图的卡片最紧：正文只有一行，但正文区仅分到卡片 5/8 高度，按它标定基准。
  const contentInsets = 20.0; // 上下内边距 15 + 正文与底行间距 5
  const singleLineText = 36.0; // 名称 20 + 单行正文 16
  final baseHeight =
      (contentInsets + singleLineText + footerExtent) * 8 / 5 + 12;
  final scaledTextGrowth = (scaledLabelSize - 14).clamp(0.0, double.infinity);
  return baseHeight + scaledTextGrowth * 6;
}

class FixedTagsPaneMetrics {
  const FixedTagsPaneMetrics({
    required this.positiveHeight,
    required this.negativeHeight,
    required this.minimumNegativeHeight,
    required this.maximumNegativeHeight,
  });

  final double positiveHeight;
  final double negativeHeight;
  final double minimumNegativeHeight;
  final double maximumNegativeHeight;
}

FixedTagsPaneMetrics computeFixedTagsPaneMetrics(
  BuildContext context, {
  required double maxHeight,
  required bool hasPositiveEntries,
  required bool hasNegativeEntries,
  required bool isListMode,
  required double requestedNegativeHeight,
}) {
  final dividerHeight = context.interactionPolicy.prefersTouchPresentation
      ? context.interactionPolicy.minimumControlExtent
      : 16.0;
  final usableHeight =
      (maxHeight - fixedTagsPanePadding.vertical - dividerHeight)
          .clamp(0.0, double.infinity)
          .toDouble();
  // 面板头跟随文字缩放，正文下限保持定值：跟着放大会在大字号下抢走用户拖出来的分栏高度。
  final paneHeaderMinimumHeight = paneHeaderExtent(context);
  const populatedMinimumHeight = 138.0;
  final emptyMinimumHeight = paneHeaderMinimumHeight;
  final desiredPositiveMinimum = !hasPositiveEntries
      ? emptyMinimumHeight
      : isListMode
      ? populatedMinimumHeight
      : 274.0;
  final desiredNegativeMinimum = !hasNegativeEntries
      ? emptyMinimumHeight
      : populatedMinimumHeight;
  final headerMinimumTotal = paneHeaderMinimumHeight * 2;
  final bodyBudget = math.max(0.0, usableHeight - headerMinimumTotal);
  final desiredPositiveBody = math.max(
    0.0,
    desiredPositiveMinimum - paneHeaderMinimumHeight,
  );
  final desiredNegativeBody = math.max(
    0.0,
    desiredNegativeMinimum - paneHeaderMinimumHeight,
  );
  final desiredBodyTotal = desiredPositiveBody + desiredNegativeBody;
  final bodyScale = desiredBodyTotal == 0
      ? 0.0
      : math.min(1.0, bodyBudget / desiredBodyTotal);
  final headerScale = math.min(1.0, usableHeight / headerMinimumTotal);
  final positiveMinimumHeight =
      paneHeaderMinimumHeight * headerScale + desiredPositiveBody * bodyScale;
  final negativeMinimumHeight =
      paneHeaderMinimumHeight * headerScale + desiredNegativeBody * bodyScale;
  final maximumNegativeHeight = math.max(
    negativeMinimumHeight,
    usableHeight - positiveMinimumHeight,
  );
  final boundedMaximumNegativeHeight = math.min(
    maximumNegativeHeight,
    fixedTagsNegativePaneMaxHeight,
  );
  final boundedMinimumNegativeHeight = math.min(
    boundedMaximumNegativeHeight,
    math.max(negativeMinimumHeight, fixedTagsNegativePaneMinHeight),
  );
  final negativeHeight = requestedNegativeHeight
      .clamp(boundedMinimumNegativeHeight, boundedMaximumNegativeHeight)
      .toDouble();
  final positiveHeight = usableHeight - negativeHeight;

  return FixedTagsPaneMetrics(
    positiveHeight: positiveHeight,
    negativeHeight: negativeHeight,
    minimumNegativeHeight: boundedMinimumNegativeHeight,
    maximumNegativeHeight: boundedMaximumNegativeHeight,
  );
}
