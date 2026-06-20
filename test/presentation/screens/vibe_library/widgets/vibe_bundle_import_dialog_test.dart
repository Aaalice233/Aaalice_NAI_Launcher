import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_bundle_import_dialog.dart';

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

  testWidgets('中文环境下导入 Bundle 弹窗不显示硬编码英文', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const VibeBundleImportDialog(
          bundleName: '2026-05-13.naiv4vibebundle',
          vibeNames: ['Vibe A', 'Vibe B', 'Vibe C', 'Vibe D'],
        ),
      ),
    );

    expect(find.text('导入 Vibe Bundle'), findsOneWidget);
    expect(find.text('Import Vibe Bundle'), findsNothing);
    expect(find.text('共 4 个 Vibe'), findsOneWidget);
    expect(find.text('4 Vibes'), findsNothing);
    expect(find.text('选择导入方式'), findsOneWidget);
    expect(find.text('Choose import method'), findsNothing);
    expect(find.text('作为整体导入'), findsOneWidget);
    expect(find.text('Import as whole'), findsNothing);
    expect(find.text('保留 Bundle 结构，并作为一个库条目导入'), findsOneWidget);
    expect(
      find.text('Keep the bundle structure and import it as one library entry'),
      findsNothing,
    );
    expect(find.text('拆分为独立条目'), findsOneWidget);
    expect(find.text('Split into separate entries'), findsNothing);
    expect(find.text('将每个 Vibe 作为独立库条目导入'), findsOneWidget);
    expect(
      find.text('Import each vibe as a separate library entry'),
      findsNothing,
    );
    expect(find.text('选择要导入的 Vibe'), findsOneWidget);
    expect(find.text('Select vibes to import'), findsNothing);
    expect(find.text('仅导入选中的 Vibe'), findsOneWidget);
    expect(find.text('Import only the selected vibes'), findsNothing);

    await tester.tap(find.text('选择要导入的 Vibe'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 4/4'), findsOneWidget);
    expect(find.text('4/4 selected'), findsNothing);
  });

  testWidgets('中文环境下可配置 Bundle 参数标题已本地化', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const VibeBundleImportDialog(
          bundleName: 'configured.naiv4vibebundle',
          vibeNames: ['Vibe A', 'Vibe B'],
          vibeReferences: [
            VibeReference(displayName: 'Vibe A', vibeEncoding: 'encoded-a'),
            VibeReference(displayName: 'Vibe B', vibeEncoding: 'encoded-b'),
          ],
        ),
      ),
    );

    expect(find.text('配置每个 Vibe 的参数'), findsOneWidget);
    expect(find.text("Configure each Vibe's parameters"), findsNothing);

    await tester.tap(find.text('选择要导入的 Vibe'));
    await tester.pumpAndSettle();

    expect(find.text('选择并配置每个 Vibe 的参数'), findsOneWidget);
    expect(
      find.text("Select and configure each Vibe's parameters"),
      findsNothing,
    );
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
