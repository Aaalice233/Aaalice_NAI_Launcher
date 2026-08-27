import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nai_launcher/presentation/providers/font_provider.dart';
import 'package:nai_launcher/presentation/themes/app_theme.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_text_selection_toolbar.dart';

/// 主题配色对比度守卫。
///
/// 两条防线，对应两种真实出现过的缺陷：
///
/// 1. **配对自洽**：`onXxx` 必须能在 `Xxx` 上读清。ColorScheme 的 getter 会
///    在未定义时回退（`secondaryContainer ?? secondary`、
///    `onSecondaryContainer ?? onSecondary`），多个预设因此让"容器"变成了
///    饱和品牌色又配白字，SegmentedButton 选中态一度只有 2.2:1。
///
/// 2. **组件实渲**：即使 colorScheme 自洽，组件主题仍可能跨族取色。
///    chipTheme 曾把 `selectedColor` 换成 primary 系，却留着 M3 默认的
///    `onSecondaryContainer` 当标签色，11/16 个主题的 Chip 因此浅底白字。
///    这条只有实际渲染才测得出来。
void main() {
  // 构建主题会走到 GoogleFonts 的资源加载，需要先初始化 binding；
  // 同时关掉运行时字体抓取，否则会去 fonts.gstatic.com 拉字体，
  // 在离线环境里抛出的异步异常会把测试判失败。字体不影响配色。
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('主题配色对比度', () {
    testWidgets('所有主题必须挂载统一语义 token', (tester) async {
      for (final style in AppStyle.values) {
        for (final brightness in Brightness.values) {
          final theme = AppTheme.getTheme(style, brightness);
          final extension = theme.extension<AppThemeExtension>();

          expect(
            extension,
            isNotNull,
            reason: '${style.name}/${brightness.name}',
          );
          expect(extension!.controlRadius, greaterThanOrEqualTo(0));
          expect(extension.cardRadius, greaterThanOrEqualTo(0));
          expect(extension.dialogRadius, greaterThanOrEqualTo(0));
          expect(extension.menuRadius, greaterThanOrEqualTo(0));
          expect(
            extension.fastDuration.inMicroseconds,
            lessThanOrEqualTo(extension.normalDuration.inMicroseconds),
          );
          expect(
            extension.normalDuration.inMicroseconds,
            lessThanOrEqualTo(extension.slowDuration.inMicroseconds),
          );
          expect(extension.dividerThickness, greaterThan(0));
          expect(extension.dividerColor.a, lessThan(0.2));
        }
      }
    });

    testWidgets('普通组件保持无描边，输入框使用低对比单层细边界', (tester) async {
      for (final style in AppStyle.values) {
        for (final brightness in Brightness.values) {
          final theme = AppTheme.getTheme(style, brightness);
          final cardShape = theme.cardTheme.shape;
          final outlinedSide = theme.outlinedButtonTheme.style?.side?.resolve(
            {},
          );
          final inputBorder = theme.inputDecorationTheme.enabledBorder;
          final tooltipDecoration = theme.tooltipTheme.decoration;

          expect(
            cardShape,
            isA<RoundedRectangleBorder>(),
            reason: '${style.name}/${brightness.name}',
          );
          expect(
            (cardShape! as RoundedRectangleBorder).side.style,
            BorderStyle.none,
            reason: '${style.name}/${brightness.name} card',
          );
          expect(
            outlinedSide?.style,
            BorderStyle.none,
            reason: '${style.name}/${brightness.name} outlined button',
          );
          expect(
            inputBorder,
            isA<OutlineInputBorder>(),
            reason: '${style.name}/${brightness.name} input type',
          );
          expect(
            (inputBorder! as OutlineInputBorder).borderSide.style,
            BorderStyle.solid,
            reason: '${style.name}/${brightness.name} input border',
          );
          expect(
            inputBorder.borderSide.width,
            lessThan(1),
            reason: '${style.name}/${brightness.name} input border width',
          );
          if (tooltipDecoration is BoxDecoration) {
            expect(
              tooltipDecoration.border,
              isNull,
              reason: '${style.name}/${brightness.name} tooltip',
            );
          }
        }
      }
    });

    // 用 testWidgets 而非 test：构建主题会触发 GoogleFonts 的异步加载，
    // 裸 test 里这些异步异常会逸出并把用例判失败。
    testWidgets('colorScheme 的 onXxx 对 Xxx 必须达 WCAG AA', (tester) async {
      final offenders = <String>[];

      for (final style in AppStyle.values) {
        for (final brightness in Brightness.values) {
          final cs = AppTheme.getTheme(style, brightness).colorScheme;
          final pairs = <String, (Color, Color)>{
            'primary/onPrimary': (cs.primary, cs.onPrimary),
            'primaryContainer/on': (cs.primaryContainer, cs.onPrimaryContainer),
            'secondary/onSecondary': (cs.secondary, cs.onSecondary),
            'secondaryContainer/on': (
              cs.secondaryContainer,
              cs.onSecondaryContainer,
            ),
            'tertiary/onTertiary': (cs.tertiary, cs.onTertiary),
            'tertiaryContainer/on': (
              cs.tertiaryContainer,
              cs.onTertiaryContainer,
            ),
            'error/onError': (cs.error, cs.onError),
            'surface/onSurface': (cs.surface, cs.onSurface),
            'surface/onSurfaceVariant': (cs.surface, cs.onSurfaceVariant),
            'surfaceContainerHighest/onSurfaceVariant': (
              cs.surfaceContainerHighest,
              cs.onSurfaceVariant,
            ),
          };
          for (final pair in pairs.entries) {
            final ratio = contrastRatio(pair.value.$2, pair.value.$1);
            if (ratio < wcagAA) {
              offenders.add(
                '  ${style.name}/${brightness.name} ${pair.key}: '
                '${hexOf(pair.value.$1)} 配 ${hexOf(pair.value.$2)} '
                '= ${ratio.toStringAsFixed(2)}',
              );
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            '以下配对读不清。注意 ColorScheme 未定义的槽位会回退到同族基色，\n'
            '改 onSecondary 会连带影响 onSecondaryContainer：\n'
            '${offenders.join('\n')}',
      );
    });

    testWidgets('常用交互组件的实际渲染必须达 WCAG AA', (tester) async {
      final offenders = <String>[];

      for (final style in AppStyle.values) {
        for (final brightness in Brightness.values) {
          final theme = AppTheme.getTheme(style, brightness);
          for (final probe in _componentProbes.entries) {
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(body: Center(child: probe.value)),
              ),
            );
            await tester.pumpAndSettle();

            final measured = _measure(tester, theme);
            if (measured == null) continue;
            if (measured.ratio < wcagAA) {
              offenders.add(
                '  ${style.name}/${brightness.name}/${probe.key}: '
                '底=${hexOf(measured.background)} 字=${hexOf(measured.foreground)} '
                '= ${measured.ratio.toStringAsFixed(2)}',
              );
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            '以下组件在实际渲染下读不清，多半是组件主题跨族取色\n'
            '（例如背景取 primaryContainer、前景却沿用 M3 默认的\n'
            'onSecondaryContainer）：\n${offenders.join('\n')}',
      );
    });

    // 修配色时很容易顺手把字体弄丢：Chip 对 labelStyle 是"有则取之"而非
    // 合并，主题里一旦传了裸 TextStyle，textTheme.labelLarge 连同字体
    // 都会被顶掉，而颜色检查是发现不了的。
    //
    // 必须两条路径都测：设了自定义字体走 AppTheme._applyFontConfig，
    // 没设则直接用 ThemeComposer 构建的结果，两处任一漏改都会掉字体。
    testWidgets('组件字体必须与 textTheme 一致（用户自定义字体）', (tester) async {
      const fontConfig = FontConfig(
        displayName: 'LXGW ZhenKai GB',
        fontFamily: 'LXGW ZhenKai GB',
        source: FontSource.system,
      );
      final theme = AppTheme.getTheme(
        AppStyle.grungeCollage,
        Brightness.dark,
        fontConfig: fontConfig,
      );
      expect(
        theme.textTheme.labelLarge?.fontFamily,
        fontConfig.fontFamily,
        reason: '前置条件：字体应已进入 textTheme',
      );

      final offenders = await _findFontMismatches(tester, theme);
      expect(offenders, isEmpty, reason: _fontFailureHint(offenders));
    });

    testWidgets('组件字体必须与 textTheme 一致（主题原生字体）', (tester) async {
      final offenders = <String>[];
      for (final style in AppStyle.values) {
        final theme = AppTheme.getTheme(style, Brightness.dark);
        if (theme.textTheme.labelLarge?.fontFamily == null) continue;
        offenders.addAll(
          (await _findFontMismatches(
            tester,
            theme,
          )).map((line) => '  ${style.name}:$line'),
        );
      }
      expect(offenders, isEmpty, reason: _fontFailureHint(offenders));
    });

    // 右键菜单（文本选择工具栏）比一般组件更隐蔽：Flutter 各平台的工具栏
    // 按钮都绕开了主题字体——桌面端与 macOS 用带 `inherit: false` 的常量
    // 样式，Android 则整体替换 TextButton 的 textStyle，都不带 fontFamily。
    // 项目用 buildThemedTextSelectionToolbar 接管按钮把字体补回来。
    testWidgets('右键菜单必须跟随用户字体', (tester) async {
      const fontConfig = FontConfig(
        displayName: 'LXGW ZhenKai GB',
        fontFamily: 'LXGW ZhenKai GB',
        source: FontSource.system,
      );
      final theme = AppTheme.getTheme(
        AppStyle.grungeCollage,
        Brightness.dark,
        fontConfig: fontConfig,
      );
      final expected = theme.textTheme.labelLarge?.fontFamily;

      final offenders = <String>[];
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => buildThemedTextSelectionToolbar(
                  context,
                  anchors: const TextSelectionToolbarAnchors(
                    primaryAnchor: Offset(100, 100),
                  ),
                  buttonItems: [
                    ContextMenuButtonItem(onPressed: () {}, label: '保存到词库'),
                    ContextMenuButtonItem(onPressed: () {}, label: '复制'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fonts = tester
            .widgetList<RichText>(find.byType(RichText))
            .map((rt) => rt.text.style?.fontFamily)
            .where((f) => f != 'MaterialIcons')
            .toSet();
        if (fonts.any((f) => f != expected)) {
          offenders.add('  ${platform.name}: 期望 $expected，实际 $fonts');
        }
      }
      debugDefaultTargetPlatformOverride = null;

      expect(
        offenders,
        isEmpty,
        reason:
            '右键菜单没跟随用户字体。检查是否误用了\n'
            'AdaptiveTextSelectionToolbar.buttonItems——它内部走各平台的\n'
            '.text() 命名构造，那些构造用的是 inherit: false 的常量样式：\n'
            '${offenders.join('\n')}',
      );
    });

    // 运行时守卫只覆盖得到 Flutter 自带组件的默认行为，覆盖不到项目代码里
    // 各处自己传的样式。这里补一条源码扫描。
    //
    // 只列无歧义的属性名：实测确认 InputDecoration 的 hintStyle / labelStyle
    // 走 merge（安全），而同名的 ChipThemeData.labelStyle 是整体替换，正则
    // 区分不了二者，硬扫只会制造虚警。ChipTheme 由上面的运行时用例兜住。
    test('整体替换语义的样式属性不得传裸 TextStyle', () {
      const replacingProps = [
        'selectedLabelTextStyle',
        'unselectedLabelTextStyle',
        'secondaryLabelStyle',
      ];
      final pattern = RegExp(
        '(${replacingProps.join('|')}):\\s*(const\\s+)?TextStyle\\(',
      );

      final offenders = <String>[];
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!pattern.hasMatch(lines[i])) continue;
          offenders.add(
            '  ${file.path.replaceAll(r'\', '/')}:${i + 1}  ${lines[i].trim()}',
          );
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            '这些属性是整体替换而非合并，传裸 TextStyle 会把默认样式连同用户\n'
            '字体一起顶掉。请改成从 theme.textTheme 的对应槽位 copyWith：\n'
            '${offenders.join('\n')}',
      );
    });
  });
}

const double wcagAA = 4.5;

/// 每个探针只渲染一个组件，便于定位背景与前景。
final _componentProbes = <String, Widget>{
  'ChoiceChip选中': const ChoiceChip(
    label: Text('1.5x'),
    selected: true,
    onSelected: _noop,
  ),
  'ChoiceChip未选': const ChoiceChip(
    label: Text('1x'),
    selected: false,
    onSelected: _noop,
  ),
  'FilterChip选中': const FilterChip(
    label: Text('ONNX'),
    selected: true,
    onSelected: _noop,
  ),
  'FilledButton': const FilledButton(onPressed: _noopVoid, child: Text('开始')),
  // showSelectedIcon: false 与项目里的实际用法一致，也避免选中勾
  // （MaterialIcons 字体的 RichText）被当成标签量到。
  'SegmentedButton选中': SegmentedButton<int>(
    segments: const [
      ButtonSegment(value: 1, label: Text('NovelAI')),
      ButtonSegment(value: 2, label: Text('ComfyUI')),
    ],
    selected: const {1},
    onSelectionChanged: _noopSelection,
    showSelectedIcon: false,
  ),
};

void _noop(bool _) {}
void _noopVoid() {}
void _noopSelection(Set<int> _) {}

/// 逐个渲染探针组件，找出字体与 `textTheme.labelLarge` 不一致的。
Future<List<String>> _findFontMismatches(
  WidgetTester tester,
  ThemeData theme,
) async {
  final expected = theme.textTheme.labelLarge?.fontFamily;
  final offenders = <String>[];

  for (final probe in _componentProbes.entries) {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: Center(child: probe.value)),
      ),
    );
    await tester.pumpAndSettle();

    final texts = tester.widgetList<RichText>(
      find.descendant(of: find.byType(Center), matching: find.byType(RichText)),
    );
    if (texts.isEmpty) continue;
    final actual = texts.first.text.style?.fontFamily;
    if (actual != expected) {
      offenders.add('  ${probe.key}: 期望 $expected，实际 $actual');
    }
  }
  return offenders;
}

String _fontFailureHint(List<String> offenders) =>
    '以下组件的字体与 textTheme 不一致。若刚改过 chipTheme，检查两处：\n'
    'ThemeComposer 里 labelStyle / secondaryLabelStyle 是否从 textTheme 派生，\n'
    '以及 AppTheme._applyFontConfig 是否同步了 chipTheme：\n'
    '${offenders.join('\n')}';

typedef _Measurement = ({Color background, Color foreground, double ratio});

/// 读出被测组件的实际前景/背景色。
///
/// 只看 [Center] 之内的 Material，避免把 Scaffold 底色当成按钮背景；
/// 组件自身无实色背景时（如 TextButton）落到页面表面色。
_Measurement? _measure(WidgetTester tester, ThemeData theme) {
  final surface = theme.colorScheme.surface;
  final materials = tester
      .widgetList<Material>(
        find.descendant(
          of: find.byType(Center),
          matching: find.byType(Material),
        ),
      )
      .where((m) => m.color != null && m.color!.a > 0.01)
      .map((m) => m.color!)
      .toList();
  final background = _flatten(
    materials.isNotEmpty ? materials.last : surface,
    surface,
  );

  final texts = tester.widgetList<RichText>(
    find.descendant(of: find.byType(Center), matching: find.byType(RichText)),
  );
  if (texts.isEmpty) return null;

  final foreground = _flatten(
    texts.first.text.style?.color ?? theme.colorScheme.onSurface,
    background,
  );
  return (
    background: background,
    foreground: foreground,
    ratio: contrastRatio(foreground, background),
  );
}

/// WCAG 相对亮度。
double relativeLuminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG 对比度，取值 1.0（同色）到 21.0（黑白）。
double contrastRatio(Color a, Color b) {
  final x = relativeLuminance(a);
  final y = relativeLuminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// 把半透明前景按其背景合成为不透明色，否则对比度算不准。
Color _flatten(Color foreground, Color background) {
  final alpha = foreground.a;
  return Color.from(
    alpha: 1,
    red: foreground.r * alpha + background.r * (1 - alpha),
    green: foreground.g * alpha + background.g * (1 - alpha),
    blue: foreground.b * alpha + background.b * (1 - alpha),
  );
}

String hexOf(Color color) {
  final rgb =
      (color.r * 255).round() << 16 |
      (color.g * 255).round() << 8 |
      (color.b * 255).round();
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
