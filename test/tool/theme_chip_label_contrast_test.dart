/// Chip 标签对比度守卫：chip 底色由内部 `Ink` 的 ShapeDecoration 绘制，外层
/// Material 的 color 是 null，只读 Material 的探针会把页面 surface 当成 chip
/// 底色，量不到未选中 chip 真正贴着的 surfaceContainerHighest。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nai_launcher/presentation/themes/app_theme.dart';

// 复用同目录守卫里的 WCAG 算法，避免两套对比度实现给出不同结论。
import 'theme_color_contrast_test.dart' show contrastRatio, hexOf, wcagAA;

void main() {
  // 构建主题会走 GoogleFonts 的资源加载，需要 binding；关掉运行时抓取避免
  // 离线环境里异步异常判失败。字体不影响配色。
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Chip 标签可读性', () {
    testWidgets('中性底 chip 的标签在所有主题下必须达 WCAG AA', (tester) async {
      final wrongSurface = <String>[];
      final offenders = <String>[];

      for (final style in AppStyle.values) {
        for (final brightness in Brightness.values) {
          final theme = AppTheme.getTheme(style, brightness);
          for (final probe in _neutralChipProbes.entries) {
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(body: Center(child: probe.value)),
              ),
            );
            await tester.pumpAndSettle();

            final label = '${style.name}/${brightness.name}/${probe.key}';
            final measured = _measureChip(tester, theme);

            if (measured == null ||
                measured.fill != theme.colorScheme.surfaceContainerHighest) {
              wrongSurface.add(
                '  $label: 期望 '
                '${hexOf(theme.colorScheme.surfaceContainerHighest)}，'
                '实际 ${measured == null ? '未量到 chip 自身底色' : hexOf(measured.fill)}',
              );
              continue;
            }
            if (measured.ratio < wcagAA) {
              offenders.add(
                '  $label: 底=${hexOf(measured.fill)} '
                '字=${hexOf(measured.foreground)} '
                '= ${measured.ratio.toStringAsFixed(2)}',
              );
            }
          }
        }
      }

      expect(
        wrongSurface,
        isEmpty,
        reason:
            '这些 chip 没有贴在最高阶中性色面上，本用例量到的就不再是设计约定的\n'
            '配对。若确实改了 chipTheme.backgroundColor，请同步更新本守卫：\n'
            '${wrongSurface.join('\n')}',
      );
      expect(
        offenders,
        isEmpty,
        reason:
            '以下 chip 标签读不清。标签色取 onSurfaceVariant，底色取\n'
            'surfaceContainerHighest，两者必须在各自调色板里配到 AA：\n'
            '${offenders.join('\n')}',
      );
    });
  });
}

void _noop(bool _) {}
void _noopVoid() {}

/// 标签走 `labelStyle`、底色走 `backgroundColor` 的 chip 形态。
///
/// 都必须可用：禁用态会落到 M3 默认的 disabled 色，量到的不再是中性色面。
final _neutralChipProbes = <String, Widget>{
  'Chip': const Chip(label: Text('seed')),
  'FilterChip未选': const FilterChip(
    label: Text('ONNX'),
    selected: false,
    onSelected: _noop,
  ),
  'ChoiceChip未选': const ChoiceChip(
    label: Text('1x'),
    selected: false,
    onSelected: _noop,
  ),
  'InputChip': const InputChip(label: Text('tag'), onPressed: _noopVoid),
  'ActionChip': const ActionChip(label: Text('随机'), onPressed: _noopVoid),
};

typedef _ChipMeasurement = ({Color fill, Color foreground, double ratio});

/// 读出 chip 自身绘制的底色与标签色。
///
/// 底色来自 `Ink` 的 ShapeDecoration；量不到就返回 null，不退回页面 surface，
/// 否则守卫会在拿不到真实底色时静默通过。
_ChipMeasurement? _measureChip(WidgetTester tester, ThemeData theme) {
  final decorations = tester
      .widgetList<Ink>(find.byType(Ink))
      .map((ink) => ink.decoration)
      .whereType<ShapeDecoration>();
  if (decorations.isEmpty) return null;
  final fill = decorations.first.color;
  if (fill == null) return null;

  final texts = tester.widgetList<RichText>(
    find.descendant(of: find.byType(Center), matching: find.byType(RichText)),
  );
  if (texts.isEmpty) return null;

  final background = _flatten(fill, theme.colorScheme.surface);
  final foreground = _flatten(
    texts.first.text.style?.color ?? theme.colorScheme.onSurface,
    background,
  );
  return (
    fill: fill,
    foreground: foreground,
    ratio: contrastRatio(foreground, background),
  );
}

/// 把半透明色按其背景合成为不透明色，否则对比度算不准。
Color _flatten(Color foreground, Color background) {
  final alpha = foreground.a;
  return Color.from(
    alpha: 1,
    red: foreground.r * alpha + background.r * (1 - alpha),
    green: foreground.g * alpha + background.g * (1 - alpha),
    blue: foreground.b * alpha + background.b * (1 - alpha),
  );
}
