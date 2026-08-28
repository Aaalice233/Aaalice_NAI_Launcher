import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../core/database/database_providers.dart';
import '../../../data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../../data/models/online_gallery/gallery_item.dart';
import '../../../data/models/online_gallery/gallery_source.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/online_gallery_provider.dart';
import '../../providers/precise_ref_library_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../providers/vibe_library_provider.dart';

final class ResolvedAgentResource {
  const ResolvedAgentResource({
    required this.reference,
    required this.label,
    this.bytes,
    this.text,
    this.vibeEntryId,
    this.preciseReferenceEntryId,
  });

  final AgentChatResourceReference reference;
  final String label;
  final Uint8List? bytes;
  final String? text;
  final String? vibeEntryId;
  final String? preciseReferenceEntryId;
}

typedef InpaintDraftImageLoader =
    Future<Uint8List?> Function(String draftId, {required bool mask});

/// Resolves validated stable resource references through application owners.
class AgentResourceResolver {
  AgentResourceResolver(this._ref, {this.loadInpaintDraftImage});

  final Ref _ref;
  final InpaintDraftImageLoader? loadInpaintDraftImage;

  AgentChatResourceReference decode(dynamic value) {
    if (value is! Map) {
      throw const FormatException('resource_ref must be an object');
    }
    return AgentChatResourceReferenceCodec.decodeJsonMap(
      Map<String, dynamic>.from(value),
    );
  }

  Future<ResolvedAgentResource?> resolve(
    AgentChatResourceReference reference,
  ) async {
    switch (reference.kind) {
      case AgentChatResourceKind.localGalleryImage:
        return _resolveLocal(reference);
      case AgentChatResourceKind.generatedImage:
        return _resolveGenerated(reference);
      case AgentChatResourceKind.onlineGalleryMedia:
        return _resolveOnline(reference);
      case AgentChatResourceKind.inpaintDraft:
        return _resolveInpaint(reference);
      case AgentChatResourceKind.fixedTag:
        return _resolveFixedTag(reference);
      case AgentChatResourceKind.tagLibraryEntry:
        return _resolveTagLibrary(reference);
      case AgentChatResourceKind.vibeLibraryEntry:
        return _resolveVibe(reference);
      case AgentChatResourceKind.preciseRefLibraryEntry:
        return _resolvePreciseReference(reference);
    }
  }

  Future<bool> exists(AgentChatResourceReference reference) async {
    switch (reference.kind) {
      case AgentChatResourceKind.localGalleryImage:
        final id = int.tryParse(reference.resourceId);
        if (id == null) return false;
        final source = (await _ref.read(
          databaseManagerProvider.future,
        )).galleryDataSource;
        final record = await source?.getImageById(id);
        return record != null &&
            !record.isDeleted &&
            await File(record.filePath).exists();
      case AgentChatResourceKind.generatedImage:
        return _ref
                .read(imageGenerationNotifierProvider)
                .findImageById(reference.resourceId) !=
            null;
      case AgentChatResourceKind.onlineGalleryMedia:
        return _onlineExists(reference);
      case AgentChatResourceKind.inpaintDraft:
        return await loadInpaintDraftImage?.call(
              reference.resourceId,
              mask: reference.mediaId == 'mask',
            ) !=
            null;
      case AgentChatResourceKind.fixedTag:
        return _ref
            .read(fixedTagsNotifierProvider)
            .entries
            .any((entry) => entry.id == reference.resourceId);
      case AgentChatResourceKind.tagLibraryEntry:
        return _ref
            .read(tagLibraryPageNotifierProvider)
            .entries
            .any((entry) => entry.id == reference.resourceId);
      case AgentChatResourceKind.vibeLibraryEntry:
        final notifier = _ref.read(vibeLibraryNotifierProvider.notifier);
        await notifier.initialize();
        return (await notifier.resolveEntriesByIds([
          reference.resourceId,
        ])).isNotEmpty;
      case AgentChatResourceKind.preciseRefLibraryEntry:
        final notifier = _ref.read(preciseRefLibraryNotifierProvider.notifier);
        await notifier.initialize();
        final entry = _ref
            .read(preciseRefLibraryNotifierProvider)
            .entries
            .where((value) => value.id == reference.resourceId)
            .firstOrNull;
        return entry != null && await File(entry.imagePath).exists();
    }
  }

