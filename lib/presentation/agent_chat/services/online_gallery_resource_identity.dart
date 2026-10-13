import '../../../core/agent/resources/agent_chat_resource_identifier.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../data/models/online_gallery/gallery_item.dart';
import '../../../data/models/online_gallery/gallery_source.dart';

/// Source work identity behind an online gallery resource reference.
///
/// The only place that maps raw gallery ids to and from reference ids.
final class OnlineGalleryResourceIdentity {
  const OnlineGalleryResourceIdentity({
    required this.source,
    required this.workId,
    this.mediaId,
  });

  OnlineGalleryResourceIdentity.coverOf(GalleryItem item)
    : this(
        source: item.sourceId,
        workId: item.sourceWorkId,
        mediaId: item.coverMediaId,
      );

  final GallerySourceId source;
  final String workId;
  final String? mediaId;

  /// Returns null for other kinds, unknown sources, or malformed ids.
  static OnlineGalleryResourceIdentity? fromReference(
    AgentChatResourceReference reference,
  ) {
    if (reference.kind != AgentChatResourceKind.onlineGalleryMedia) {
      return null;
    }
    final source = GallerySourceId.values
        .where((value) => value.key == reference.source)
        .firstOrNull;
    final workId = AgentChatResourceIdentifier.decode(reference.resourceId);
    if (source == null || workId == null) return null;
    final encodedMediaId = reference.mediaId;
    final mediaId = encodedMediaId == null
        ? null
        : AgentChatResourceIdentifier.decode(encodedMediaId);
    if (encodedMediaId != null && mediaId == null) return null;
    return OnlineGalleryResourceIdentity(
      source: source,
      workId: workId,
      // Placeholder covers never appear in detail media; they mean the first.
      mediaId: GalleryMedia.isPlaceholderId(mediaId, workId) ? null : mediaId,
    );
  }

  AgentChatResourceReference toReference({
    Map<String, String> display = const {},
  }) => AgentChatResourceReference(
    kind: AgentChatResourceKind.onlineGalleryMedia,
    source: source.key,
    resourceId: AgentChatResourceIdentifier.encode(workId),
    mediaId: switch (mediaId) {
      final mediaId? => AgentChatResourceIdentifier.encode(mediaId),
      null => null,
    },
    display: display,
  );
}
