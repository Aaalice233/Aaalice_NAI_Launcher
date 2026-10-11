import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/services/local_onnx_model_service.dart';
import 'package:nai_launcher/data/services/local_onnx_tagger_labels.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_panel_expansion_provider.dart';
import 'package:nai_launcher/presentation/providers/reverse_prompt_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/reverse_prompt_panel.dart';

import '../../../../helpers/labeled_rows_expectations.dart';
import '../../../../helpers/light_theme_contrast.dart';

const _pixaiModel = LocalOnnxModelDescriptor(
  name: 'model.onnx',
  path: 'models/pixai/model.onnx',
  kind: LocalOnnxModelKind.pixaiTagger,
  labelsPath: 'models/pixai/config.json',
);

const _wd14Model = LocalOnnxModelDescriptor(
  name: 'wd-v1-4-vit-tagger-v2.onnx',
  path: 'models/wd14/wd-v1-4-vit-tagger-v2.onnx',
  kind: LocalOnnxModelKind.wd14Tagger,
  labelsPath: 'models/wd14/selected_tags.csv',
);

void main() {
  testWidgets('PixAI 模型列出五个输出分类并默认勾选通用、角色、版权', (tester) async {
    final container = await _pumpPanel(tester, model: _pixaiModel);
    final l10n = lookupAppLocalizations(const Locale('zh'));

    for (final (label, selected) in [
      (l10n.tagCategory_general, true),
      (l10n.tagCategory_character, true),
      (l10n.tagCategory_copyright, true),
      (l10n.tagCategory_artist, false),
      (l10n.tagCategory_meta, false),
    ]) {
      expect(_chip(tester, label).selected, selected, reason: label);
    }

    await tester.tap(find.widgetWithText(FilterChip, l10n.tagCategory_artist));
    await tester.pumpAndSettle();

    expect(
      container.read(reversePromptProvider).taggerCategories,
      contains(OnnxTaggerLabelCategory.artist),
    );
    expect(_chip(tester, l10n.tagCategory_artist).selected, isTrue);
  });

  testWidgets('只列出模型具备的分类，并拒绝取消其中最后一个', (tester) async {
    final container = await _pumpPanel(tester, model: _wd14Model);
    final l10n = lookupAppLocalizations(const Locale('zh'));

    expect(
      find.widgetWithText(FilterChip, l10n.tagCategory_copyright),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(FilterChip, l10n.tagCategory_general));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilterChip, l10n.tagCategory_character),
    );
    await tester.pumpAndSettle();

    expect(_chip(tester, l10n.tagCategory_character).selected, isTrue);
    expect(
      container.read(reversePromptProvider).taggerCategories,
      contains(OnnxTaggerLabelCategory.character),
    );
    expect(find.text(l10n.reversePrompt_keepOneTaggerCategory), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  for (final locale in const ['zh', 'ja', 'en']) {
    for (final width in labeledRowWidths) {
      for (final scale in labeledRowTextScales) {
        final scenario = '$locale ${width.toInt()} ${scale}x';
        testWidgets('$scenario 下输出分类开关完整可达', (tester) async {
          await _pumpPanel(
            tester,
            model: _pixaiModel,
            locale: locale,
            width: width,
            textScale: scale,
          );
          final l10n = lookupAppLocalizations(Locale(locale));

          for (final label in [
            l10n.tagCategory_general,
            l10n.tagCategory_character,
            l10n.tagCategory_copyright,
            l10n.tagCategory_artist,
            l10n.tagCategory_meta,
          ]) {
            final chip = find.widgetWithText(FilterChip, label);
            await tester.ensureVisible(chip);
            await tester.pumpAndSettle();
            final rect = tester.getRect(chip);
            expect(
              rect.left,
              greaterThanOrEqualTo(0),
              reason: '$scenario $label',
            );
            expect(
              rect.right,
              lessThanOrEqualTo(width),
              reason: '$scenario $label',
            );
            expect(
              chip.hitTestable(),
              findsOneWidget,
              reason: '$scenario $label',
            );
          }
          tester.takeException();
        });
      }
    }
  }
}

FilterChip _chip(WidgetTester tester, String label) =>
    tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));

Future<ProviderContainer> _pumpPanel(
  WidgetTester tester, {
  required LocalOnnxModelDescriptor model,
  String locale = 'zh',
  double width = 1180,
  double textScale = 1,
}) async {
  final categories = model.kind == LocalOnnxModelKind.pixaiTagger
      ? OnnxTaggerLabelCategory.values.toSet()
      : {
          OnnxTaggerLabelCategory.general,
          OnnxTaggerLabelCategory.character,
          OnnxTaggerLabelCategory.rating,
        };
  final container = createStorageFreeContainer(
    overrides: [
      localOnnxModelServiceProvider.overrideWith(
        (ref) =>
            _FixedTaggerModels(ref.read(localStorageServiceProvider), model),
      ),
      reversePromptTaggerCategoriesProvider.overrideWith(
        (ref, labelsPath) async => categories,
      ),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(generationPanelExpansionProvider.notifier)
      .setExpanded(GenerationWorkbenchPanel.reversePrompt, true);
  await tester.binding.setSurfaceSize(Size(width, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: ReversePromptPanel()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // 底部操作按钮行在窄屏大字号下的既有溢出与分类开关无关，分类开关由逐项边界断言覆盖
  tester.takeException();
  return container;
}

class _FixedTaggerModels extends LocalOnnxModelService {
  const _FixedTaggerModels(super.storage, this.model);

  final LocalOnnxModelDescriptor model;

  @override
  Future<List<LocalOnnxModelDescriptor>> scanTaggerModels() async => [model];
}
