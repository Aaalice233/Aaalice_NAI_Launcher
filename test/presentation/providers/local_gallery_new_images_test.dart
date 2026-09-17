import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_index_admission.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';

void main() {
  test('图库未初始化时新图延后收录，不在生成链路上枚举整个根目录', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(localGalleryNotifierProvider.notifier);
    expect(container.read(localGalleryNotifierProvider).isInitialized, isFalse);

    final admission = await notifier.addNewlySavedImages([
      'G:/gallery/output.png',
    ]);

    expect(admission, GalleryIndexAdmission.deferred);
    expect(admission.requiresFullRescan, isFalse);
  });

  test('空路径列表不产生任何索引动作', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final admission = await container
        .read(localGalleryNotifierProvider.notifier)
        .addNewlySavedImages([]);

    expect(admission, GalleryIndexAdmission.alreadyIndexed);
    expect(admission.requiresFullRescan, isFalse);
  });
}
