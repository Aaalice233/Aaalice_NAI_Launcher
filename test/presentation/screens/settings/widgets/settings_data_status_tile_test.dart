import 'package:nai_launcher/presentation/screens/settings/widgets/settings_data_status_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTile(double width) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: SettingsDataStatusTile(
              leading: const Icon(Icons.translate_outlined, key: Key('icon')),
              title: const Text('ffdkj 简体中文汉化库', key: Key('title')),
              subtitle: const Text(
                '已安装 316325 条 · 版本 66a9c591',
                key: Key('subtitle'),
              ),
              actions: [
                IconButton(
                  key: const Key('refresh'),
                  onPressed: () {},
                  icon: const Icon(Icons.refresh),
                ),
                FilledButton.tonal(
                  key: const Key('repair'),
                  onPressed: () {},
                  child: const Text('修复'),
                ),
                IconButton(
                  key: const Key('delete'),
                  onPressed: () {},
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('窄屏将操作区放到完整元数据下方', (tester) async {
    await tester.pumpWidget(buildTile(390));

    final titleRect = tester.getRect(find.byKey(const Key('title')));
    final subtitleRect = tester.getRect(find.byKey(const Key('subtitle')));
    final refreshRect = tester.getRect(find.byKey(const Key('refresh')));
    final deleteRect = tester.getRect(find.byKey(const Key('delete')));
    final iconRect = tester.getRect(find.byKey(const Key('icon')));

    expect(refreshRect.top, greaterThanOrEqualTo(subtitleRect.bottom));
    expect(refreshRect.left, greaterThan(titleRect.left));
    expect(deleteRect.right, closeTo(390 - 16, 0.01));
    expect(iconRect.top, lessThan(subtitleRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏保留单行尾部操作区', (tester) async {
    await tester.pumpWidget(buildTile(800));

    final titleRect = tester.getRect(find.byKey(const Key('title')));
    final refreshRect = tester.getRect(find.byKey(const Key('refresh')));

    expect(refreshRect.left, greaterThan(titleRect.right));
    expect(refreshRect.center.dy, lessThan(titleRect.bottom + 32));
    expect(tester.takeException(), isNull);
  });
}
