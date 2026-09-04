import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/prompt_assistant_settings_forms.dart';

void main() {
  testWidgets('连接配置弹窗在桌面按内容高度呈现', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(610, 1025);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                unawaited(
                  AdaptivePresenter.showForm<
                    PromptAssistantConnectionFormResult
                  >(
                    context: context,
                    dialogWidth: 520,
                    title: '美饭 连接配置',
                    builder: (context, scrollController) =>
                        PromptAssistantConnectionForm(
                          provider: const ProviderConfig(
                            id: 'meifan',
                            name: '美饭',
                            baseUrl: 'https://sub.mathhomework.top/v1beta',
                            allowImageInput: true,
                          ),
                          scrollController: scrollController,
                        ),
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface).height, lessThan(560));
    expect(find.text('保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('连接配置内容受限时滚动且操作区保持可见', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                unawaited(
                  AdaptivePresenter.showForm<
                    PromptAssistantConnectionFormResult
                  >(
                    context: context,
                    dialogWidth: 520,
                    title: '美饭 连接配置',
                    builder: (context, scrollController) =>
                        PromptAssistantConnectionForm(
                          provider: const ProviderConfig(
                            id: 'meifan',
                            name: '美饭',
                            baseUrl: 'https://sub.mathhomework.top/v1beta',
                            allowImageInput: true,
                          ),
                          scrollController: scrollController,
                        ),
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

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
}
