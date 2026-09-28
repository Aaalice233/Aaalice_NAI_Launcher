import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/vibe_card.dart';
import 'package:nai_launcher/presentation/widgets/common/editable_double_field.dart';
import 'package:nai_launcher/presentation/widgets/common/hover_image_preview.dart';

void main() {
  testWidgets('参考强度滑条保持官网范围，但数值输入不设上下限', (tester) async {
    double? changedStrength;
    final vibe = VibeReference(
      displayName: 'test',
      vibeEncoding: 'encoded',
      rawImageData: Uint8List.fromList(const [1, 2, 3]),
      thumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: -2.4,
      infoExtracted: 0.7,
      sourceType: VibeSourceType.naiv4vibe,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: VibeCard(
              index: 0,
              vibe: vibe,
              onRemove: () {},
              onStrengthChanged: (value) => changedStrength = value,
              onInfoExtractedChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final strengthSlider = tester.widget<Slider>(find.byType(Slider).at(0));
    final strengthField = tester.widget<EditableDoubleField>(
      find.byType(EditableDoubleField).at(0),
    );

    expect(strengthSlider.min, 0.01);
    expect(strengthSlider.max, 1.0);
    expect(strengthSlider.value, 0.01);
    expect(strengthSlider.divisions, 99);
    expect(strengthField.min, isNull);
    expect(strengthField.max, isNull);

    await tester.enterText(find.byType(TextField).at(0), '3.25');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(changedStrength, 3.25);
  });

  test('参考强度只拒绝非有限数值', () {
    expect(VibeReference.sanitizeStrength(4.2), 4.2);
    expect(VibeReference.sanitizeStrength(-3.1), -3.1);
    expect(
      VibeReference.sanitizeStrength(double.infinity),
      VibeReference.defaultStrength,
    );
  });

  testWidgets('没有原图数据时不显示信息提取调节项', (tester) async {
    final vibe = VibeReference(
      displayName: 'encoded-only',
      vibeEncoding: 'encoded',
      thumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: 0.4,
      infoExtracted: 0.7,
      sourceType: VibeSourceType.naiv4vibe,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: VibeCard(
              index: 0,
              vibe: vibe,
              onRemove: () {},
              onStrengthChanged: (_) {},
              onInfoExtractedChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('信息提取'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(EditableDoubleField), findsOneWidget);
  });

  testWidgets('启用开关会回传当前卡片的新状态', (tester) async {
    final vibe = VibeReference(
      displayName: 'toggle-test',
      vibeEncoding: 'encoded',
      thumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: 0.4,
      infoExtracted: 0.7,
      sourceType: VibeSourceType.naiv4vibe,
    );
    bool? nextEnabled;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: VibeCard(
              index: 0,
              vibe: vibe,
              onRemove: () {},
              onStrengthChanged: (_) {},
              onInfoExtractedChanged: (_) {},
              onEnabledChanged: (value) => nextEnabled = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('vibe-enabled-switch-0')));
    await tester.pump();

    expect(nextEnabled, isFalse);
  });

  testWidgets('未编码原图加入卡片后不会自动弹出编码确认', (tester) async {
    final vibe = VibeReference(
      displayName: 'raw-image',
      vibeEncoding: '',
      rawImageData: Uint8List.fromList(const [1, 2, 3]),
      thumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: 0.6,
      infoExtracted: 0.7,
      sourceType: VibeSourceType.rawImage,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: VibeCard(
              index: 0,
              vibe: vibe,
              onRemove: () {},
              onStrengthChanged: (_) {},
              onInfoExtractedChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('未登录手动编码不会进入 encoding 状态或调用上传', (tester) async {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    var encodeCalls = 0;
    final vibe = VibeReference(
      displayName: 'private-vibe',
      vibeEncoding: '',
      rawImageData: Uint8List.fromList(const [1, 2, 3]),
      thumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: 0.6,
      infoExtracted: 0.7,
      sourceType: VibeSourceType.rawImage,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: VibeCard(
              index: 0,
              vibe: vibe,
              onRemove: () {},
              onStrengthChanged: (_) {},
              onInfoExtractedChanged: (_) {},
              onEncode:
                  (
                    _, {
                    required informationExtracted,
                    required vibeName,
                  }) async {
                    encodeCalls++;
                    return 'should-not-run';
                  },
              onUpdateEncoding: (_, {required vibeEncoding}) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.pending));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(encodeCalls, 0);
    expect(find.byIcon(Icons.pending), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      container.read(authPromptRequestProvider)?.reason,
      AuthPromptReason.vibeEncoding,
    );
  });

  testWidgets('宽版卡片将缩略图与参数区垂直居中', (tester) async {
    final vibe = VibeReference(
      displayName: 'wide-card',
      vibeEncoding: 'encoded',
      rawImageData: Uint8List.fromList(const [1, 2, 3]),
      thumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: 0.6,
      infoExtracted: 0.7,
      sourceType: VibeSourceType.rawImage,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 460,
                child: VibeCard(
                  index: 0,
                  vibe: vibe,
                  onRemove: () {},
                  onStrengthChanged: (_) {},
                  onInfoExtractedChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final hoverPreview = tester.widget<HoverImagePreview>(
      find.byType(HoverImagePreview),
    );
    expect(hoverPreview.previewMaxSize, 520);

    final contentRect = tester.getRect(
      find.byKey(const ValueKey('vibe-card-wide-content-0')),
    );
    final thumbnailRect = tester.getRect(
      find.byKey(const ValueKey('vibe-card-thumbnail-0')),
    );
    expect(thumbnailRect.center.dy, closeTo(contentRect.center.dy, 0.01));
  });

  testWidgets('窄宽卡片将操作区收进边界且删除按钮可点击', (tester) async {
    final vibe = VibeReference(
      displayName: 'narrow-card',
      vibeEncoding: 'encoded',
      thumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: 0.6,
      infoExtracted: 0.7,
      sourceType: VibeSourceType.naiv4vibe,
    );
    var removed = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 154,
                child: VibeCard(
                  index: 0,
                  vibe: vibe,
                  onRemove: () => removed = true,
                  onStrengthChanged: (_) {},
                  onInfoExtractedChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final cardRect = tester.getRect(
      find.byKey(const ValueKey('vibe-card-container-0')),
    );
    final removeFinder = find.byKey(const Key('vibe-card-remove-0'));
    final removeRect = tester.getRect(removeFinder);
    expect(cardRect.contains(removeRect.center), isTrue);
    expect(tester.takeException(), isNull);

    await tester.tap(removeFinder);
    await tester.pump();
    expect(removed, isTrue);
  });

  testWidgets('关闭的 Vibe 卡片会降低整体透明度', (tester) async {
    final vibe = VibeReference(
      displayName: 'disabled-test',
      vibeEncoding: 'encoded',
      thumbnail: Uint8List.fromList(const [1, 2, 3]),
      strength: 0.4,
      infoExtracted: 0.7,
      sourceType: VibeSourceType.naiv4vibe,
      enabled: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: VibeCard(
              index: 0,
              vibe: vibe,
              onRemove: () {},
              onStrengthChanged: (_) {},
              onInfoExtractedChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('vibe-card-enabled-opacity-0')),
    );

    expect(opacity.opacity, lessThan(1.0));
  });
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams(model: 'nai-diffusion-4-full');
}
