import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/settings_card.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/settings_page_layout.dart';

void main() {
  testWidgets('settings cards derive their layer from the page surface', (
    tester,
  ) async {
    const scheme = ColorScheme.dark(
      surface: Color(0xFF1A1A1A),
      onSurface: Color(0xFFF0EAD6),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        home: const Scaffold(body: SettingsCard(child: Text('content'))),
      ),
    );

    final card = tester.widget<Card>(find.byType(Card));
    expect(
      card.color,
      Color.alphaBlend(
        scheme.onSurface.withValues(alpha: 0.05),
        scheme.surface,
      ),
    );
  });

  Widget buildSubject({
    required Brightness brightness,
    required double textScale,
  }) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness, colorSchemeSeed: Colors.indigo),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SettingsPageLayout(
              title: 'Page title',
              description:
                  'A description that can wrap onto more than one line.',
              actions: FilledButton(
                onPressed: () {},
                child: const Text('Action'),
              ),
              children: [
                const SettingsCard(
                  title: 'First section',
                  description: 'Section help text',
                  child: ListTile(
                    title: Text('First setting'),
                    trailing: Switch(value: true, onChanged: null),
                  ),
                ),
                SettingsCard(
                  title: 'Second section',
                  trailing: TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text(
                      'Preview the final system prompt before saving',
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(title: Text('Setting 1')),
                      ListTile(title: Text('Setting 2')),
                      ListTile(title: Text('Setting 3')),
                      ListTile(title: Text('Setting 4')),
                      ListTile(title: Text('Setting 5')),
                      ListTile(
                        title: Text(
                          'Bottom setting',
                          key: ValueKey('bottom-setting'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('统一页面和分组色面支持 ${brightness.name} 主题', (tester) async {
      tester.view.physicalSize = const Size(1180, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildSubject(brightness: brightness, textScale: 1),
      );
      await tester.pump();

      final pageLeft = tester.getTopLeft(find.byType(SettingsPageLayout)).dx;
      final cards = find.byType(Card);
      expect(cards, findsNWidgets(2));
      for (final card in cards.evaluate()) {
        final rect = tester.getRect(find.byWidget(card.widget));
        expect(rect.left, pageLeft);
        expect(rect.width, greaterThan(0));
        final widget = card.widget as Card;
        expect(widget.elevation, 0);
        final colorScheme = Theme.of(card).colorScheme;
        expect(
          widget.color,
          Color.alphaBlend(
            colorScheme.onSurface.withValues(alpha: 0.05),
            colorScheme.surface,
          ),
        );
        expect(widget.color, isNot(colorScheme.surface));
        expect(widget.shape, isNull);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [
    Size(320, 640),
    Size(700, 700),
    Size(840, 700),
    Size(1180, 800),
    Size(1600, 900),
  ]) {
    testWidgets('布局在 ${size.width.toInt()} 宽度和放大文本下可滚动且无溢出', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildSubject(brightness: Brightness.light, textScale: 2),
      );
      await tester.pump();

      expect(find.byType(SettingsPageLayout), findsOneWidget);
      expect(find.text('First section'), findsOneWidget);
      expect(find.text('Second section'), findsOneWidget);
      expect(tester.takeException(), isNull);

      if (size.width == 320) {
        final verticalScrollable = find.descendant(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == Axis.vertical,
          ),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        );
        final position = tester
            .state<ScrollableState>(verticalScrollable)
            .position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('bottom-setting')),
          200,
          scrollable: verticalScrollable,
        );
        expect(
          find.byKey(const ValueKey('bottom-setting')).hitTestable(),
          findsOneWidget,
        );
      }
    });
  }
}
