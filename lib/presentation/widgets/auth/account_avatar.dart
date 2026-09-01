import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/services/avatar_image_cache.dart';
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
        splashColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.2),
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

    if (avatarPath == null || avatarPath.isEmpty) {
      return _buildDefaultAvatar(theme);
    }

    final cachedBytes = AvatarImageCache.instance.get(avatarPath);
    if (cachedBytes != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: MemoryImage(cachedBytes),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: AvatarImageCache.instance.load(avatarPath),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return CircleAvatar(
            radius: size / 2,
            backgroundImage: MemoryImage(bytes),
          );
        }
        return _buildDefaultAvatar(theme);
      },
    );
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
          border: Border.all(color: theme.colorScheme.surface, width: 2),
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

    if (avatarPath == null || avatarPath.isEmpty) {
      return _buildDefaultAvatar(theme, isSelected);
    }

    final cachedBytes = AvatarImageCache.instance.get(avatarPath);
    if (cachedBytes != null) {
      return _buildImageAvatar(theme, cachedBytes);
    }

    return FutureBuilder<Uint8List?>(
      future: AvatarImageCache.instance.load(avatarPath),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return bytes == null
            ? _buildDefaultAvatar(theme, isSelected)
            : _buildImageAvatar(theme, bytes);
      },
    );
  }

  Widget _buildImageAvatar(ThemeData theme, Uint8List bytes) {
    return Container(
      decoration: isSelected
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: CircleAvatar(
        radius: size / 2,
        backgroundImage: MemoryImage(bytes),
      ),
    );
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
              border: Border.all(color: theme.colorScheme.primary, width: 2),
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
