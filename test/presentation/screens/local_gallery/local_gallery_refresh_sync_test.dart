import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_action_coordinator.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_screen_controller.dart';

void main() {
  late List<String> calls;
  late bool mounted;
  late LocalGalleryScreenController controller;

  setUp(() {
    calls = <String>[];
    mounted = true;
  });

  Future<void> pumpController(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localGalleryNotifierProvider.overrideWith(
            () => _RecordingGalleryNotifier(calls),
          ),
          galleryCategoryNotifierProvider.overrideWith(
            () => _RecordingCategoryNotifier(calls),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              controller = LocalGalleryScreenController(
                ref: ref,
                context: () => context,
                mounted: () => mounted,
                groupedGridViewKey: GlobalKey(),
                actions: LocalGalleryActionCoordinator(
                  ref: ref,
                  context: () => context,
                  mounted: () => mounted,
                ),
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  testWidgets('刷新画廊会先刷新图片，再让文件夹列表与磁盘同步', (tester) async {
    await pumpController(tester);

    await controller.refreshGallery();

    expect(calls, ['refreshImages', 'waitCategoriesLoaded', 'syncCategories']);
  });

  testWidgets('页面已卸载时刷新画廊不再同步文件夹列表', (tester) async {
    await pumpController(tester);
    mounted = false;

    await controller.refreshGallery();

    expect(calls, ['refreshImages']);
  });
}

class _RecordingGalleryNotifier extends LocalGalleryNotifier {
  _RecordingGalleryNotifier(this._calls);

  final List<String> _calls;

  @override
  LocalGalleryState build() => const LocalGalleryState();

  @override
  Future<void> refresh({bool scan = true}) async {
    _calls.add('refreshImages');
  }
}

class _RecordingCategoryNotifier extends GalleryCategoryNotifier {
  _RecordingCategoryNotifier(this._calls);

  final List<String> _calls;

  @override
  GalleryCategoryState build() => const GalleryCategoryState();

  @override
  Future<void> whenLoaded() async {
    _calls.add('waitCategoriesLoaded');
  }

  @override
  Future<void> syncWithFileSystem() async {
    _calls.add('syncCategories');
  }
}
