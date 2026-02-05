
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
                _buildProgressSection(theme, primaryColor, progress, warmupState.subTaskMessage),

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
      case 'warmup_networkCheck':
        return l10n.warmup_networkCheck;
      case 'warmup_loadingTranslation':
        return l10n.warmup_loadingTranslation;
      case 'warmup_initTagSystem':
        return l10n.warmup_initTagSystem;
      case 'warmup_loadingPromptConfig':
        return l10n.warmup_loadingPromptConfig;
      case 'warmup_danbooruAuth':
        return l10n.warmup_danbooruAuth;
      case 'warmup_imageEditor':
        return l10n.warmup_imageEditor;
      case 'warmup_database':
        return l10n.warmup_database;
      case 'warmup_network':
        return l10n.warmup_network;
      case 'warmup_fonts':
        return l10n.warmup_fonts;
      case 'warmup_imageCache':
        return l10n.warmup_imageCache;
      case 'warmup_statistics':
        return l10n.warmup_statistics;
      case 'warmup_subscription':
        return l10n.warmup_subscription;
      case 'warmup_dataSourceCache':
        return l10n.warmup_dataSourceCache;
      case 'warmup_galleryFileCount':
        return l10n.warmup_galleryFileCount;
      case 'warmup_cooccurrenceData':
        return l10n.warmup_cooccurrenceData;
      case 'warmup_cooccurrenceInit':
        return l10n.warmup_cooccurrenceInit;
      case 'warmup_translationInit':
        return l10n.warmup_translationInit;
      case 'warmup_danbooruTagsInit':
        return l10n.warmup_danbooruTagsInit;
      case 'warmup_group_dataSourceInitialization':
        return l10n.warmup_group_dataSourceInitialization;
      case 'warmup_group_dataSourceInitialization_complete':
        return l10n.warmup_group_dataSourceInitialization_complete;
      case 'warmup_group_basicUI':
        return l10n.warmup_group_basicUI;
      case 'warmup_group_basicUI_complete':
        return l10n.warmup_group_basicUI_complete;
      case 'warmup_group_dataServices':
        return l10n.warmup_group_dataServices;
      case 'warmup_group_dataServices_complete':
        return l10n.warmup_group_dataServices_complete;
      case 'warmup_group_networkServices':
        return l10n.warmup_group_networkServices;
      case 'warmup_group_networkServices_complete':
        return l10n.warmup_group_networkServices_complete;
      case 'warmup_group_cacheServices':
        return l10n.warmup_group_cacheServices;
      case 'warmup_group_cacheServices_complete':
        return l10n.warmup_group_cacheServices_complete;
      default:
        return taskKey;
    }
  }

  Widget _buildProgressSection(
    ThemeData theme,
    Color primaryColor,
    WarmupProgress progress,
    String? subTaskMessage,
  ) {
    final translatedTask = _translateTaskKey(context, progress.currentTask);
    final percentage = (progress.progress * 100).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          // 进度条 + 百分比
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child:
                      _buildProgressBar(theme, primaryColor, progress.progress),
                ),
              ),
              const SizedBox(width: 12),
              // 百分比文字（使用等宽数字特性）
              SizedBox(
                width: 42,
                child: Text(
                  '$percentage%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 当前任务（带加载指示器）
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Row(
              key: ValueKey(progress.currentTask),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!progress.isComplete) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  translatedTask,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          // 子任务进度（如"下载中... 50%"）
          if (subTaskMessage != null && !progress.isComplete) ...[
            const SizedBox(height: 8),
            Text(
              subTaskMessage,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme, Color primaryColor, double value) {
    final lighterColor = Color.lerp(primaryColor, Colors.white, 0.4)!;

    return Container(
      height: 4,
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
}