  /// Checks only state already owned by the application. It never searches a
  /// remote gallery or initializes a resource library merely to render a
  /// pending composer card.
  Future<bool> existsWithoutExternalResolution(
    AgentChatResourceReference reference,
  ) async {
    switch (reference.kind) {
      case AgentChatResourceKind.onlineGalleryMedia:
        final source = GallerySourceId.values
            .where((value) => value.key == reference.source)
            .firstOrNull;
        if (source == null) return false;
        final visibleItem = _ref
            .read(onlineGalleryNotifierProvider)
            .posts
            .where(
              (value) =>
                  value.sourceId == source &&
                  value.sourceWorkId == reference.resourceId,
            )
            .firstOrNull;
        if (visibleItem == null) {
          return _ref.read(onlineGallerySourceAdaptersProvider)[source] != null;
        }
        return reference.mediaId == null ||
            reference.mediaId == visibleItem.cover.id;
      case AgentChatResourceKind.vibeLibraryEntry:
        final entries = _ref.read(vibeLibraryNotifierProvider).entries;
        return entries.isEmpty ||
            entries.any((entry) => entry.id == reference.resourceId);
      case AgentChatResourceKind.preciseRefLibraryEntry:
        final entries = _ref.read(preciseRefLibraryNotifierProvider).entries;
        if (entries.isEmpty) return true;
        final entry = entries
            .where((value) => value.id == reference.resourceId)
            .firstOrNull;
        return entry != null && await File(entry.imagePath).exists();
      default:
        return exists(reference);
    }
  }

  Future<bool> _onlineExists(AgentChatResourceReference reference) async {
    final source = GallerySourceId.values
        .where((value) => value.key == reference.source)
        .firstOrNull;
    if (source == null) return false;
    final visibleItem = _ref
        .read(onlineGalleryNotifierProvider)
        .posts
        .where(
          (value) =>
              value.sourceId == source &&
              value.sourceWorkId == reference.resourceId,
        )
        .firstOrNull;
    if (visibleItem != null &&
        (reference.mediaId == null ||
            reference.mediaId == visibleItem.cover.id)) {
      return true;
    }
    final adapter = _ref.read(onlineGallerySourceAdaptersProvider)[source];
    if (adapter == null) return false;
    GalleryItem? item = visibleItem;
    if (item == null &&
        (source == GallerySourceId.danbooru ||
            source == GallerySourceId.safebooru ||
            source == GallerySourceId.gelbooru)) {
      final page = await adapter.search(
        GallerySearchRequest(
          cursor: '1',
          pageSize: 1,
          query: 'id:${reference.resourceId}',
        ),
      );
      item = page.items
          .where((value) => value.sourceWorkId == reference.resourceId)
          .firstOrNull;
      if (item == null) return false;
    }
    item ??= GalleryItem(
      id: int.tryParse(reference.resourceId) ?? 0,
      workId: reference.resourceId,
      sourceId: source,
      focusedMediaId: reference.mediaId,
    );
    final detail = await adapter.detail(item, cancelToken: CancelToken());
    return reference.mediaId == null ||
        detail.media.any((media) => media.id == reference.mediaId);
  }

  Future<ResolvedAgentResource?> _resolveLocal(
    AgentChatResourceReference reference,
  ) async {
    final id = int.tryParse(reference.resourceId);
    if (id == null) return null;
    final source = (await _ref.read(
      databaseManagerProvider.future,
    )).galleryDataSource;
    final record = await source?.getImageById(id);
    if (record == null || record.isDeleted) return null;
    final file = File(record.filePath);
    if (!await file.exists()) return null;
    return ResolvedAgentResource(
      reference: reference,
      label: record.fileName,
      bytes: await file.readAsBytes(),
    );
  }

  ResolvedAgentResource? _resolveGenerated(
    AgentChatResourceReference reference,
  ) {
    final image = _ref
        .read(imageGenerationNotifierProvider)
        .findImageById(reference.resourceId);
    if (image == null) return null;
    return ResolvedAgentResource(
      reference: reference,
      label: reference.display['label'] ?? 'Generated image',
      bytes: image.bytes,
    );
  }

