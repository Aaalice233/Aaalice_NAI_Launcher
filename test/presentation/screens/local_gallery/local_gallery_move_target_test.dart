import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_move_target.dart';

GalleryCategory _category(
  String id,
  String name, {
  String? parentId,
  int sortOrder = 0,
}) {
  return GalleryCategory(
    id: id,
    name: name,
    folderPath: name,
    parentId: parentId,
    sortOrder: sortOrder,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}

Widget _host(Future<void> Function(BuildContext) open) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('returns empty list when no categories exist', () {
    expect(buildLocalGalleryMoveTargets(const []), isEmpty);
  });

  test('flattens category tree in display order with hierarchy labels', () {
    final categories = [
      _category('x', '角色', sortOrder: 1),
      _category('a', '风景', sortOrder: 0),
      _category('a1', '海滩', parentId: 'a', sortOrder: 1),
      _category('a2', '山脉', parentId: 'a', sortOrder: 0),
      _category('a2g', '雪山', parentId: 'a2'),
    ];

    final targets = buildLocalGalleryMoveTargets(categories);

    expect(targets.map((target) => target.label).toList(), [
      '风景',
      '风景 / 山脉',
      '风景 / 山脉 / 雪山',
      '风景 / 海滩',
      '角色',
    ]);
    expect(targets.map((target) => target.category.id).toList(), [
      'a',
      'a2',
      'a2g',
      'a1',
      'x',
    ]);
  });

  testWidgets('move target dialog returns selected category id', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      _host((context) async {
        result = await showLocalGalleryMoveTargetDialog(
          context: context,
          targets: buildLocalGalleryMoveTargets([
            _category('a', '风景'),
            _category('x', '角色'),
          ]),
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Move to Category'), findsOneWidget);

    await tester.tap(find.text('角色'));
    await tester.pumpAndSettle();

    expect(result, 'x');
  });

  testWidgets('move target dialog returns null when cancelled', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(
      _host((context) async {
        result = await showLocalGalleryMoveTargetDialog(
          context: context,
          targets: buildLocalGalleryMoveTargets([_category('a', '风景')]),
        );
      }),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
