import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/auth/saved_account.dart';
import '../../providers/account_manager_provider.dart';
import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';
import '../auth/account_avatar.dart';
import '../auth/token_login_card.dart';

class MainNavRail extends ConsumerWidget {
  const MainNavRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).matchedLocation;

    int selectedIndex = 0;
    if (location == AppRoutes.gallery) selectedIndex = 1;
    if (location == AppRoutes.promptConfig) selectedIndex = 2;
    if (location == AppRoutes.onlineGallery) selectedIndex = 3;
    if (location == AppRoutes.settings) selectedIndex = 5;

    return Container(
      width: 60,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // 账户头像区域
          _AccountAvatarButton(ref: ref),
          
          // Navigation Items
          _NavIcon(
            icon: Icons.brush, // Canvas/Edit
            label: context.l10n.nav_canvas,
            isSelected: selectedIndex == 0,
            onTap: () => context.go(AppRoutes.home),
          ),
          _NavIcon(
            icon: Icons.image, // Local Gallery
            label: context.l10n.nav_gallery,
            isSelected: selectedIndex == 1,
            onTap: () => context.go(AppRoutes.gallery),
          ),

          // 在线画廊
          _NavIcon(
            icon: Icons.photo_library, // Online Gallery
            label: context.l10n.nav_onlineGallery,
            isSelected: selectedIndex == 3,
            onTap: () => context.go(AppRoutes.onlineGallery),
          ),

          // 随机配置
          _NavIcon(
            icon: Icons.casino, // Random prompt config
            label: context.l10n.nav_randomConfig,
            isSelected: selectedIndex == 2,
            onTap: () => context.go(AppRoutes.promptConfig),
          ),

          // 词库（未来功能）
          _NavIcon(
            icon: Icons.book, // Tags/Dictionary placeholder
            label: context.l10n.nav_dictionary,
            isSelected: false,
            onTap: () {}, // 词库功能 - 待产品规划
            isDisabled: true,
          ),

          const Spacer(),
          
          // Discord 社群
          _ExternalLinkIcon(
            icon: Icons.discord,
            label: context.l10n.nav_discordCommunity,
            color: const Color(0xFF5865F2), // Discord 紫色
            url: 'https://discord.gg/R48n6GwXzD',
          ),
          
          // GitHub 仓库
          const _GitHubIcon(
            url: 'https://github.com/Aaalice233/Aaalice_NAI_Launcher',
          ),
          
          // Bottom Settings
          _NavIcon(
            icon: Icons.settings,
            label: context.l10n.nav_settings,
            isSelected: selectedIndex == 5,
            onTap: () => context.go(AppRoutes.settings),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// GitHub 图标（自定义绘制）
class _GitHubIcon extends StatefulWidget {
  final String url;

  const _GitHubIcon({required this.url});

  @override
  State<_GitHubIcon> createState() => _GitHubIconState();
}

class _GitHubIconState extends State<_GitHubIcon> {
  bool _isHovering = false;
  bool _isPressed = false;

  Future<void> _launchUrl() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark 
        ? Colors.white 
        : const Color(0xFF24292E);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _launchUrl,
          onHover: (val) => setState(() => _isHovering = val),
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedScale(
            scale: _isPressed ? 0.92 : (_isHovering ? 1.1 : 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _isHovering 
                    ? color.withOpacity(0.15) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(24, 24),
                  painter: _GitHubLogoPainter(
                    color: color.withOpacity(_isHovering ? 1.0 : 0.7),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// GitHub Logo 绘制器
class _GitHubLogoPainter extends CustomPainter {
  final Color color;

  _GitHubLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final scale = size.width / 24;
    
    // GitHub Octocat 简化路径
    path.moveTo(12 * scale, 0.5 * scale);
    path.cubicTo(5.37 * scale, 0.5 * scale, 0 * scale, 5.87 * scale, 0 * scale, 12.5 * scale);
    path.cubicTo(0 * scale, 17.83 * scale, 3.44 * scale, 22.31 * scale, 8.21 * scale, 23.75 * scale);
    path.cubicTo(8.81 * scale, 23.86 * scale, 9.02 * scale, 23.5 * scale, 9.02 * scale, 23.18 * scale);
    path.cubicTo(9.02 * scale, 22.9 * scale, 9.01 * scale, 22.21 * scale, 9.01 * scale, 21.29 * scale);
    path.cubicTo(5.67 * scale, 22.03 * scale, 4.97 * scale, 19.68 * scale, 4.97 * scale, 19.68 * scale);
    path.cubicTo(4.42 * scale, 18.42 * scale, 3.63 * scale, 18.05 * scale, 3.63 * scale, 18.05 * scale);
    path.cubicTo(2.55 * scale, 17.33 * scale, 3.71 * scale, 17.35 * scale, 3.71 * scale, 17.35 * scale);
    path.cubicTo(4.91 * scale, 17.43 * scale, 5.54 * scale, 18.55 * scale, 5.54 * scale, 18.55 * scale);
    path.cubicTo(6.61 * scale, 20.31 * scale, 8.36 * scale, 19.79 * scale, 9.05 * scale, 19.49 * scale);
    path.cubicTo(9.16 * scale, 18.77 * scale, 9.46 * scale, 18.25 * scale, 9.79 * scale, 17.96 * scale);
    path.cubicTo(7.14 * scale, 17.67 * scale, 4.34 * scale, 16.72 * scale, 4.34 * scale, 12.18 * scale);
    path.cubicTo(4.34 * scale, 10.99 * scale, 4.78 * scale, 10.02 * scale, 5.56 * scale, 9.25 * scale);
    path.cubicTo(5.44 * scale, 8.96 * scale, 5.04 * scale, 7.85 * scale, 5.67 * scale, 6.35 * scale);
    path.cubicTo(5.67 * scale, 6.35 * scale, 6.68 * scale, 6.04 * scale, 8.99 * scale, 7.44 * scale);
    path.cubicTo(9.87 * scale, 7.19 * scale, 10.94 * scale, 7.06 * scale, 12 * scale, 7.06 * scale);
    path.cubicTo(13.06 * scale, 7.06 * scale, 14.13 * scale, 7.19 * scale, 15.01 * scale, 7.44 * scale);
    path.cubicTo(17.32 * scale, 6.04 * scale, 18.33 * scale, 6.35 * scale, 18.33 * scale, 6.35 * scale);
    path.cubicTo(18.96 * scale, 7.85 * scale, 18.56 * scale, 8.96 * scale, 18.44 * scale, 9.25 * scale);
    path.cubicTo(19.22 * scale, 10.02 * scale, 19.66 * scale, 10.99 * scale, 19.66 * scale, 12.18 * scale);
    path.cubicTo(19.66 * scale, 16.73 * scale, 16.86 * scale, 17.67 * scale, 14.21 * scale, 17.96 * scale);
    path.cubicTo(14.62 * scale, 18.31 * scale, 15 * scale, 19 * scale, 15 * scale, 20.04 * scale);
    path.cubicTo(15 * scale, 21.51 * scale, 14.99 * scale, 22.7 * scale, 14.99 * scale, 23.18 * scale);
    path.cubicTo(14.99 * scale, 23.5 * scale, 15.19 * scale, 23.87 * scale, 15.81 * scale, 23.75 * scale);
    path.cubicTo(20.57 * scale, 22.31 * scale, 24 * scale, 17.83 * scale, 24 * scale, 12.5 * scale);
    path.cubicTo(24 * scale, 5.87 * scale, 18.63 * scale, 0.5 * scale, 12 * scale, 0.5 * scale);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GitHubLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// 外部链接图标
class _ExternalLinkIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String url;

  const _ExternalLinkIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.url,
  });

  @override
  State<_ExternalLinkIcon> createState() => _ExternalLinkIconState();
}

class _ExternalLinkIconState extends State<_ExternalLinkIcon> {
  bool _isHovering = false;
  bool _isPressed = false;

  Future<void> _launchUrl() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _launchUrl,
          onHover: (val) => setState(() => _isHovering = val),
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedScale(
            scale: _isPressed ? 0.92 : (_isHovering ? 1.1 : 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _isHovering 
                    ? widget.color.withOpacity(0.15) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.icon,
                color: widget.color.withOpacity(_isHovering ? 1.0 : 0.7),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDisabled;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  State<_NavIcon> createState() => _NavIconState();
}

class _NavIconState extends State<_NavIcon> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.isSelected
        ? theme.colorScheme.primary
        : (widget.isDisabled ? theme.disabledColor : theme.iconTheme.color?.withOpacity(0.7));

    // 计算背景色：选中状态优先，其次是 Hover 状态
    Color backgroundColor = Colors.transparent;
    if (widget.isSelected) {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.1);
    } else if (_isHovering && !widget.isDisabled) {
      backgroundColor = theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);
    }

    return Tooltip(
      message: widget.label,
      preferBelow: false,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        width: 48,
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isDisabled ? null : widget.onTap,
            onHover: (val) {
              if (!widget.isDisabled) {
                setState(() => _isHovering = val);
              }
            },
            onTapDown: (_) {
              if (!widget.isDisabled) {
                setState(() => _isPressed = true);
              }
            },
            onTapUp: (_) {
              if (!widget.isDisabled) {
                setState(() => _isPressed = false);
              }
            },
            onTapCancel: () {
              if (!widget.isDisabled) {
                setState(() => _isPressed = false);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: AnimatedScale(
              scale: _isPressed ? 0.92 : (_isHovering ? 1.1 : 1.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: widget.isSelected 
                    ? Border.all(color: theme.colorScheme.primary.withOpacity(0.5), width: 1) 
                    : null,
                ),
                child: Icon(
                  widget.icon,
                  color: color,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 账户头像按钮组件
class _AccountAvatarButton extends StatefulWidget {
  final WidgetRef ref;

  const _AccountAvatarButton({required this.ref});

  @override
  State<_AccountAvatarButton> createState() => _AccountAvatarButtonState();
}

class _AccountAvatarButtonState extends State<_AccountAvatarButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = widget.ref.watch(authNotifierProvider);
    final accounts = widget.ref.watch(accountManagerNotifierProvider).accounts;

    // 获取当前账户
    SavedAccount? currentAccount;
    if (authState.accountId != null) {
      try {
        currentAccount = accounts.firstWhere((a) => a.id == authState.accountId);
      } catch (_) {
        currentAccount = accounts.isNotEmpty ? accounts.first : null;
      }
    } else if (accounts.isNotEmpty) {
      currentAccount = accounts.first;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: 40,
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAccountMenu(context, currentAccount),
          onHover: (val) => setState(() => _isHovering = val),
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedScale(
            scale: _isPressed ? 0.92 : (_isHovering ? 1.1 : 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: currentAccount != null
                ? AccountAvatarSmall(
                    account: currentAccount,
                    size: 40,
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// 显示账户菜单
  Future<void> _showAccountMenu(BuildContext context, SavedAccount? currentAccount) async {
    final theme = Theme.of(context);
    final accounts = widget.ref.read(accountManagerNotifierProvider).accounts;
    final authState = widget.ref.read(authNotifierProvider);

    // 获取按钮的位置用于定位菜单
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // 使用 Rect 定义菜单弹出的锚点位置
    final menuAnchor = Rect.fromLTWH(
      68, // 侧边栏宽度(60) + 间距(8)
      offset.dy,
      1,
      button.size.height,
    );

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(menuAnchor, Offset.zero & screenSize),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        // 当前账号标题
        if (currentAccount != null)
          PopupMenuItem<String>(
            enabled: false,
            height: 40,
            child: Text(
              '${context.l10n.auth_currentAccount}: ${currentAccount.displayName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),

        // 分割线
        if (currentAccount != null && accounts.length > 1)
          const PopupMenuDivider(),

        // 账号列表
        ...accounts.map((account) => PopupMenuItem<String>(
              value: 'switch_${account.id}',
              child: Row(
                children: [
                  AccountAvatarSmall(account: account, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      account.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (account.id == authState.accountId)
                    Icon(
                      Icons.check,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                ],
              ),
            ),),

        const PopupMenuDivider(),

        // 添加账号
        PopupMenuItem<String>(
          value: 'add',
          child: Row(
            children: [
              Icon(
                Icons.add,
                color: theme.colorScheme.onSurface,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(context.l10n.auth_addAccount),
            ],
          ),
        ),

        // 退出登录
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(
                Icons.logout,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.auth_logout,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );

    if (value == null || !mounted) return;

    if (value == 'add') {
      if (mounted) {
        // ignore: use_build_context_synchronously
        _showAddAccountDialog(context);
      }
    } else if (value == 'logout') {
      widget.ref.read(authNotifierProvider.notifier).logout();
    } else if (value.startsWith('switch_')) {
      final accountId = value.substring(7);
      _switchAccount(accountId);
    }
  }

  /// 切换账号
  Future<void> _switchAccount(String accountId) async {
    final accounts = widget.ref.read(accountManagerNotifierProvider).accounts;
    final account = accounts.firstWhere((a) => a.id == accountId);

    // 获取 Token
    final token = await widget.ref
        .read(accountManagerNotifierProvider.notifier)
        .getAccountToken(account.id);

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.auth_tokenNotFound)),
        );
      }
      return;
    }

    // 执行登录
    await widget.ref.read(authNotifierProvider.notifier).loginWithToken(
          token,
          accountId: account.id,
          displayName: account.displayName,
        );

    // 更新最后使用时间
    widget.ref
        .read(accountManagerNotifierProvider.notifier)
        .updateLastUsed(account.id);
  }

  /// 显示添加账号对话框
  void _showAddAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Row(
                  children: [
                    const SizedBox(width: 16),
                    Text(
                      context.l10n.auth_addAccount,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                // Token 登录表单
                TokenLoginCard(
                  onLoginSuccess: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
