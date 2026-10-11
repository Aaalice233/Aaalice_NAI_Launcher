import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/library_export/library_export_controls.dart';

void main() {
  testWidgets('进度视图呈现进度值与阶段文案', (tester) async {
    await _pump(
      tester,
      const LibraryExportProgressView(progress: 0.42, message: '正在压缩...'),
    );

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 0.42);
    expect(find.text('正在压缩...'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('缩略图开关回传新值', (tester) async {
    bool? received;
    await _pump(
      tester,
      LibraryExportThumbnailOption(
        title: '包含预览图',
        subtitle: '导出文件会更大',
        value: true,
        onChanged: (value) => received = value,
      ),
    );

    expect(find.text('包含预览图'), findsOneWidget);
    expect(find.text('导出文件会更大'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(received, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计项默认使用主色，可按语义覆盖', (tester) async {
    await _pump(
      tester,
      const Row(
        children: [
          LibraryExportStatItem(
            label: '条目',
            value: '2/3',
            icon: Icons.article_outlined,
          ),
          LibraryExportStatItem(
            label: '不可导出',
            value: '1',
            icon: Icons.error_outline,
            color: Color(0xFFB3261E),
          ),
        ],
      ),
    );

    final colorScheme = Theme.of(
      tester.element(find.byType(Row).first),
    ).colorScheme;
    expect(
      tester.widget<Icon>(find.byIcon(Icons.article_outlined)).color,
      colorScheme.primary,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
      const Color(0xFFB3261E),
    );
    expect(find.text('2/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 1600.0]) {
    testWidgets('${width.toInt()} 宽与 3x 文本下共用控件不溢出', (tester) async {
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LibraryExportProgressView(
              progress: 0.5,
              message: '正在导出一个名字非常非常长的条目以验证换行与截断表现',
            ),
            LibraryExportThumbnailOption(
              title: '包含预览图',
              subtitle: '导出文件会更大，但可以保留缩略图',
              value: false,
              onChanged: (_) {},
            ),
          ],
        ),
        width: width,
        textScaler: const TextScaler.linear(3),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 600,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    ),
  );
}
