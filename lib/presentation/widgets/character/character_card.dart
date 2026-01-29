import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../themes/theme_extension.dart';
import '../common/themed_switch.dart';
import 'add_to_library_dialog.dart';

/// 角色卡片组件（竖直ID身份卡样式）
///
/// 设计特点：
/// - 竖直比例 0.72:1（类似真实ID卡）
/// - 顶部性别色条带
/// - 居中头像区域
/// - 金属质感分隔线
/// - 底部状态徽章行
/// - 背景纹理效果
class CharacterCard extends ConsumerStatefulWidget {
  final CharacterPrompt character;
  final bool globalAiChoice;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onEnabledChanged;
  final VoidCallback? onDelete;

  const CharacterCard({
    super.key,
    required this.character,
    this.globalAiChoice = false,
    this.onTap,
    this.onEnabledChanged,
    this.onDelete,
  });

  @override
  ConsumerState<CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends ConsumerState<CharacterCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _glossController;
  late Animation<double> _glossAnimation;

  @override
  void initState() {
    super.initState();
    _glossController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _glossAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _glossController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glossController.dispose();
    super.dispose();
  }

  void _onHoverEnter(PointerEvent event) {
    if (!widget.character.enabled) return;
    setState(() => _isHovered = true);
    _glossController.forward(from: 0.0);
  }

  void _onHoverExit(PointerEvent event) {
    setState(() => _isHovered = false);
  }

  /// 获取性别对应的颜色
  Color _getGenderColor() {
    switch (widget.character.gender) {
      case CharacterGender.female:
        return const Color(0xFFEC4899); // pink-500
      case CharacterGender.male:
        return const Color(0xFF3B82F6); // blue-500
      case CharacterGender.other:
        return const Color(0xFF8B5CF6); // violet-500
    }
  }

  /// 获取性别图标
  IconData _getGenderIcon() {
    switch (widget.character.gender) {
      case CharacterGender.female:
        return Icons.female;
      case CharacterGender.male:
        return Icons.male;
      case CharacterGender.other:
        return Icons.transgender;
    }
  }

  /// 获取位置显示文本
  String _getPositionText() {
    if (widget.globalAiChoice) return 'AI';
    if (widget.character.positionMode == CharacterPositionMode.aiChoice) {
      return 'AI';
    }
    if (widget.character.customPosition != null) {
      return widget.character.customPosition!.toNaiString();
    }
    return '--';
  }

