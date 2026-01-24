import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_warmup_service.dart';
import '../../../core/utils/localization_extension.dart';
import '../../providers/warmup_provider.dart';

/// 启动画面
/// 显示应用品牌和预加载进度
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Logo 呼吸动画
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _breathController,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(
        parent: _breathController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warmupState = ref.watch(warmupNotifierProvider);
    final progress = warmupState.progress;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final backgroundColor = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 背景装饰
          _buildBackground(primaryColor, backgroundColor),

          // 主内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // Logo 动画
                _buildLogo(primaryColor),

                const SizedBox(height: 24),

                // 应用名称
                _buildTitle(theme, primaryColor),

                const Spacer(flex: 2),

                // 进度区域
                _buildProgressSection(theme, primaryColor, progress),

                // 跳过预热按钮 (仅调试模式)
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  _buildSkipButton(theme, primaryColor),
                ],

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(Color primaryColor, Color backgroundColor) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.5,
              colors: [
                primaryColor.withOpacity(_glowAnimation.value * 0.15),
                backgroundColor,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo(Color primaryColor) {
    return AnimatedBuilder(
      animation: _breathAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _breathAnimation.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor,
                  primaryColor.withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(_glowAnimation.value * 0.5),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 56,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle(ThemeData theme, Color primaryColor) {
    final lighterColor = Color.lerp(primaryColor, Colors.white, 0.4)!;
    
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              primaryColor,
              lighterColor,
            ],
          ).createShader(bounds),
          child: const Text(
            'NAI Launcher',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'NovelAI Image Generation',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  /// 翻译任务 key 为本地化文本
  String _translateTaskKey(BuildContext context, String taskKey) {
    final l10n = context.l10n;
    switch (taskKey) {
      case 'warmup_preparing':
        return l10n.warmup_preparing;
      case 'warmup_complete':
        return l10n.warmup_complete;
      case 'warmup_loadingTranslation':
        return l10n.warmup_loadingTranslation;
      case 'warmup_initTagSystem':
        return l10n.warmup_initTagSystem;
      case 'warmup_loadingPromptConfig':
        return l10n.warmup_loadingPromptConfig;
      default:
        return taskKey;
    }
  }

  Widget _buildProgressSection(ThemeData theme, Color primaryColor, WarmupProgress progress) {
    final translatedTask = _translateTaskKey(context, progress.currentTask);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          // 进度条
          _buildProgressBar(theme, primaryColor, progress.progress),

          const SizedBox(height: 16),

          // 状态文字
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              translatedTask,
              key: ValueKey(progress.currentTask),
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme, Color primaryColor, double value) {
    final lighterColor = Color.lerp(primaryColor, Colors.white, 0.4)!;

    return Container(
      height: 4,
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: theme.colorScheme.onSurface.withOpacity(0.1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 进度填充
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * value,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      lighterColor,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSkipButton(ThemeData theme, Color primaryColor) {
    return TextButton(
      onPressed: () {
        ref.read(warmupNotifierProvider.notifier).skip();
      },
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface.withOpacity(0.6),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(context.l10n.warmup_skip),
    );
  }
}
