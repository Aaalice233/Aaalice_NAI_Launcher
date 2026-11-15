import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/gelbooru_auth_service.dart';
import '../../data/services/online_gallery/artist_chain_parser.dart';
import '../../data/services/online_gallery/online_gallery_error_mapper.dart';
import 'online_gallery_state.dart';

const int onlineGalleryPageSize = 60;

class GalleryPageJumpTarget {
  const GalleryPageJumpTarget({
    required this.page,
    required this.itemIndex,
    required this.stableKey,
  });

  final int page;
  final int itemIndex;
  final String stableKey;
}

String resolveOnlineGalleryEffectivePrompt(
  String prompt, {
  required bool isArtistHuntActive,
}) {
  return isArtistHuntActive
      ? ArtistChainParser.withArtistConstraint(prompt)
      : prompt;
}

int resolveOnlineGalleryServerOrdinaryTagLimit({
  required GallerySourceId sourceId,
  required DanbooruAuthState danbooruAuth,
  required GelbooruAuthState gelbooruAuth,
}) {
  final capability = sourceId.capabilities.tagSearch;
  final authenticated = switch (sourceId) {
    GallerySourceId.danbooru => danbooruAuth.isLoggedIn,
    GallerySourceId.gelbooru => gelbooruAuth.isAuthenticated,
    _ => false,
  };
  final accountLevel = sourceId == GallerySourceId.danbooru
      ? danbooruAuth.user?.level
      : null;
  return capability.serverLimit(
    authenticated: authenticated,
    accountLevel: accountLevel,
  );
}

OnlineGalleryErrorCode mapOnlineGalleryErrorCode(
  Object error,
  GallerySourceId activeSourceId, {
  OnlineGalleryErrorMapper errorMapper = const OnlineGalleryErrorMapper(),
}) => switch (errorMapper.map(error, activeSourceId)) {
  OnlineGalleryFailureCode.tooManySearchTags =>
    OnlineGalleryErrorCode.tooManySearchTags,
  OnlineGalleryFailureCode.unsupportedMetatag =>
    OnlineGalleryErrorCode.unsupportedMetatag,
  OnlineGalleryFailureCode.credentialsRequired =>
    OnlineGalleryErrorCode.credentialsRequired,
  OnlineGalleryFailureCode.credentialsInvalid =>
    OnlineGalleryErrorCode.credentialsInvalid,
  OnlineGalleryFailureCode.rateLimited => OnlineGalleryErrorCode.rateLimited,
  OnlineGalleryFailureCode.timeout => OnlineGalleryErrorCode.timeout,
  OnlineGalleryFailureCode.server => OnlineGalleryErrorCode.server,
  OnlineGalleryFailureCode.network => OnlineGalleryErrorCode.network,
  OnlineGalleryFailureCode.malformedResponse =>
    OnlineGalleryErrorCode.malformedResponse,
  OnlineGalleryFailureCode.detailNotFound =>
    OnlineGalleryErrorCode.detailNotFound,
  OnlineGalleryFailureCode.imageUnavailable =>
    OnlineGalleryErrorCode.imageUnavailable,
  OnlineGalleryFailureCode.rankingProcessing =>
    OnlineGalleryErrorCode.rankingProcessing,
  OnlineGalleryFailureCode.configurationUnavailable =>
    OnlineGalleryErrorCode.configurationUnavailable,
  OnlineGalleryFailureCode.requestFailed =>
    OnlineGalleryErrorCode.requestFailed,
  OnlineGalleryFailureCode.gelbooruCredentialsRequired =>
    OnlineGalleryErrorCode.gelbooruCredentialsRequired,
  OnlineGalleryFailureCode.gelbooruCredentialsInvalid =>
    OnlineGalleryErrorCode.gelbooruCredentialsInvalid,
  OnlineGalleryFailureCode.gelbooruRateLimited =>
    OnlineGalleryErrorCode.gelbooruRateLimited,
  OnlineGalleryFailureCode.gelbooruTimeout =>
    OnlineGalleryErrorCode.gelbooruTimeout,
  OnlineGalleryFailureCode.gelbooruServer =>
    OnlineGalleryErrorCode.gelbooruServer,
  OnlineGalleryFailureCode.gelbooruNetwork =>
    OnlineGalleryErrorCode.gelbooruNetwork,
  OnlineGalleryFailureCode.gelbooruMalformedResponse =>
    OnlineGalleryErrorCode.gelbooruMalformedResponse,
  OnlineGalleryFailureCode.gelbooruRequestFailed =>
    OnlineGalleryErrorCode.gelbooruRequestFailed,
  OnlineGalleryFailureCode.artistHuntDetailFailed =>
    OnlineGalleryErrorCode.artistHuntDetailFailed,
};