  /// 获取主题适配的效果强度
  _EffectIntensity _getEffectIntensity(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();

    if (extension?.enableNeonGlow == true) {
      return const _EffectIntensity(edgeGlow: 1.3, gloss: 1.0);
    } else if (extension?.isLightTheme == true) {
      return const _EffectIntensity(edgeGlow: 0.6, gloss: 1.0);
    } else {
      return const _EffectIntensity(edgeGlow: 1.0, gloss: 0.8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final genderColor = _getGenderColor();
    final intensity = _getEffectIntensity(context);
    final isEnabled = widget.character.enabled;
    final isLight = theme.extension<AppThemeExtension>()?.isLightTheme ?? false;

    // 检查是否已收藏到词库
    final libraryEntries = ref.watch(tagLibraryPageNotifierProvider).entries;
    final isFavorited = libraryEntries.any(
      (e) =>
          e.content == widget.character.prompt &&
          widget.character.prompt.isNotEmpty,
    );

    return MouseRegion(
      onEnter: _onHoverEnter,
      onExit: _onHoverExit,
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: isEnabled ? widget.onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isEnabled ? 1.0 : 0.6,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translate(0.0, _isHovered && isEnabled ? -4.0 : 0.0),
            transformAlignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isHovered
                      ? genderColor.withOpacity(0.6)
                      : colorScheme.outlineVariant.withOpacity(0.4),
                  width: _isHovered ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? genderColor.withOpacity(0.2)
                        : Colors.black.withOpacity(0.1),
                    blurRadius: _isHovered ? 16 : 8,
                    offset: Offset(0, _isHovered ? 8 : 4),
                    spreadRadius: _isHovered ? 1 : 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // 背景纹理
                    Positioned.fill(
                      child: _CardBackground(
                        isLight: isLight,
                        genderColor: genderColor,
                      ),
                    ),

                    // 主内容
                    Column(
                      children: [
                        // 顶部性别色条带
                        _TopStripe(genderColor: genderColor),

                        // 头像区域
                        Expanded(
                          flex: 3,
                          child: _AvatarSection(
                            character: widget.character,
                            genderColor: genderColor,
                            genderIcon: _getGenderIcon(),
                          ),
                        ),

                        // 金属分隔线
                        _MetallicDivider(genderColor: genderColor),

                        // 信息区域
                        Expanded(
                          flex: 6,
                          child: _InfoSection(
                            character: widget.character,
                            isEnabled: isEnabled,
                            genderColor: genderColor,
                            genderIcon: _getGenderIcon(),
                          ),
                        ),

                        // 底部状态栏
                        _StatusBar(
                          genderIcon: _getGenderIcon(),
                          genderColor: genderColor,
                          positionText: _getPositionText(),
                          isEnabled: isEnabled,
                          onEnabledChanged: widget.onEnabledChanged,
                        ),

                        // 底部装饰条
                        _BottomStripe(genderColor: genderColor),
                      ],
                    ),

                    // 边缘高光效果
                    if (_isHovered && isEnabled)
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return _EdgeHighlight(
                              glowColor: genderColor,
                              intensity: value * intensity.edgeGlow,
                            );
                          },
                        ),
                      ),

                    // 光泽扫过效果
                    if (_isHovered && isEnabled)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _glossAnimation,
                            builder: (context, child) {
                              return _GlossOverlay(
                                progress: _glossAnimation.value,
                                intensity: intensity.gloss,
                              );
                            },
                          ),
                        ),
                      ),

                    // 悬浮时显示收藏按钮（左上角）
                    if (_isHovered && isEnabled)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: _FavoriteButton(
                          isFavorited: isFavorited,
                          onTap: () async {
                            final result = await AddToLibraryDialog.show(
                              context,
                              name:
                                  '${widget.character.name} - ${AppLocalizations.of(context)!.prompt_positivePrompt}',
                              content: widget.character.prompt,
                            );
                            if (result == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(context)!
                                        .tagLibrary_addedToFixed,
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          genderColor: genderColor,
                        ),
                      ),

                    // 悬浮时显示删除按钮（右上角）
                    if (_isHovered && widget.onDelete != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _DeleteButton(
                          onTap: widget.onDelete!,
                          genderColor: genderColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 卡片背景纹理（仿真ID卡材质）
class _CardBackground extends StatelessWidget {
  final bool isLight;
  final Color genderColor;

  const _CardBackground({
    required this.isLight,
    required this.genderColor,
  });

  // ID卡专用配色
  static const _lightCardBase = Color(0xFFFAF8F5); // 米白色卡片
  static const _lightCardAccent = Color(0xFFF0EDE8); // 浅米色
  static const _darkCardBase = Color(0xFF2A3441); // 深蓝灰塑料卡
  static const _darkCardAccent = Color(0xFF1F2937); // 更深的蓝灰

  @override
  Widget build(BuildContext context) {
    final baseColor = isLight ? _lightCardBase : _darkCardBase;
    final accentColor = isLight ? _lightCardAccent : _darkCardAccent;

    return Container(
      decoration: BoxDecoration(
        // 实心不透明背景
        color: baseColor,
        // 微妙渐变增加层次
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            baseColor,
            accentColor,
            baseColor.withOpacity(0.95),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // 纹理层
          Positioned.fill(
            child: CustomPaint(
              painter: _CardTexturePainter(
                isLight: isLight,
                genderColor: genderColor,
              ),
            ),
          ),
          // 微光层（模拟塑料光泽）
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-1, -1),
                  end: const Alignment(1, 1),
                  colors: [
                    Colors.white.withOpacity(isLight ? 0.15 : 0.05),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.white.withOpacity(isLight ? 0.08 : 0.03),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ID卡纹理绘制器（模拟塑料卡片质感）
class _CardTexturePainter extends CustomPainter {
  final bool isLight;
  final Color genderColor;

  _CardTexturePainter({
    required this.isLight,
    required this.genderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制细微点阵纹理（模拟塑料磨砂质感）
    final dotPaint = Paint()
      ..color = (isLight ? Colors.black : Colors.white)
          .withOpacity(isLight ? 0.015 : 0.02);

    const dotSpacing = 4.0;
    for (double x = 0; x < size.width; x += dotSpacing) {
      for (double y = 0; y < size.height; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), 0.3, dotPaint);
      }
    }

    // 绘制水印图案（安全线效果）
    final watermarkPaint = Paint()
      ..color = genderColor.withOpacity(isLight ? 0.03 : 0.05)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // 斜线水印
    const watermarkSpacing = 20.0;
    for (double i = -size.height;
        i < size.width + size.height;
        i += watermarkSpacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height * 0.5, size.height),
        watermarkPaint,
      );
    }

    // 边缘装饰线
    final borderPaint = Paint()
      ..color = genderColor.withOpacity(isLight ? 0.08 : 0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final borderRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(6),
    );
    canvas.drawRRect(borderRect, borderPaint);
  }

  @override
  bool shouldRepaint(_CardTexturePainter oldDelegate) {
    return oldDelegate.isLight != isLight ||
        oldDelegate.genderColor != genderColor;
  }
}

/// 顶部性别色条带
class _TopStripe extends StatelessWidget {
  final Color genderColor;

  const _TopStripe({required this.genderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            genderColor.withOpacity(0.8),
            genderColor,
            genderColor.withOpacity(0.8),
          ],
        ),
      ),
      // 顶部装饰图案
      child: CustomPaint(
        painter: _StripPatternPainter(color: Colors.white.withOpacity(0.15)),
      ),
    );
  }
}

/// 条带装饰图案绘制器
class _StripPatternPainter extends CustomPainter {
  final Color color;

  _StripPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    // 绘制斜线装饰
    const spacing = 8.0;
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPatternPainter oldDelegate) => false;
}