  Future<ResolvedAgentResource?> _resolveOnline(
    AgentChatResourceReference reference,
  ) async {
    final source = GallerySourceId.values
        .where((value) => value.key == reference.source)
        .firstOrNull;
    if (source == null) return null;
    GalleryItem? item = _ref
        .read(onlineGalleryNotifierProvider)
        .posts
        .where(
          (value) =>
              value.sourceId == source &&
              value.sourceWorkId == reference.resourceId,
        )
        .firstOrNull;
    final adapter = _ref.read(onlineGallerySourceAdaptersProvider)[source]!;
    if (item == null) {
      if (source == GallerySourceId.danbooru ||
          source == GallerySourceId.safebooru ||
          source == GallerySourceId.gelbooru) {
        final page = await adapter.search(
          GallerySearchRequest(
            cursor: '1',
            pageSize: 1,
            query: 'id:${reference.resourceId}',
          ),
        );
        item = page.items
            .where((value) => value.sourceWorkId == reference.resourceId)
            .firstOrNull;
      } else {
        item = GalleryItem(
          id: int.tryParse(reference.resourceId) ?? 0,
          workId: reference.resourceId,
          sourceId: source,
          focusedMediaId: reference.mediaId,
        );
      }
    }
    if (item == null) return null;
    final detail = await adapter.detail(item, cancelToken: CancelToken());
    final media = reference.mediaId == null
        ? detail.media.firstOrNull
        : detail.media
              .where((value) => value.id == reference.mediaId)
              .firstOrNull;
    if (media == null) return null;
    final url = media.displayUrl.isNotEmpty
        ? media.displayUrl
        : (media.downloadUrl.isNotEmpty ? media.downloadUrl : media.previewUrl);
    if (url.isEmpty) return null;
    final file = await OnlineGalleryImageCacheManager.instance.getSingleFile(
      url,
      key: onlineGalleryImageCacheKeyForUrl(url),
      headers: onlineGalleryImageHeadersForUrl(url),
    );
    return ResolvedAgentResource(
      reference: reference,
      label:
          reference.display['label'] ??
          detail.item.title ??
          '${source.label} ${reference.resourceId}',
      bytes: await file.readAsBytes(),
      text: media.prompt ?? detail.prompt,
    );
  }

  Future<ResolvedAgentResource?> _resolveInpaint(
    AgentChatResourceReference reference,
  ) async {
    final bytes = await loadInpaintDraftImage?.call(
      reference.resourceId,
      mask: reference.mediaId == 'mask',
    );
    if (bytes == null) return null;
    return ResolvedAgentResource(
      reference: reference,
      label: reference.display['label'] ?? 'Inpaint draft',
      bytes: bytes,
    );
  }

  ResolvedAgentResource? _resolveFixedTag(
    AgentChatResourceReference reference,
  ) {
    final entry = _ref
        .read(fixedTagsNotifierProvider)
        .entries
        .where((value) => value.id == reference.resourceId)
        .firstOrNull;
    if (entry == null) return null;
    return ResolvedAgentResource(
      reference: reference,
      label: entry.displayName,
      text: entry.content,
    );
  }

  ResolvedAgentResource? _resolveTagLibrary(
    AgentChatResourceReference reference,
  ) {
    final entry = _ref
        .read(tagLibraryPageNotifierProvider)
        .entries
        .where((value) => value.id == reference.resourceId)
        .firstOrNull;
    if (entry == null) return null;
    return ResolvedAgentResource(
      reference: reference,
      label: entry.name,
      text: entry.content,
    );
  }

  Future<ResolvedAgentResource?> _resolveVibe(
    AgentChatResourceReference reference,
  ) async {
    final notifier = _ref.read(vibeLibraryNotifierProvider.notifier);
    await notifier.initialize();
    final entry = (await notifier.resolveEntriesByIds([
      reference.resourceId,
    ])).firstOrNull;
    if (entry == null) return null;
    return ResolvedAgentResource(
      reference: reference,
      label: entry.displayName,
      bytes: entry.rawImageData ?? entry.thumbnail ?? entry.vibeThumbnail,
      vibeEntryId: entry.id,
    );
  }

  Future<ResolvedAgentResource?> _resolvePreciseReference(
    AgentChatResourceReference reference,
  ) async {
    final notifier = _ref.read(preciseRefLibraryNotifierProvider.notifier);
    await notifier.initialize();
    final entry = _ref
        .read(preciseRefLibraryNotifierProvider)
        .entries
        .where((value) => value.id == reference.resourceId)
        .firstOrNull;
    if (entry == null) return null;
    final file = File(entry.imagePath);
    if (!await file.exists()) return null;
    return ResolvedAgentResource(
      reference: reference,
      label: entry.name,
      bytes: await file.readAsBytes(),
      preciseReferenceEntryId: entry.id,
    );
  }
}
