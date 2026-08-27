import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/tag_library_page/widgets/entry_add_dialog.dart';

void main() {
  testWidgets('添加条目对话框在手机宽度改为单列且无横向溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: EntryAddDialog(categories: [])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('添加条目'), findsOneWidget);
    expect(find.text('预览图'), findsOneWidget);
    expect(find.text('名称'), findsOneWidget);

    final thumbnailTop = tester.getTopLeft(find.text('预览图')).dy;
    final nameTop = tester.getTopLeft(find.text('名称')).dy;
    expect(nameTop, greaterThan(thumbnailTop));

    final dialogContentRect = tester.getRect(
      find.byType(SingleChildScrollView),
    );
    expect(dialogContentRect.left, greaterThanOrEqualTo(16));
    expect(dialogContentRect.right, lessThanOrEqualTo(344));
  });
}
