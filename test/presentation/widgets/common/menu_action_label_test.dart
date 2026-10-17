import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/menu_action_label.dart';

const _labels = {
  'en': 'Move the selected category back to the root level',
  'ja': '選択したカテゴリをルート階層へ戻して並べ替えます',
};

Future<void> _openMenu(
  WidgetTester tester, {
  required List<PopupMenuEntry<String>> Function(BuildContext) items,
  double width = 360,
  double scale = 1,
  String locale = 'en',
}) async {
  tester.view.physicalSize = Size(width, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: PopupMenuButton<String>(
            key: const Key('menu'),
            itemBuilder: items,
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('menu')));
  await tester.pumpAndSettle();
}

Color? _iconColor(WidgetTester tester, IconData icon) =>
    IconTheme.of(tester.element(find.byIcon(icon))).color;

TextStyle _renderedStyle(WidgetTester tester, String label) {
  final element = tester.element(find.text(label));
  final text = tester.widget<Text>(find.text(label));
  return DefaultTextStyle.of(element).style.merge(text.style);
}

void main() {
  for (final locale in _labels.keys) {
    for (final scale in const [1.0, 3.0]) {
      testWidgets('$locale ${scale}x 长文案在菜单内换行且不溢出', (tester) async {
        final label = _labels[locale]!;
        await _openMenu(
          tester,
          locale: locale,
          scale: scale,
          items: (_) => [
            PopupMenuItem(
              value: 'move',
              child: MenuActionLabel(
                leading: const Icon(Icons.drive_file_move_outline),
                label: label,
                trailing: const Icon(Icons.check, size: 16),
              ),
            ),
          ],
        );

        expect(tester.takeException(), isNull);
        final item = find.byType(PopupMenuItem<String>);
        final itemRect = tester.getRect(item);
        final textRect = tester.getRect(find.text(label));
        final iconRect = tester.getRect(
          find.byIcon(Icons.drive_file_move_outline),
        );
        final trailingRect = tester.getRect(find.byIcon(Icons.check));
        final fontSize = _renderedStyle(tester, label).fontSize!;

        expect(textRect.height, greaterThan(fontSize * scale * 1.5));
        expect(textRect.right, lessThanOrEqualTo(trailingRect.left));
        expect(trailingRect.right, lessThanOrEqualTo(itemRect.right));
        expect(iconRect.size, const Size.square(18));
        expect(textRect.left - iconRect.right, 8);
        expect(find.text(label).hitTestable(), findsOneWidget);
      });
    }
  }

  testWidgets('图标尺寸与间距按参数保持各菜单原有外观', (tester) async {
    await _openMenu(
      tester,
      items: (_) => [
        const PopupMenuItem(
          value: 'account',
          child: MenuActionLabel(
            leading: Icon(Icons.login),
            label: 'Login',
            iconSize: 20,
            gap: 12,
          ),
        ),
      ],
    );

    final iconRect = tester.getRect(find.byIcon(Icons.login));
    expect(iconRect.size, const Size.square(20));
    expect(tester.getRect(find.text('Login')).left - iconRect.right, 12);
  });

  testWidgets('危险操作仅在可用时使用错误色', (tester) async {
    late ColorScheme scheme;
    await _openMenu(
      tester,
      items: (context) {
        scheme = Theme.of(context).colorScheme;
        return const [
          PopupMenuItem(
            value: 'delete',
            child: MenuActionLabel(
              leading: Icon(Icons.delete),
              label: 'Delete',
              destructive: true,
            ),
          ),
          PopupMenuItem(
            value: 'remove',
            enabled: false,
            child: MenuActionLabel(
              leading: Icon(Icons.delete_outline),
              label: 'Remove',
              enabled: false,
              destructive: true,
            ),
          ),
        ];
      },
    );

    expect(_iconColor(tester, Icons.delete), scheme.error);
    expect(_renderedStyle(tester, 'Delete').color, scheme.error);
    expect(_iconColor(tester, Icons.delete_outline), isNot(scheme.error));
    expect(_renderedStyle(tester, 'Remove').color, isNot(scheme.error));
  });

  testWidgets('强调色、图标色与字重按优先级生效', (tester) async {
    late ColorScheme scheme;
    await _openMenu(
      tester,
      items: (context) {
        scheme = Theme.of(context).colorScheme;
        return [
          PopupMenuItem(
            value: 'add',
            child: MenuActionLabel(
              leading: const Icon(Icons.add),
              label: 'Add',
              color: scheme.primary,
              iconColor: scheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          PopupMenuItem(
            value: 'export',
            child: MenuActionLabel(
              leading: const Icon(Icons.file_download),
              label: 'Export',
              iconColor: scheme.secondary,
            ),
          ),
        ];
      },
    );

    expect(_iconColor(tester, Icons.add), scheme.primary);
    final addStyle = _renderedStyle(tester, 'Add');
    expect(addStyle.color, scheme.primary);
    expect(addStyle.fontWeight, FontWeight.w600);
    expect(_iconColor(tester, Icons.file_download), scheme.secondary);
    expect(_renderedStyle(tester, 'Export').color, scheme.onSurface);
  });
}
