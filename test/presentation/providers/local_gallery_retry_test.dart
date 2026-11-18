import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/exceptions/gallery_exceptions.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/unified_gallery_service.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';

class _Gallery extends Mock implements LocalGalleryService {}

void main() {
  late _Gallery service;
  late ProviderContainer container;
  late LocalGalleryNotifier gallery;
  final image = LocalImageRecord(
    path: 'one.png',
    size: 1,
    modifiedAt: DateTime(2026),
  );

  setUp(() {
    service = _Gallery();
    when(service.dispose).thenAnswer((_) async {});
    when(() => service.isInitialized).thenReturn(true);
    when(() => service.totalCount).thenReturn(1);
    when(() => service.filteredCount).thenReturn(1);
    when(
      () => service.getPage(0, pageSize: any(named: 'pageSize')),
    ).thenAnswer((_) async => [image]);
    when(
      () => service.applyFilter(const FilterCriteria()),
    ).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        galleryServiceProvider.overrideWith(
          () => GalleryService(createService: () => service),
        ),
      ],
    );
    addTearDown(container.dispose);
    gallery = container.read(localGalleryNotifierProvider.notifier);
  });

  for (final retryCount in [1, 2]) {
    test('$retryCount 次重试共享一次新的枚举并重新显示首页', () async {
      when(
        service.initialize,
      ).thenThrow(const GalleryScanException(message: 'denied'));
      await gallery.initialize();
      expect(container.read(localGalleryNotifierProvider).error, isNotNull);
      expect(
        container.read(galleryServiceProvider),
        isA<ErrorGalleryService>(),
      );

      final enumeration = Completer<List<File>>();
      when(service.initialize).thenAnswer((_) => enumeration.future);
      final retries = List.generate(retryCount, (_) => gallery.refresh());
      final shared = container.read(galleryServiceProvider.notifier);
      expect(shared.ensureInitialized(), same(shared.ensureInitialized()));
      enumeration.complete([File(image.path)]);
      await Future.wait(retries);

      final state = container.read(localGalleryNotifierProvider);
      expect(state.error, isNull);
      expect(state.currentImages, [image]);
      verify(service.initialize).called(2);
      verifyNever(() => service.refresh(scan: any(named: 'scan')));
    });
  }

  test('刷新、分页和分组成功后撤销旧错误', () async {
    when(service.initialize).thenAnswer((_) async => [File(image.path)]);
    await gallery.initialize();
    Future<void> failRefresh() async {
      when(
        () => service.refresh(),
      ).thenThrow(const GalleryScanException(message: 'unreadable'));
      await gallery.refresh();
      expect(
        container.read(localGalleryNotifierProvider).error?.code,
        LocalGalleryErrorCode.refreshFailed,
      );
    }

    await failRefresh();
    final gate = Completer<void>();
    when(() => service.refresh()).thenAnswer((_) => gate.future);
    final retry = gallery.refresh();
    expect(container.read(localGalleryNotifierProvider).error, isNull);
    gate.complete();
    await retry;
    expect(container.read(localGalleryNotifierProvider).currentImages, [image]);
    expect(container.read(localGalleryNotifierProvider).error, isNull);
    await failRefresh();
    await gallery.loadPage(0);
    expect(container.read(localGalleryNotifierProvider).error, isNull);
    await failRefresh();
    await gallery.setGroupedView(true);
    expect(container.read(localGalleryNotifierProvider).groupedImages, [image]);
    expect(container.read(localGalleryNotifierProvider).error, isNull);
  });
}