/// 头像区域组件
class _AvatarSection extends StatelessWidget {
  final CharacterPrompt character;
  final Color genderColor;
  final IconData genderIcon;

  const _AvatarSection({
    required this.character,
    required this.genderColor,
    required this.genderIcon,
  });

  @override
  Widget build(BuildContext context) {
    final hasThumbnail =
        character.thumbnailPath != null && character.thumbnailPath!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: genderColor.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: genderColor.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: hasThumbnail
                  ? Image.file(
                      File(character.thumbnailPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            genderColor.withOpacity(0.3),
            genderColor.withOpacity(0.15),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          genderIcon,
          size: 40,
          color: genderColor.withOpacity(0.8),
        ),
      ),
    );
  }
}

/// 装饰分隔线（单条亮色渐变线）
class _MetallicDivider extends StatelessWidget {
  final Color genderColor;

  const _MetallicDivider({required this.genderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            genderColor.withOpacity(0.4),
            genderColor.withOpacity(0.8),
            Colors.white.withOpacity(0.9),
            genderColor.withOpacity(0.8),
            genderColor.withOpacity(0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.15, 0.35, 0.5, 0.65, 0.85, 1.0],
        ),
      ),
    );
  }
}

/// 信息区域组件
class _InfoSection extends StatelessWidget {
  final CharacterPrompt character;
  final bool isEnabled;
  final Color genderColor;
  final IconData genderIcon;

  const _InfoSection({
    required this.character,
    required this.isEnabled,
    required this.genderColor,
    required this.genderIcon,
  });

