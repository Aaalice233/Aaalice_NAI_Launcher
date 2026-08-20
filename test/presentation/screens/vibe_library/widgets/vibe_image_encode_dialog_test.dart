import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_image_encode_dialog.dart';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 1200);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('V3 原图模式不显示编码费用或编码按钮', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const VibeImageEncodeDialog(
          defaultName: 'raw-vibe.png',
          encodeImage: false,
        ),
      ),
    );

    expect(find.text('保存到库'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('编码图片为 Vibe'), findsNothing);
    expect(find.text('开始编码'), findsNothing);
    expect(find.text('编码将消耗 2 Anlas'), findsNothing);
  });

  testWidgets('V4 编码模式保留编码费用提示', (tester) async {
    await tester.pumpWidget(
      _wrap(const VibeImageEncodeDialog(defaultName: 'encoded-vibe.png')),
    );

    expect(find.text('编码图片为 Vibe'), findsOneWidget);
    expect(find.text('开始编码'), findsOneWidget);
    expect(find.text('编码将消耗 2 Anlas'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: Center(child: child)),
  );
}
