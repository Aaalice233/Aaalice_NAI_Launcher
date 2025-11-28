import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'saved_account.freezed.dart';
part 'saved_account.g.dart';

/// 已保存的账号
@freezed
class SavedAccount with _$SavedAccount {
  const SavedAccount._();

  const factory SavedAccount({
    /// 账号唯一ID
    required String id,

    /// 邮箱
    required String email,

    /// 昵称（可选，用于显示）
    String? nickname,

    /// 创建时间
    required DateTime createdAt,

    /// 最后使用时间
    DateTime? lastUsedAt,

    /// 是否为默认账号
    @Default(false) bool isDefault,
  }) = _SavedAccount;

  factory SavedAccount.fromJson(Map<String, dynamic> json) =>
      _$SavedAccountFromJson(json);

  /// 创建新账号
  factory SavedAccount.create({
    required String email,
    String? nickname,
    bool isDefault = false,
  }) {
    return SavedAccount(
      id: const Uuid().v4(),
      email: email,
      nickname: nickname,
      createdAt: DateTime.now(),
      isDefault: isDefault,
    );
  }

  /// 显示名称（优先使用昵称，否则使用邮箱）
  String get displayName => nickname ?? email;

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
