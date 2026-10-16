import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';

/// 逻辑像素的视口尺寸、软键盘高度与系统安全区
typedef ViewportScenario = ({
  Size size,
  double keyboard,
  FakeViewPadding padding,
});

const responsiveWidths = [320.0, 600.0, 840.0, 1180.0, 1600.0];

/// 手机横屏时刘海与手势条占去的左右安全区
const landscapePadding = FakeViewPadding(left: 32, right: 48);

/// 表单与弹窗的验收视口：各断点宽度、短横屏有无键盘与安全区、更矮的横屏、
/// 竖屏键盘，以及四边都有安全区的竖屏键盘
final formViewports = <ViewportScenario>[
  for (final width in responsiveWidths)
    (size: Size(width, 900), keyboard: 0, padding: FakeViewPadding.zero),
  (size: const Size(740, 360), keyboard: 0, padding: FakeViewPadding.zero),
  (size: const Size(740, 360), keyboard: 160, padding: FakeViewPadding.zero),
  (size: const Size(740, 360), keyboard: 160, padding: landscapePadding),
  (size: const Size(568, 320), keyboard: 120, padding: FakeViewPadding.zero),
  (size: const Size(360, 740), keyboard: 300, padding: FakeViewPadding.zero),
  (
    size: const Size(320, 800),
    keyboard: 280,
    padding: const FakeViewPadding(left: 12, top: 32, right: 20, bottom: 28),
  ),
];

/// 没有安全区的视口，可带软键盘
ViewportScenario plainViewport(Size size, {double keyboard = 0}) =>
    (size: size, keyboard: keyboard, padding: FakeViewPadding.zero);

String describeViewport(ViewportScenario viewport) =>
    '${viewport.size} keyboard=${viewport.keyboard} '
    'padding=${viewport.padding.left}/${viewport.padding.top}';

/// 按逻辑像素设置测试视图，用例结束时还原
void applyViewport(WidgetTester tester, ViewportScenario viewport) {
  tester.view
    ..physicalSize = viewport.size
    ..devicePixelRatio = 1
    ..padding = viewport.padding
    ..viewInsets = FakeViewPadding(bottom: viewport.keyboard);
  addTearDown(tester.view.reset);
}

/// 带本地化与文字缩放的测试应用；不传 [interactionPolicy] 时沿用默认交互策略
Widget localizedTestApp({
  required Widget home,
  Locale locale = const Locale('zh'),
  double textScale = 1,
  InteractionPolicy? interactionPolicy,
  ThemeData? theme,
}) {
  return MaterialApp(
    locale: locale,
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      final scaled = MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
      return interactionPolicy == null
          ? scaled
          : InteractionPolicyScope(
              initialPolicy: interactionPolicy,
              child: scaled,
            );
    },
    home: home,
  );
}

/// 居中放一个按钮，点击后打开被测面板
Widget panelLauncher(String label, void Function(BuildContext context) open) {
  return Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(onPressed: () => open(context), child: Text(label)),
      ),
    ),
  );
}
