import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/category/vibe_category_item.dart';
import 'package:nai_launcher/presentation/widgets/common/draggable_number_input.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_library_toolbar.dart';

void main() {
  testWidgets(
    'gallery search keeps its outer surface during typing and focus',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? query;
      await tester.pumpWidget(
        _host(
          GalleryLibrarySearchField(
            controller: controller,
            hintText: 'Search',
            onChanged: (value) => query = value,
          ),
        ),
      );
      _expectNoInnerFill(tester);
      await tester.enterText(find.byType(TextField), 'cat');
      await tester.pumpAndSettle();
      _expectNoInnerFill(tester);
      expect(query, 'cat');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('numeric edit does not add a smaller filled surface', (
    tester,
  ) async {
    int? value;
    await tester.pumpWidget(
      _host(DraggableNumberInput(value: 2, onChanged: (next) => value = next)),
    );
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    _expectNoInnerFill(tester);
    await tester.enterText(find.byType(TextField), '5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(value, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline Vibe rename keeps the row surface', (tester) async {
    String? renamed;
    await tester.pumpWidget(
      _host(
        VibeCategoryItem(
          icon: Icons.folder,
          label: 'Category',
          count: 0,
          isSelected: false,
          onTap: () {},
          onRename: (value) => renamed = value,
        ),
      ),
    );
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    _expectNoInnerFill(tester);
    await tester.enterText(find.byType(TextField), 'New name');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(renamed, 'New name');
    expect(tester.takeException(), isNull);
  });
}

void _expectNoInnerFill(WidgetTester tester) {
  final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
  expect(decorator.decoration.filled, isFalse);
}

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: ThemeData(
    platform: TargetPlatform.android,
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.purple,
    ),
  ),
  home: InteractionPolicyScope(
    initialPolicy: InteractionPolicy.touchFirst,
    child: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  ),
);
