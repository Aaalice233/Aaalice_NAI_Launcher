import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/cache/box_fit_resize_image.dart';
import 'package:nai_launcher/data/models/director/director_prompt_params.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/director_tools_notifier.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/screens/director_tools/director_tools_screen.dart';
import 'package:nai_launcher/presentation/widgets/common/decoded_memory_image.dart';

import '../../../helpers/light_theme_contrast.dart';

final Uint8List _sourceImage = Uint8List.fromList(
  img.encodePng(img.Image(width: 16, height: 16)),
);

/// 传入已有 [container] 时等同于在同一次运行里重新打开页面。
Future<ProviderContainer> _pumpScreen(
  WidgetTester tester, {
  ProviderContainer? container,
}) async {
  if (container == null) {
    // 面板只用订阅态决定 Anlas 徽章，直接钉死，免得把认证链路拖进来。
    container = createStorageFreeContainer(
      overrides: <Override>[
        isOpusSubscriptionProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
  }
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
        home: DirectorToolsScreen(key: UniqueKey(), sourceImage: _sourceImage),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _selectPixelSnap(WidgetTester tester) async {
  await tester.tap(find.text('像素对齐'));
  await tester.pumpAndSettle();
}

Future<void> _selectTool(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _tapEmotion(WidgetTester tester, String label) async {
  final Finder chip = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

List<String> _selectedEmotionLabels(WidgetTester tester) => <String>[
  for (final ChoiceChip chip in tester.widgetList<ChoiceChip>(
    find.byType(ChoiceChip),
  ))
    if (chip.selected) (chip.label as Text).data!,
];

TextEditingController _promptController(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!;

double _sliderValue(WidgetTester tester) =>
    tester.widget<Slider>(find.byType(Slider)).value;

DirectorToolsState _state(ProviderContainer container) =>
    container.read(directorToolsNotifierProvider);

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

  testWidgets('表情工具按官网列出 24 种情绪且名称走本地化', (WidgetTester tester) async {
    await _pumpScreen(tester);
    await tester.tap(find.text('表情修复'));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNWidgets(24));
    for (final String label in <String>['平静', '害怕', '大笑', '调皮']) {
      expect(
        find.widgetWithText(ChoiceChip, label),
        findsOneWidget,
        reason: label,
      );
    }
    expect(find.text('Laugh'), findsNothing);
    expect(find.text('数值越大，表情越弱（0 = 正常，5 = 最弱）'), findsOneWidget);
    expect(find.text('表情等级'), findsOneWidget);
    expect(find.text('情绪'), findsOneWidget);
  });

  testWidgets('先选情绪再调表情等级，与官网顺序一致', (WidgetTester tester) async {
    await _pumpScreen(tester);
    await _selectTool(tester, '表情修复');

    final double moodTop = tester.getTopLeft(find.text('情绪')).dy;
    final double lastChipBottom = tester
        .getBottomLeft(find.widgetWithText(ChoiceChip, '调皮'))
        .dy;
    final double levelTop = tester.getTopLeft(find.text('表情等级')).dy;
    final double promptTop = tester.getTopLeft(find.byType(TextField)).dy;
    expect(moodTop, lessThan(lastChipBottom));
    expect(lastChipBottom, lessThan(levelTop));
    expect(levelTop, lessThan(promptTop));
  });

  testWidgets('选中的情绪另有描边，不只靠底色区分', (WidgetTester tester) async {
    await _pumpScreen(tester);
    await _selectTool(tester, '表情修复');

    void expectOnlyOutlined(String selectedLabel) {
      final ColorScheme colorScheme = Theme.of(
        tester.element(find.byType(ChoiceChip).first),
      ).colorScheme;
      for (final ChoiceChip chip in tester.widgetList<ChoiceChip>(
        find.byType(ChoiceChip),
      )) {
        final String label = (chip.label as Text).data!;
        expect(chip.showCheckmark, isFalse, reason: label);
        if (label == selectedLabel) {
          expect(chip.selected, isTrue, reason: label);
          expect(chip.side?.color, colorScheme.primary, reason: label);
          expect(chip.side?.width, greaterThan(0), reason: label);
        } else {
          expect(chip.side, BorderSide.none, reason: label);
        }
      }
    }

    expectOnlyOutlined('平静');
    await _tapEmotion(tester, '害怕');
    expectOnlyOutlined('害怕');
  });

  testWidgets('刚打开时平静已选中，空附加提示词请求为 neutral;;', (WidgetTester tester) async {
    final ProviderContainer container = await _pumpScreen(tester);
    await _selectTool(tester, '表情修复');

    expect(_selectedEmotionLabels(tester), <String>['平静']);
    expect(_promptController(tester).text, isEmpty);
    expect(_state(container).emotionRequestPrompt, 'neutral;;');
  });

  testWidgets('先写附加提示词再换情绪，输入框与请求都保留原文', (WidgetTester tester) async {
    final ProviderContainer container = await _pumpScreen(tester);
    await _selectTool(tester, '表情修复');
    await tester.enterText(find.byType(TextField), 'tears, blush');
    await tester.pumpAndSettle();

    for (final (String label, String mood) in <(String, String)>[
      ('开心', 'happy'),
      ('悲伤', 'sad'),
      ('爱意', 'love'),
      ('害怕', 'scared'),
    ]) {
      await _tapEmotion(tester, label);
      expect(_selectedEmotionLabels(tester), <String>[label]);
      expect(_promptController(tester).text, 'tears, blush', reason: label);
      expect(_state(container).emotionParams.prompt, 'tears, blush');
      expect(_state(container).emotionRequestPrompt, '$mood;;tears, blush');
    }
  });

  testWidgets('在中间改字时光标停在原处，不被状态回写拉到末尾', (WidgetTester tester) async {
    final ProviderContainer container = await _pumpScreen(tester);
    await _selectTool(tester, '表情修复');
    await tester.enterText(find.byType(TextField), 'tears');
    await tester.pumpAndSettle();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'teXars',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pumpAndSettle();

    expect(_state(container).emotionParams.prompt, 'teXars');
    expect(
      _promptController(tester).selection,
      const TextSelection.collapsed(offset: 3),
    );
  });

  testWidgets('上色与表情各自保留提示词与 defry，输入框和滑块跟随当前工具', (WidgetTester tester) async {
    final ProviderContainer container = await _pumpScreen(tester);
    final DirectorToolsNotifier notifier = container.read(
      directorToolsNotifierProvider.notifier,
    );

    await _selectTool(tester, '上色');
    await tester.enterText(find.byType(TextField), 'red hair');
    notifier.updateDefry(2);
    await tester.pumpAndSettle();
    expect(_sliderValue(tester), 2);

    await _selectTool(tester, '表情修复');
    expect(_promptController(tester).text, isEmpty);
    expect(_sliderValue(tester), 0);
    await tester.enterText(find.byType(TextField), 'tears');
    notifier.updateDefry(4);
    await tester.pumpAndSettle();

    await _selectTool(tester, '上色');
    expect(_promptController(tester).text, 'red hair');
    expect(_sliderValue(tester), 2);
    expect(find.byType(ChoiceChip), findsNothing);

    await _selectTool(tester, '表情修复');
    expect(_promptController(tester).text, 'tears');
    expect(_sliderValue(tester), 4);
    expect(
      _state(container).colorizeParams,
      const DirectorPromptParams(prompt: 'red hair', defry: 2),
    );
    expect(
      _state(container).emotionParams,
      const DirectorPromptParams(prompt: 'tears', defry: 4),
    );
  });

  testWidgets('重新打开时情绪、提示词与 defry 回到默认，不沿用上一次', (WidgetTester tester) async {
    final ProviderContainer container = await _pumpScreen(tester);
    await _selectTool(tester, '表情修复');
    await _tapEmotion(tester, '害怕');
    await tester.enterText(find.byType(TextField), 'tears');
    container.read(directorToolsNotifierProvider.notifier).updateDefry(3);
    await tester.pumpAndSettle();
    expect(_selectedEmotionLabels(tester), <String>['害怕']);

    await _pumpScreen(tester, container: container);
    await _selectTool(tester, '表情修复');

    expect(_selectedEmotionLabels(tester), <String>['平静']);
    expect(_promptController(tester).text, isEmpty);
    expect(_sliderValue(tester), 0);
    expect(_state(container).emotionRequestPrompt, 'neutral;;');
  });

  testWidgets('原图预览按显示器尺寸封顶解码，与窗口尺寸无关', (WidgetTester tester) async {
    await _pumpScreen(tester);
    final display = tester.view.display;
    final logicalDisplay = display.size / display.devicePixelRatio;
    final pixelRatio = tester.view.devicePixelRatio;
    final expected = BoxFitResizeImage(
      MemoryImage(_sourceImage),
      width: DecodedMemoryImage.resolveCacheDimension(
        logicalSize: logicalDisplay.width,
        constrainedSize: null,
        pixelRatio: pixelRatio,
      ),
      height: DecodedMemoryImage.resolveCacheDimension(
        logicalSize: logicalDisplay.height,
        constrainedSize: null,
        pixelRatio: pixelRatio,
      ),
      fit: DecodeFit.contain,
    );

    BoxFitResizeImage sourcePreview() => tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<BoxFitResizeImage>()
        .single;

    expect(sourcePreview(), expected);
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    await tester.pumpAndSettle();
    expect(sourcePreview(), expected);
  });
}
