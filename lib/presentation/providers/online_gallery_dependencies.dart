import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/autocomplete/tag_catalog_repository.dart';
import '../../core/network/online_gallery_retry_interceptor.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/datasources/remote/gelbooru_api_service.dart';
import '../../data/datasources/remote/online_gallery/ai_tag_gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/donmai_gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/gelbooru_gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/quick_tag_cloud_gallery_source_adapter.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/models/online_gallery/quick_tag_cloud_catalog.dart';
import '../../data/models/online_gallery/quick_tag_cloud_codex.dart';
import '../../data/repositories/online_gallery_repository.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/gelbooru_auth_service.dart';
import '../../data/services/online_gallery/online_gallery_query.dart';
import 'quick_tag_cloud_gallery_provider.dart';

Dio onlineGalleryHttpClient(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
  dio.interceptors.add(OnlineGalleryRetryInterceptor(dio: dio));
  return dio;
}

final onlineGalleryHttpClientProvider = Provider<Dio>(
  onlineGalleryHttpClient,
  name: 'onlineGalleryHttpClientProvider',
);

// ignore: deprecated_member_use
typedef OnlineGalleryHttpClientRef = ProviderRef<Dio>;

typedef GalleryTagMetadataLoader =
    Future<Map<String, TagCatalogRecord>> Function(Iterable<String> terms);

final onlineGalleryTagCatalogProvider = Provider<TagCatalogRepository>((ref) {
  final repository = TagCatalogRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final onlineGalleryTagMetadataLoaderProvider =
    Provider<GalleryTagMetadataLoader>((ref) {
      return ref.watch(onlineGalleryTagCatalogProvider).resolveExactTags;
    });

final quickTagCloudGallerySourceAdapterProvider =
    Provider<QuickTagCloudGallerySourceAdapter>((ref) {
      return QuickTagCloudGallerySourceAdapter(
        catalogService: ref.watch(quickTagCloudCatalogServiceProvider),
        userService: ref.watch(quickTagCloudUserServiceProvider),
        queryReader: () => ref.read(quickTagCloudFilterProvider),
      );
    });

final quickTagCloudCatalogProvider =
    FutureProvider.autoDispose<QuickTagCloudCatalog>((ref) {
      return ref.watch(quickTagCloudGallerySourceAdapterProvider).getCatalog();
    });

final quickTagCloudCodexProvider = FutureProvider.autoDispose
    .family<QuickTagCloudCodex, String>((ref, id) {
      return ref.watch(quickTagCloudGallerySourceAdapterProvider).getCodex(id);
    });

Map<GallerySourceId, GallerySourceAdapter> onlineGallerySourceAdapters(
  Ref ref,
) {
  final dio = ref.watch(onlineGalleryHttpClientProvider);
  return {
    GallerySourceId.danbooru: DonmaiGallerySourceAdapter(
      sourceId: GallerySourceId.danbooru,
      dio: dio,
      authHeader: () => ref.read(danbooruAuthProvider.notifier).getAuthHeader(),
    ),
    GallerySourceId.safebooru: DonmaiGallerySourceAdapter(
      sourceId: GallerySourceId.safebooru,
      dio: dio,
    ),
    GallerySourceId.gelbooru: GelbooruGallerySourceAdapter(
      dio: dio,
      apiService: ref.watch(gelbooruApiServiceProvider),
      credentials: () async {
        await ref.read(gelbooruAuthProvider.notifier).ensureInitialized();
        return ref.read(gelbooruAuthProvider).credentials;
      },
      markCredentialsInvalid: () {
        ref.read(gelbooruAuthProvider.notifier).markInvalid();
      },
    ),
    GallerySourceId.aiTag: AiTagGallerySourceAdapter(dio: dio),
    GallerySourceId.quickTagCloud: ref.watch(
      quickTagCloudGallerySourceAdapterProvider,
    ),
  };
}

final onlineGallerySourceAdaptersProvider =
    Provider<Map<GallerySourceId, GallerySourceAdapter>>(
      onlineGallerySourceAdapters,
      name: 'onlineGallerySourceAdaptersProvider',
    );

typedef OnlineGallerySourceAdaptersRef =
    // ignore: deprecated_member_use
    ProviderRef<Map<GallerySourceId, GallerySourceAdapter>>;

final onlineGalleryRepositoryProvider = Provider<OnlineGalleryRepository>((
  ref,
) {
  return OnlineGalleryRepository(
    adapters: ref.watch(onlineGallerySourceAdaptersProvider),
    danbooruApi: ref.watch(danbooruApiServiceProvider),
    gelbooruApi: ref.watch(gelbooruApiServiceProvider),
  );
});

final onlineGalleryQueryProvider = Provider<OnlineGalleryQuery>(
  (ref) => const OnlineGalleryQuery(),
);
