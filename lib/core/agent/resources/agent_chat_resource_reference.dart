import 'package:collection/collection.dart';

/// Resource types that can be attached to an Agent chat without embedding the
/// underlying resource itself.
enum AgentChatResourceKind {
  onlineGalleryMedia,
  localGalleryImage,
  generatedImage,
  inpaintDraft,
  fixedTag,
  tagLibraryEntry,
  vibeLibraryEntry,
  preciseRefLibraryEntry,
}

/// A small, versioned pointer to an application-owned resource.
///
/// [resourceId] is the stable identity inside [source]. [mediaId] may identify
/// one item when that resource contains multiple media items. The metadata
/// maps are intentionally string-only so references cannot become a second
/// transport for arbitrary payloads.
final class AgentChatResourceReference {
  AgentChatResourceReference({
    this.version = currentVersion,
    required this.kind,
    required this.source,
    required this.resourceId,
    this.mediaId,
    Map<String, String> display = const {},
    Map<String, String> provenance = const {},
  }) : display = Map.unmodifiable(display),
       provenance = Map.unmodifiable(provenance);

  static const int currentVersion = 1;

  final int version;
  final AgentChatResourceKind kind;
  final String source;
  final String resourceId;
  final String? mediaId;
  final Map<String, String> display;
  final Map<String, String> provenance;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AgentChatResourceReference &&
            version == other.version &&
            kind == other.kind &&
            source == other.source &&
            resourceId == other.resourceId &&
            mediaId == other.mediaId &&
            const MapEquality<String, String>().equals(
              display,
              other.display,
            ) &&
            const MapEquality<String, String>().equals(
              provenance,
              other.provenance,
            );
  }

  @override
  int get hashCode => Object.hash(
    version,
    kind,
    source,
    resourceId,
    mediaId,
    const MapEquality<String, String>().hash(display),
    const MapEquality<String, String>().hash(provenance),
  );
}
