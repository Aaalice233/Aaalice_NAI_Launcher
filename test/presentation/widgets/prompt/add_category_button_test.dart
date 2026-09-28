import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/category_card_widgets.dart';

void main() {
  testWidgets('未接线的新增类别按钮默认弹窗创建类别', (tester) async {
    final notifier = _RecordingRandomPresetNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(() => notifier),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AddCategoryButton()),
        ),
      ),
    );

    await tester.tap(find.text('新增类别'));
    await tester.pumpAndSettle();

    // 默认行为：弹出输入对话框
    expect(find.text('创建新类别'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '发色');
    // 让 onChanged 的 setState 生效，确认按钮才会变为可点击
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(notifier.added, hasLength(1));
    expect(notifier.added.single.name, '发色');
    expect(notifier.added.single.key, isNotEmpty);
  });

  testWidgets('传入回调时优先使用自定义回调', (tester) async {
    var pressed = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            _RecordingRandomPresetNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AddCategoryButton(onPressed: () => pressed++)),
        ),
      ),
    );

    await tester.tap(find.text('新增类别'));
    await tester.pumpAndSettle();

    expect(pressed, 1);
    expect(find.text('创建新类别'), findsNothing);
  });
}

class _RecordingRandomPresetNotifier extends RandomPresetNotifier {
  final List<RandomCategory> added = [];

  @override
  RandomPresetState build() {
    return const RandomPresetState(
      presets: [
        RandomPreset(id: 'custom', name: '测试预设'),
      ],
      selectedPresetId: 'custom',
    );
  }

  @override
  Future<void> addCategory(RandomCategory category) async {
    added.add(category);
  }
}
