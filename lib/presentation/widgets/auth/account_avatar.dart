import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/models/auth/saved_account.dart';

/// 账号头像组件
/// 支持显示自定义头像或昵称首字
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.account,
    this.size = 48,
    this.onTap,
    this.showEditBadge = true,
  });

  final SavedAccount account;
  final double size;
  final VoidCallback? onTap;
  final bool showEditBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        customBorder: const CircleBorder(side: BorderSide.none),
        child: Padding(
          padding: EdgeInsets.all(showEditBadge ? size * 0.15 : 0),
          child: Stack(
            children: [
              _buildAvatar(context),
              if (showEditBadge) _buildEditBadge(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final theme = Theme.of(context);
    final avatarPath = account.avatarPath;

    // 如果有头像路径且文件存在，显示图片
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final avatarFile = File(avatarPath);
      if (avatarFile.existsSync()) {
        // 使用 Image.memory 绕过 FileImage 缓存问题
        // 因为 FileImage 会缓存同一路径的图片，导致更新后显示旧图片
        return FutureBuilder<Uint8List>(
          future: avatarFile.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return CircleAvatar(
                radius: size / 2,
                backgroundImage: MemoryImage(snapshot.data!),
              );
            }
            // 加载中或失败时显示默认头像
            return _buildDefaultAvatar(theme);
          },
        );
      }
    }

    // 默认头像：显示昵称首字
    return _buildDefaultAvatar(theme);
  }

  Widget _buildDefaultAvatar(ThemeData theme) {
    final firstChar = account.displayName.isNotEmpty
        ? account.displayName.characters.first.toUpperCase()
        : '?';

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _getColorFromName(account.displayName, theme),
      child: Text(
        firstChar,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEditBadge(BuildContext context) {
    final theme = Theme.of(context);
    final badgeSize = size * 0.3;

    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.surface,
            width: 2,
          ),
        ),
        child: Icon(
          Icons.camera_alt,
          size: badgeSize * 0.6,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  /// 根据名称生成稳定的颜色
  Color _getColorFromName(String name, ThemeData theme) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
    ];

    if (name.isEmpty) {
      return theme.colorScheme.primary;
    }

    return colors[name.hashCode.abs() % colors.length];
  }
}

/// 简化版头像组件，用于列表项
class AccountAvatarSmall extends StatelessWidget {
  const AccountAvatarSmall({
    super.key,
    required this.account,
    this.size = 40,
    this.isSelected = false,
  });

  final SavedAccount account;
  final double size;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarPath = account.avatarPath;

    // 如果有头像路径且文件存在，显示图片
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final avatarFile = File(avatarPath);
      if (avatarFile.existsSync()) {
        // 使用 Image.memory 绕过 FileImage 缓存问题
        return FutureBuilder<Uint8List>(
          future: avatarFile.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Container(
                decoration: isSelected
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      )
                    : null,
                child: CircleAvatar(
                  radius: size / 2,
                  backgroundImage: MemoryImage(snapshot.data!),
                ),
              );
            }
            // 加载中或失败时显示默认头像
            return _buildDefaultAvatar(theme, isSelected);
          },
        );
      }
    }

    // 默认头像：显示昵称首字
    return _buildDefaultAvatar(theme, isSelected);
  }

  Widget _buildDefaultAvatar(ThemeData theme, bool isSelected) {
    final firstChar = account.displayName.isNotEmpty
        ? account.displayName.characters.first.toUpperCase()
        : '?';

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
    ];

    final bgColor = account.displayName.isEmpty
        ? theme.colorScheme.primary
        : colors[account.displayName.hashCode.abs() % colors.length];

    return Container(
      decoration: isSelected
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            )
          : null,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: bgColor,
        child: Text(
          firstChar,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
