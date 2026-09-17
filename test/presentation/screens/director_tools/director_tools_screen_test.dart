import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/screens/director_tools/director_tools_screen.dart';

import '../../../helpers/light_theme_contrast.dart';

final Uint8List _sourceImage = Uint8List.fromList(
  img.encodePng(img.Image(width: 16, height: 16)),
);

Future<void> _pumpScreen(WidgetTester tester) async {
  // 面板只用订阅态决定 Anlas 徽章，直接钉死，免得把认证链路拖进来。
  final ProviderContainer container = createStorageFreeContainer(
    overrides: <Override>[isOpusSubscriptionProvider.overrideWithValue(false)],
  );
  addTearDown(container.dispose);
  await tester.binding.setSurfaceSize(const Size(1400, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.light(),
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DirectorToolsScreen(sourceImage: _sourceImage),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectPixelSnap(WidgetTester tester) async {
  await tester.tap(find.text('像素对齐'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('像素对齐出现在工具列表里', (WidgetTester tester) async {
    await _pumpScreen(tester);
    expect(find.text('像素对齐'), findsOneWidget);
  });

  testWidgets('选中后显示调色板选择器与两个开关', (WidgetTester tester) async {
    await _pumpScreen(tester);
    await _selectPixelSnap(tester);

    expect(find.text('调色板'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('自动'), findsOneWidget);
    expect(find.text('自定义'), findsOneWidget);
    expect(find.text('不过度细化'), findsOneWidget);
    expect(find.text('放大回原尺寸'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
  });

  testWidgets('本地工具不显示 Anlas 徽章', (WidgetTester tester) async {
    await _pumpScreen(tester);
    await _selectPixelSnap(tester);

    expect(find.byIcon(Icons.diamond_outlined), findsNothing);
  });

  testWidgets('切到自定义才出现色数滑块', (WidgetTester tester) async {
    await _pumpScreen(tester);
    await _selectPixelSnap(tester);

    expect(find.text('色数'), findsNothing);

    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();

    expect(find.text('色数'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('开关文案随状态切换', (WidgetTester tester) async {
    await _pumpScreen(tester);
    await _selectPixelSnap(tester);

    expect(find.text('更细的像素尺寸更贴合原图时会改用它。'), findsOneWidget);

    await tester.tap(find.text('不过度细化'));
    await tester.pumpAndSettle();

    expect(find.text('始终保留检测到的像素尺寸。'), findsOneWidget);
  });
}
