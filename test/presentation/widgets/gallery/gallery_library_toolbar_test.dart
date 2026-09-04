import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_library_toolbar.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_sidebar.dart';

void main() {
  tearDown(() => PlatformCapabilities.debugOverride = null);

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets('all toolbar modules stay reachable at ${width.toInt()}px', (
      tester,
    ) async {
      await _pumpToolbar(tester, width: width);

      expect(find.text('资料库'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      for (final label in ['排序', '分类', '多选', '导入', '添加']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);

      if (width >= 1180) {
        expect(
          find.byKey(const ValueKey('gallery-library-toolbar-desktop')),
          findsOneWidget,
        );
        final searchRect = tester.getRect(find.byType(TextField));
        final titleRect = tester.getRect(find.text('资料库'));
        final sortRect = tester.getRect(find.text('排序'));
        expect(searchRect.left, greaterThan(titleRect.right));
        expect(searchRect.right, lessThan(sortRect.left));
        expect(searchRect.width, greaterThan(200));
      } else {
        expect(
          find.byKey(const ValueKey('gallery-library-toolbar-compact')),
          findsOneWidget,
        );
      }
    });
  }

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets('3x text uses complete compact layout at ${width.toInt()}px', (
      tester,
    ) async {
      await _pumpToolbar(tester, width: width, textScale: 3);

      expect(
        find.byKey(const ValueKey('gallery-library-toolbar-compact')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('gallery-library-toolbar-actions')),
        findsOneWidget,
      );
      for (final label in ['排序', '分类', '多选', '导入', '添加']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('touch controls preserve 44px hit targets', (tester) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    await _pumpToolbar(tester, width: 600, touch: true);

    for (final label in ['排序', '分类', '多选', '导入']) {
      expect(tester.getSize(find.text(label).first).height, lessThan(44));
      final button = find.ancestor(
        of: find.text(label).first,
        matching: find.byType(GalleryLibraryAction),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    }
  });
}

Future<void> _pumpToolbar(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
  bool touch = false,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = TextEditingController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: InteractionPolicyScope(
            initialPolicy: touch
                ? const InteractionPolicy(
                    modality: InteractionModality.touch,
                    touchAvailable: true,
                    precisePointerAvailable: false,
                  )
                : InteractionPolicy.neutral,
            child: Scaffold(
              body: GalleryLibraryToolbar(
                title: const GalleryCollectionPageTitle(
                  icon: Icons.collections_outlined,
                  title: '资料库',
                ),
                count: const GalleryLibraryCountBadge(label: '12'),
                search: GalleryLibrarySearchField(
                  controller: controller,
                  hintText: '搜索',
                  onChanged: (_) {},
                ),
                actions: const [
                  GalleryLibraryAction(icon: Icons.sort, label: '排序'),
                  GalleryLibraryAction(icon: Icons.category, label: '分类'),
                  GalleryLibraryAction(icon: Icons.checklist, label: '多选'),
                  GalleryLibraryAction(icon: Icons.upload, label: '导入'),
                ],
                primaryAction: const GalleryLibraryPrimaryAction(
                  icon: Icons.add,
                  label: '添加',
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