  // ID卡专用文字颜色
  static const _lightTextPrimary = Color(0xFF1A1A1A); // 深色文字
  static const _lightTextSecondary = Color(0xFF4A4A4A); // 次要文字
  static const _darkTextPrimary = Color(0xFFF5F5F5); // 浅色文字
  static const _darkTextSecondary = Color(0xFFB0B0B0); // 次要文字

  /// 根据角色ID生成固定的工号
  String _generateEmployeeId() {
    // 使用角色ID的hashCode生成固定的6位数字
    final hash = character.id.hashCode.abs();
    return (hash % 900000 + 100000).toString();
  }

  /// 获取性别文字
  String _getGenderText() {
    switch (character.gender) {
      case CharacterGender.female:
        return 'F';
      case CharacterGender.male:
        return 'M';
      case CharacterGender.other:
        return 'O';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.extension<AppThemeExtension>()?.isLightTheme ?? false;
    final textPrimary = isLight ? _lightTextPrimary : _darkTextPrimary;
    final textSecondary = isLight ? _lightTextSecondary : _darkTextSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 角色名称（加大）
          Text(
            character.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              decoration: isEnabled ? null : TextDecoration.lineThrough,
              color: isEnabled ? textPrimary : textPrimary.withOpacity(0.5),
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          // 性别 + 工号
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                genderIcon,
                size: 12,
                color: genderColor.withOpacity(0.8),
              ),
              const SizedBox(width: 2),
              Text(
                _getGenderText(),
                style: TextStyle(
                  fontSize: 10,
                  color: genderColor.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'NO.${_generateEmployeeId()}',
                style: TextStyle(
                  fontSize: 9,
                  color: textSecondary.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 提示词预览
          Expanded(
            child: Text(
              character.prompt.isNotEmpty
                  ? character.prompt
                  : AppLocalizations.of(context)!.characterEditor_promptHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: character.prompt.isNotEmpty
                    ? textSecondary
                    : textSecondary.withOpacity(0.5),
                height: 1.2,
                fontSize: 10,
              ),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// 状态栏组件
class _StatusBar extends StatelessWidget {
  final IconData genderIcon;
  final Color genderColor;
  final String positionText;
  final bool isEnabled;
  final ValueChanged<bool>? onEnabledChanged;

  const _StatusBar({
    required this.genderIcon,
    required this.genderColor,
    required this.positionText,
    required this.isEnabled,
    this.onEnabledChanged,
  });

  // ID卡状态栏配色
  static const _lightStatusBg = Color(0xFFE8E4DF); // 浅灰棕
  static const _darkStatusBg = Color(0xFF1F2937); // 深蓝灰

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.extension<AppThemeExtension>()?.isLightTheme ?? false;
    final statusBg = isLight ? _lightStatusBg : _darkStatusBg;
    final textColor =
        isLight ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: statusBg,
        border: Border(
          top: BorderSide(
            color: genderColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 性别徽章
          _StatusBadge(
            icon: genderIcon,
            color: genderColor,
            size: 18,
          ),
          // 位置徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: genderColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              positionText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
          // 启用开关
          GestureDetector(
            onTap: () => onEnabledChanged?.call(!isEnabled),
            behavior: HitTestBehavior.opaque,
            child: ThemedSwitch(
              value: isEnabled,
              onChanged: onEnabledChanged,
              scale: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

/// 状态徽章组件
class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _StatusBadge({
    required this.icon,
    required this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        size: size * 0.7,
        color: color,
      ),
    );
  }
}

/// 底部装饰条
class _BottomStripe extends StatelessWidget {
  final Color genderColor;

  const _BottomStripe({required this.genderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            genderColor.withOpacity(0.6),
            genderColor.withOpacity(0.9),
            genderColor,
            genderColor.withOpacity(0.9),
            genderColor.withOpacity(0.6),
          ],
        ),
      ),
    );
  }
}

/// 删除按钮组件（位于顶部条带右上角）
class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color genderColor;

  const _DeleteButton({
    required this.onTap,
    required this.genderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(8),
        ),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(8),
            ),
            border: Border(
              left: BorderSide(
                color: genderColor.withOpacity(0.5),
                width: 1,
              ),
              bottom: BorderSide(
                color: genderColor.withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
          child: const Icon(
            Icons.close,
            size: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 收藏按钮组件（位于左上角）
class _FavoriteButton extends StatefulWidget {
  final bool isFavorited;
  final VoidCallback onTap;
  final Color genderColor;

  const _FavoriteButton({
    required this.isFavorited,
    required this.onTap,
    required this.genderColor,
  });

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isFavorited = widget.isFavorited;
    final l10n = AppLocalizations.of(context)!;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomRight: Radius.circular(8),
          ),
          child: Tooltip(
            message: isFavorited
                ? l10n.tagLibrary_pinned
                : l10n.tagLibrary_addToLibrary,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isFavorited
                    ? Colors.red.shade400.withOpacity(0.9)
                    : (_isHovered
                        ? Colors.black.withOpacity(0.7)
                        : Colors.black.withOpacity(0.5)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomRight: Radius.circular(8),
                ),
                border: Border(
                  right: BorderSide(
                    color: isFavorited
                        ? Colors.red.shade400.withOpacity(0.5)
                        : widget.genderColor.withOpacity(0.5),
                    width: 1,
                  ),
                  bottom: BorderSide(
                    color: isFavorited
                        ? Colors.red.shade400.withOpacity(0.5)
                        : widget.genderColor.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                boxShadow: isFavorited || _isHovered
                    ? [
                        BoxShadow(
                          color: Colors.red.shade400.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: isFavorited ? 1 : 0,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isFavorited || _isHovered
                    ? Icons.favorite
                    : Icons.favorite_border,
                size: 14,
                color: isFavorited || _isHovered
                    ? Colors.white
                    : Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 效果强度配置
class _EffectIntensity {
  final double edgeGlow;
  final double gloss;

  const _EffectIntensity({
    required this.edgeGlow,
    required this.gloss,
  });
}

/// 边缘高光效果覆盖层
class _EdgeHighlight extends StatelessWidget {
  final Color glowColor;
  final double intensity;

  const _EdgeHighlight({
    required this.glowColor,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _EdgeHighlightPainter(
          glowColor: glowColor,
          intensity: intensity,
        ),
      ),
    );
  }
}

/// 边缘高光绘制器
class _EdgeHighlightPainter extends CustomPainter {
  final Color glowColor;
  final double intensity;

  _EdgeHighlightPainter({
    required this.glowColor,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    for (int i = 0; i < 2; i++) {
      final inset = (i + 1) * 1.5;
      final innerRect = rect.deflate(inset);
      final innerRRect = RRect.fromRectAndRadius(
        innerRect,
        Radius.circular(math.max(0, 12 - inset)),
      );

      final opacity = 0.15 * intensity * (2 - i) / 2;
      final blurAmount = (2 - i) * 2.0;

      final paint = Paint()
        ..color = glowColor.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurAmount);

      canvas.drawRRect(innerRRect, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgeHighlightPainter oldDelegate) {
    return oldDelegate.glowColor != glowColor ||
        oldDelegate.intensity != intensity;
  }
}

/// 光泽扫过效果覆盖层
class _GlossOverlay extends StatelessWidget {
  final double progress;
  final double intensity;

  const _GlossOverlay({
    required this.progress,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GlossPainter(
          progress: progress,
          intensity: intensity,
        ),
      ),
    );
  }
}

/// 光泽效果绘制器
class _GlossPainter extends CustomPainter {
  final double progress;
  final double intensity;

  _GlossPainter({
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final mainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.08 * intensity),
          Colors.white.withOpacity(0.2 * intensity),
          Colors.white.withOpacity(0.08 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(
        Rect.fromLTWH(
          size.width * progress - size.width * 0.5,
          size.height * progress - size.height * 0.5,
          size.width,
          size.height,
        ),
      );

    canvas.drawRect(Offset.zero & size, mainPaint);
  }

  @override
  bool shouldRepaint(_GlossPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}
