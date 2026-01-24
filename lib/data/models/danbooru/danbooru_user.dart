import 'package:freezed_annotation/freezed_annotation.dart';

part 'danbooru_user.freezed.dart';
part 'danbooru_user.g.dart';

/// Danbooru 用户模型
@freezed
class DanbooruUser with _$DanbooruUser {
  const DanbooruUser._();

  const factory DanbooruUser({
    required int id,
    required String name,
    @JsonKey(name: 'level') @Default(20) int level,
    @JsonKey(name: 'level_string') @Default('Member') String levelString,
    @JsonKey(name: 'post_upload_count') @Default(0) int postUploadCount,
    @JsonKey(name: 'post_update_count') @Default(0) int postUpdateCount,
    @JsonKey(name: 'note_update_count') @Default(0) int noteUpdateCount,
    @JsonKey(name: 'is_banned') @Default(false) bool isBanned,
    @JsonKey(name: 'can_approve_posts') @Default(false) bool canApprovePosts,
    @JsonKey(name: 'can_upload_free') @Default(false) bool canUploadFree,
    @JsonKey(name: 'is_super_voter') @Default(false) bool isSuperVoter,
    @JsonKey(name: 'favorite_count') @Default(0) int favoriteCount,
  }) = _DanbooruUser;

  factory DanbooruUser.fromJson(Map<String, dynamic> json) =>
      _$DanbooruUserFromJson(json);

  /// 是否为高级用户（Gold+）
  bool get isPremium => level >= 30;

  /// 是否为版主
  bool get isModerator => level >= 40;

  /// 是否为管理员
  bool get isAdmin => level >= 50;

  /// 获取用户等级名称
  String get levelName {
    switch (level) {
      case 10:
        return 'Restricted';
      case 20:
        return 'Member';
      case 30:
        return 'Gold';
      case 31:
        return 'Platinum';
      case 32:
        return 'Builder';
      case 35:
        return 'Contributor';
      case 40:
        return 'Approver';
      case 50:
        return 'Admin';
      default:
        return levelString;
    }
  }
}

/// Danbooru 认证凭据
@freezed
class DanbooruCredentials with _$DanbooruCredentials {
  const factory DanbooruCredentials({
    required String username,
    required String apiKey,
  }) = _DanbooruCredentials;

  factory DanbooruCredentials.fromJson(Map<String, dynamic> json) =>
      _$DanbooruCredentialsFromJson(json);
}
