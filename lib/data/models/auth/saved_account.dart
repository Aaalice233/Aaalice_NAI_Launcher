import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'saved_account.freezed.dart';
part 'saved_account.g.dart';

/// 账号类型
enum AccountType {
  /// API Token 登录
  token,
}

/// 已保存的账号
@freezed
class SavedAccount with _$SavedAccount {
  const SavedAccount._();

  const factory SavedAccount({
    /// 账号唯一ID
    required String id,

    /// 邮箱或标识符（Token 账号可使用自定义名称）
    required String email,

    /// 昵称（用于显示和生成默认头像）
    /// @Default 用于 freezed 构造函数，@JsonKey 用于 JSON 反序列化兼容旧数据
    @Default('') @JsonKey(defaultValue: '') String nickname,

    /// 头像本地路径（null 表示使用默认头像-昵称首字）
    String? avatarPath,

    /// 创建时间
    required DateTime createdAt,

    /// 最后使用时间
    DateTime? lastUsedAt,

    /// 是否为默认账号
    @Default(false) bool isDefault,

    /// 账号类型
    @Default(AccountType.token) AccountType accountType,
  }) = _SavedAccount;

  factory SavedAccount.fromJson(Map<String, dynamic> json) =>
      _$SavedAccountFromJson(json);

  /// 创建新账号
  factory SavedAccount.create({
    required String email,
    String nickname = '',
    String? avatarPath,
    bool isDefault = false,
    AccountType accountType = AccountType.token,
  }) {
    return SavedAccount(
      id: const Uuid().v4(),
      email: email,
      nickname: nickname,
      avatarPath: avatarPath,
      createdAt: DateTime.now(),
      isDefault: isDefault,
      accountType: accountType,
    );
  }

  /// 显示名称（优先使用昵称，否则使用邮箱标识）
  String get displayName => nickname.isNotEmpty ? nickname : email;

  /// 邮箱的掩码版本（用于安全显示）
  String get maskedEmail {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '$name***@$domain';
    }
    return '${name.substring(0, 2)}***@$domain';
  }
}
