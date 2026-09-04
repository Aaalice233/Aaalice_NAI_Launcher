import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/save_as_preset_dialog.dart';

void main() {
  testWidgets('320dp、3x、IME 与 SafeArea 下使用长表单且内容可滚动', (tester) async {
    final view = tester.view;
    view.devicePixelRatio = 3;
    view.physicalSize = const Size(960, 1704);
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              viewInsets: const EdgeInsets.only(bottom: 240),
              textScaler: const TextScaler.linear(3),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    SaveAsPresetDialog.show(context, metadata: _metadata),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

const _metadata = NaiImageMetadata(
  prompt: 'very long prompt, second tag',
  negativePrompt: 'negative tag',
  seed: 42,
  steps: 28,
  scale: 6,
  width: 1024,
  height: 1024,
  sampler: 'k_euler',
  model: 'long model name',
  smea: true,
  qualityTags: ['best quality'],
);
