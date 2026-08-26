import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/settings_card.dart';
import 'package:nai_launcher/presentation/themes/app_theme.dart';
import 'package:nai_launcher/presentation/widgets/common/compact_icon_button.dart';
import 'package:nai_launcher/presentation/widgets/common/elevated_card.dart';
import 'package:nai_launcher/presentation/widgets/common/inset_shadow_container.dart';
import 'package:nai_launcher/presentation/widgets/common/safe_dropdown.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_container.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_dropdown.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_switch.dart';

void main() {
  testWidgets('普通卡片和设置分组不绘制完整结构边框', (tester) async {
    final theme = AppTheme.getTheme(AppStyle.grungeCollage, Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Column(
            children: [
              ElevatedCard(child: Text('Card')),
              SettingsCard(title: 'Settings', child: Text('Content')),
            ],
          ),
        ),
      ),
    );

    final animated = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(ElevatedCard),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = animated.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isEmpty);

    final settingsCard = tester.widget<Card>(
      find.descendant(
        of: find.byType(SettingsCard),
        matching: find.byType(Card),
      ),
    );
    expect(settingsCard.shape, isNull, reason: '应继承 CardTheme，而非局部恢复描边');
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('紧凑按钮无常驻边框且支持键盘激活', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompactIconButton(
            icon: Icons.refresh,
            label: 'Refresh',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.style?.side?.resolve({})?.style, BorderStyle.none);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(pressed, isTrue);
  });

  testWidgets('禁用开关保留明确的不可用视觉状态', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThemedSwitch(value: true, enabled: false, onChanged: (_) {}),
        ),
      ),
    );

    final opacity = tester.widgetList<Opacity>(
      find.descendant(
        of: find.byType(ThemedSwitch),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.any((widget) => widget.opacity == 0.5), isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });

  testWidgets('旧内阴影参数保持构造兼容且不会被误解为禁用控件', (tester) async {
    const background = Color(0xFF123456);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InsetShadowContainer(
            shadowDepth: 0.4,
            shadowBlur: 12,
            enabled: false,
            backgroundColor: background,
            child: Text('Input'),
          ),
        ),
      ),
    );

    final animated = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(InsetShadowContainer),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect((animated.decoration! as BoxDecoration).color, background);
  });

  testWidgets('静态卡片显式启用 hover 时参数仍生效', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedCard(
              enableHoverEffect: true,
              hoverTranslateY: -3,
              child: SizedBox(width: 120, height: 60),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(
      location: tester.getCenter(find.byType(ElevatedCard)),
    );
    await tester.pumpAndSettle();

    final animated = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(ElevatedCard),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(animated.transform!.getTranslation().y, -3);
    await gesture.removePointer();
  });

  testWidgets('圆形语义容器不会同时继承矩形圆角', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ThemedContainer(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(ThemedContainer),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.borderRadius, isNull);
  });

  testWidgets('下拉输入允许全局主题提供焦点和错误状态边界', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(AppStyle.grungeCollage, Brightness.dark),
        home: Scaffold(
          body: Column(
            children: [
              ThemedDropdown<String>(
                value: 'a',
                items: const [DropdownMenuItem(value: 'a', child: Text('A'))],
                onChanged: (_) {},
              ),
              SafeDropdownFormField<String>(
                value: 'a',
                items: const [DropdownMenuItem(value: 'a', child: Text('A'))],
                onChanged: (_) {},
                validator: (_) => 'Error',
              ),
            ],
          ),
        ),
      ),
    );

    final fields = tester.widgetList<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    for (final field in fields) {
      expect(field.decoration.focusedBorder, isNull);
      expect(field.decoration.errorBorder, isNull);
    }
  });

  testWidgets('安全下拉框用状态边界反馈键盘焦点', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeDropdown<String>(
            value: 'a',
            items: const [DropdownMenuItem(value: 'a', child: Text('A'))],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final surface = tester.widget<InsetShadowContainer>(
      find.byType(InsetShadowContainer),
    );
    expect(surface.isFocused, isTrue);
  });
}
