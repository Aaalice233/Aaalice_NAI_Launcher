import 'package:dio/dio.dart';

import '../../../core/online_gallery/gallery_tag_query.dart';
import '../../datasources/remote/gelbooru_api_service.dart';
import '../../datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../models/online_gallery/gallery_source.dart';
import 'online_gallery_artist_hunt_service.dart';

enum OnlineGalleryFailureCode {
  tooManySearchTags,
  unsupportedMetatag,
  credentialsRequired,
  credentialsInvalid,
  rateLimited,
  timeout,
  server,
  network,
  malformedResponse,
  detailNotFound,
  imageUnavailable,
  rankingProcessing,
  configurationUnavailable,
  requestFailed,
  gelbooruCredentialsRequired,
  gelbooruCredentialsInvalid,
  gelbooruRateLimited,
  gelbooruTimeout,
  gelbooruServer,
  gelbooruNetwork,
  gelbooruMalformedResponse,
  gelbooruRequestFailed,
  artistHuntDetailFailed,
}

class OnlineGalleryErrorMapper {
  const OnlineGalleryErrorMapper();

  OnlineGalleryFailureCode map(Object error, GallerySourceId activeSource) {
    if (error is GalleryTagQueryLimitException) {
      return OnlineGalleryFailureCode.tooManySearchTags;
    }
    if (error is GalleryTagMetatagUnsupportedException) {
      return OnlineGalleryFailureCode.unsupportedMetatag;
    }
    if (error is OnlineGalleryArtistHuntDetailException) {
      return OnlineGalleryFailureCode.artistHuntDetailFailed;
    }
    if (error is GallerySourceException) {
      if (error.source == GallerySourceId.gelbooru) {
        return switch (error.code) {
          GallerySourceErrorCode.credentialsRequired =>
            OnlineGalleryFailureCode.gelbooruCredentialsRequired,
          GallerySourceErrorCode.credentialsInvalid =>
            OnlineGalleryFailureCode.gelbooruCredentialsInvalid,
          GallerySourceErrorCode.rateLimited =>
            OnlineGalleryFailureCode.gelbooruRateLimited,
          GallerySourceErrorCode.timeout =>
            OnlineGalleryFailureCode.gelbooruTimeout,
          GallerySourceErrorCode.server =>
            OnlineGalleryFailureCode.gelbooruServer,
          GallerySourceErrorCode.network =>
            OnlineGalleryFailureCode.gelbooruNetwork,
          GallerySourceErrorCode.malformedResponse =>
            OnlineGalleryFailureCode.gelbooruMalformedResponse,
          _ => OnlineGalleryFailureCode.gelbooruRequestFailed,
        };
      }
      return switch (error.code) {
        GallerySourceErrorCode.credentialsRequired =>
          OnlineGalleryFailureCode.credentialsRequired,
        GallerySourceErrorCode.credentialsInvalid =>
          OnlineGalleryFailureCode.credentialsInvalid,
        GallerySourceErrorCode.rateLimited =>
          OnlineGalleryFailureCode.rateLimited,
        GallerySourceErrorCode.timeout => OnlineGalleryFailureCode.timeout,
        GallerySourceErrorCode.server => OnlineGalleryFailureCode.server,
        GallerySourceErrorCode.network => OnlineGalleryFailureCode.network,
        GallerySourceErrorCode.malformedResponse =>
          OnlineGalleryFailureCode.malformedResponse,
        GallerySourceErrorCode.detailNotFound =>
          OnlineGalleryFailureCode.detailNotFound,
        GallerySourceErrorCode.imageUnavailable =>
          OnlineGalleryFailureCode.imageUnavailable,
        GallerySourceErrorCode.rankingProcessing =>
          OnlineGalleryFailureCode.rankingProcessing,
        GallerySourceErrorCode.configurationUnavailable =>
          OnlineGalleryFailureCode.configurationUnavailable,
        GallerySourceErrorCode.unknown =>
          OnlineGalleryFailureCode.requestFailed,
      };
    }
    if (error is GelbooruApiException) {
      return switch (error.type) {
        GelbooruApiErrorType.invalidCredentials =>
          OnlineGalleryFailureCode.gelbooruCredentialsInvalid,
        GelbooruApiErrorType.rateLimited =>
          OnlineGalleryFailureCode.gelbooruRateLimited,
        GelbooruApiErrorType.timeout =>
          OnlineGalleryFailureCode.gelbooruTimeout,
        GelbooruApiErrorType.server => OnlineGalleryFailureCode.gelbooruServer,
        GelbooruApiErrorType.network =>
          OnlineGalleryFailureCode.gelbooruNetwork,
        GelbooruApiErrorType.malformedResponse =>
          OnlineGalleryFailureCode.gelbooruMalformedResponse,
        GelbooruApiErrorType.cancelled || GelbooruApiErrorType.unknown =>
          OnlineGalleryFailureCode.gelbooruRequestFailed,
      };
    }
    if (error is DioException) {
      return map(mapGalleryDioException(error, activeSource), activeSource);
    }
    return OnlineGalleryFailureCode.requestFailed;
  }
}
