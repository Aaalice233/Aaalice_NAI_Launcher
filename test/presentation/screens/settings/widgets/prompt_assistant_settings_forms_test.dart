import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/model_services/provider_model_form.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/prompt_assistant_settings_forms.dart';

const _provider = ProviderConfig(
  id: 'meifan',
  name: '美饭',
  baseUrl: 'https://sub.mathhomework.top/v1beta',
  allowImageInput: true,
);

Widget _launcher({
  required Future<void> Function(BuildContext context) open,
  double textScale = 1,
}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => FilledButton(
        onPressed: () => unawaited(open(context)),
        child: const Text('打开'),
      ),
    ),
  ),
);

Future<void> _openModelForm(BuildContext context) =>
    AdaptivePresenter.showForm<ProviderModelFormResult>(
      context: context,
      dialogWidth: 480,
      title: '手动添加',
      builder: (context, scrollController) => ProviderModelForm(
        provider: _provider,
        existingIds: const {},
        scrollController: scrollController,
      ),
    );

Future<void> _openProviderForm(BuildContext context, ProviderConfig? provider) =>
    AdaptivePresenter.showForm<PromptAssistantProviderFormResult>(
      context: context,
      dialogWidth: 520,
      title: '服务商',
      builder: (context, scrollController) => PromptAssistantProviderForm(
        provider: provider,
        scrollController: scrollController,
      ),
    );

void main() {
  testWidgets('模型表单在桌面按内容高度呈现', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(610, 1025);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_launcher(open: _openModelForm));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface).height, lessThan(480));
    expect(find.text('保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('模型表单内容受限时滚动且操作区保持可见', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_launcher(open: _openModelForm, textScale: 3));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-centered-form'));
    final save = find.text('保存');
    expect(surface, findsOneWidget);
    expect(save, findsOneWidget);
    expect(
      tester.getBottomRight(save).dy,
      lessThanOrEqualTo(tester.getBottomRight(surface).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('模型表单拒绝空 ID 和重复 ID', (tester) async {
    ProviderModelFormResult? result;
    await tester.pumpWidget(
      _launcher(
        open: (context) async {
          result = await AdaptivePresenter.showForm<ProviderModelFormResult>(
            context: context,
            title: '手动添加',
            builder: (context, scrollController) => ProviderModelForm(
              provider: _provider,
              existingIds: const {'gpt-4o'},
              scrollController: scrollController,
            ),
          );
        },
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入模型 ID'), findsOneWidget);

    final idField = find.byKey(const ValueKey('model-services-model-id'));
    await tester.enterText(idField, 'gpt-4o');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('这个服务商已经有这个模型'), findsOneWidget);

    await tester.enterText(idField, '  my-model  ');
    await tester.enterText(
      find.byKey(const ValueKey('model-services-model-display-name')),
      '我的模型',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(result, (id: 'my-model', displayName: '我的模型'));
  });

  testWidgets('编辑已有服务商时地址和密钥交给页内编辑，新建时仍可填写', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _launcher(open: (context) => _openProviderForm(context, _provider)),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('Base URL'), findsNothing);
    expect(find.text('API Key (留空不改)'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _launcher(open: (context) => _openProviderForm(context, null)),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('Base URL'), findsOneWidget);
    expect(find.text('API Key (留空不改)'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
  });
}
