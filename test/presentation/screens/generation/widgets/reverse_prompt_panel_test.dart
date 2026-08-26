import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/providers/reverse_prompt_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/reverse_prompt_panel.dart';

import '../../../../helpers/light_theme_contrast.dart';

void main() {
  testWidgets('删除最后一张反推图后隐藏图像数量徽标', (tester) async {
    final container = createStorageFreeContainer(
      overrides: [
        reversePromptProvider.overrideWith(_SeededReversePromptNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await pumpPanelInLightTheme(
      tester,
      container: container,
      panel: const ReversePromptPanel(),
    );

    expect(find.text('1 张'), findsOneWidget);

    await tester.tap(find.text('反推'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('待添加'), findsNothing);
    expect(find.text('1 张'), findsNothing);
    expect(find.text('保留的反推结果'), findsOneWidget);
  });
}

final Uint8List _testImageBytes = Uint8List.fromList(
  img.encodePng(img.Image(width: 8, height: 8)),
);

class _SeededReversePromptNotifier extends ReversePromptNotifier {
  _SeededReversePromptNotifier(super.ref) {
    state = ReversePromptState(
      images: [
        ReversePromptImage(
          id: 'test-image',
          bytes: _testImageBytes,
          name: 'test.png',
        ),
      ],
      finalPrompt: '保留的反推结果',
    );
  }
}
