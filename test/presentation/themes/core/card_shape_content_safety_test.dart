import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/settings_card.dart';
import 'package:nai_launcher/presentation/themes/app_theme.dart';
import 'package:nai_launcher/presentation/themes/design_tokens.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// 卡片圆角的内容安全守卫。
///
/// 卡片用 `Clip.antiAlias` 真实裁剪子树，圆角越大左上角吃掉的横向空间越多。
/// 半径 r 在距顶边 p 处向内吃掉 `r - sqrt(r² - (r-p)²)`，要求它不超过 p，
/// 解得 `r <= (2 + sqrt2) * p`。曾有三套主题把胶囊用的 100px 当卡片圆角，
/// 设置页标题首字被斜切掉。
void main() {
  // 构建主题会触发 GoogleFonts 加载，离线环境下的异步异常会误判成测试失败。
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const contentPadding = DesignTokens.spacingMd;
  const maxSafeRadius = (2 + math.sqrt2) * contentPadding;

  group('卡片圆角不裁内容', () {
    testWidgets('所有主题的卡片圆角都在安全上限内', (tester) async {
      for (final style in AppStyle.values) {
        for (final brightness in Brightness.values) {
          final corners = _cardCorners(AppTheme.getTheme(style, brightness));

          for (final corner in [
            corners.topLeft,
            corners.topRight,
            corners.bottomLeft,
            corners.bottomRight,
          ]) {
            expect(
              corner.x,
              lessThanOrEqualTo(maxSafeRadius),
              reason:
                  '${style.name}/${brightness.name} 卡片圆角 ${corner.x} 超过 '
                  '${maxSafeRadius.toStringAsFixed(1)}，'
                  '${contentPadding}px 内边距处的内容会被裁掉',
            );
          }
        }
      }
    });

    testWidgets('ElevatedCard 取到的圆角与 Card 实渲形状一致', (tester) async {
      for (final style in AppStyle.values) {
        for (final brightness in Brightness.values) {
          final theme = AppTheme.getTheme(style, brightness);

          expect(
            theme.extension<AppThemeExtension>()!.cardRadius,
            _cardCorners(theme).topLeft.x,
            reason: '${style.name}/${brightness.name}',
          );
        }
      }
    });

    testWidgets('设置卡标题在最圆的主题下完整可见', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // 三套曾经把标题裁掉的主题。
      for (final style in [
        AppStyle.fluidSaturated,
        AppStyle.materialYou,
        AppStyle.appleLight,
      ]) {
        final theme = AppTheme.getTheme(style, Brightness.dark);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(24),
                child: SettingsCard(
                  title: '界面呈现',
                  child: SizedBox(height: 240),
                ),
              ),
            ),
          ),
        );

        final card = tester.getRect(find.byType(Card));
        final title = tester.getRect(find.text('界面呈现'));
        final radius = _cardCorners(theme).topLeft.x;
        final dx = title.left - card.left;
        final dy = title.top - card.top;

        expect(
          dx,
          greaterThanOrEqualTo(_cornerInset(radius, dy)),
          reason:
              '${style.name} 圆角 $radius 在 y=$dy 处吃掉 '
              '${_cornerInset(radius, dy).toStringAsFixed(1)}px，'
              '标题左边距只有 ${dx}px',
        );
      }
    });
  });
}

BorderRadius _cardCorners(ThemeData theme) =>
    (theme.cardTheme.shape! as RoundedRectangleBorder).borderRadius.resolve(
      TextDirection.ltr,
    );

/// 半径 [radius] 的圆角在距顶边 [dy] 处向内吃掉的横向距离。
double _cornerInset(double radius, double dy) {
  if (dy >= radius) return 0;
  final chord = radius - dy;
  return radius - math.sqrt(math.max(0, radius * radius - chord * chord));
}
