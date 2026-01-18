import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/permission_utils.dart';
import '../../providers/local_gallery_provider.dart';
import '../../widgets/common/pagination_bar.dart';
import '../../widgets/local_image_card.dart';

/// 本地画廊屏幕
class LocalGalleryScreen extends ConsumerStatefulWidget {
  const LocalGalleryScreen({super.key});

  @override
  ConsumerState<LocalGalleryScreen> createState() => _LocalGalleryScreenState();
}

class _LocalGalleryScreenState extends ConsumerState<LocalGalleryScreen> {
  @override
  void initState() {
    super.initState();
    // 首次加载时检查权限并扫描图片
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissionsAndScan();
      await _showFirstTimeTip();
    });
  }

  /// 检查权限并扫描图片
  Future<void> _checkPermissionsAndScan() async {
    // 检查权限状态
    final hasPermission = await PermissionUtils.checkGalleryPermission();

    if (!hasPermission) {
      // 请求权限
      final granted = await PermissionUtils.requestGalleryPermission();

      if (!granted && mounted) {
        // 权限被拒绝，显示引导对话框
        _showPermissionDeniedDialog();
        return;
      }
    }

    // 有权限，开始扫描
    if (mounted) {
      ref.read(localGalleryNotifierProvider.notifier).initialize();
    }
  }

  /// 显示权限被拒绝对话框
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('需要存储权限'),
        content: const Text(
          '本地画廊需要访问存储权限才能扫描您生成的图片。\n\n'
          '请在设置中授予权限后重试。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              PermissionUtils.openAppSettings();
            },
            child: const Text('打开设置'),
          ),
        ],
      ),
    );
  }

  /// 显示首次使用提示
  Future<void> _showFirstTimeTip() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTip =
        prefs.getBool(StorageKeys.hasSeenLocalGalleryTip) ?? false;

    if (hasSeenTip || !mounted) return;

    // 标记已显示
    await prefs.setBool(StorageKeys.hasSeenLocalGalleryTip, true);

    // 延迟显示，避免与权限对话框冲突
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💡 使用提示'),
        content: const Text(
          '右键点击（桌面端）或长按（移动端）图片可以：\n\n'
          '• 复制 Prompt\n'
          '• 复制 Seed\n'
          '• 查看完整元数据',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localGalleryNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    // 计算列数（200px/列，最少2列，最多8列）
    final columns = (screenWidth / 200).floor().clamp(2, 8);
    final itemWidth = screenWidth / columns;

    return Scaffold(
      appBar: AppBar(
        title: const Text('本地画廊'),
        actions: [
          if (state.isIndexing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(localGalleryNotifierProvider.notifier).refresh();
              },
              tooltip: '刷新',
            ),
        ],
      ),
      body: state.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('加载失败: ${state.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.read(localGalleryNotifierProvider.notifier).refresh(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : state.isIndexing // Initial Indexing State
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('索引本地图片中...'), // Updated text
                    ],
                  ),
                )
              : state.allFiles.isEmpty // Empty State
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('暂无本地图片'),
                          SizedBox(height: 8),
                          Text('生成的图片将保存在此处', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : Column( // Content State with Pagination
                      children: [
                        Expanded(
                          child: state.isPageLoading
                            ? MasonryGridView.count(
                                crossAxisCount: columns,
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4,
                                // 骨架屏数量与实际图片一致，如果为空则默认 20 个
                                itemCount: state.currentImages.isNotEmpty 
                                    ? state.currentImages.length 
                                    : 20,
                                itemBuilder: (c, i) {
                                  // 使用索引作为随机种子，保证高度在重绘时保持一致
                                  final random = Random(i);
                                  final height = 150.0 + random.nextInt(151); // 150-300px
                                  
                                  return Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: _ShimmerSkeleton(height: height),
                                  );
                                },
                              )
                            : MasonryGridView.count(
                                crossAxisCount: columns,
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4,
                                itemCount: state.currentImages.length,
                                itemBuilder: (c, i) => LocalImageCard(record: state.currentImages[i], itemWidth: itemWidth),
                              ),
                        ),
                        if (state.totalPages > 1)
                          PaginationBar(
                            currentPage: state.currentPage,
                            totalPages: state.totalPages,
                            onPageChanged: (p) => ref.read(localGalleryNotifierProvider.notifier).loadPage(p),
                          ),
                      ],
                    ),
    );
  }
}

/// 简单的 Shimmer 骨架屏组件
class _ShimmerSkeleton extends StatefulWidget {
  final double height;

  const _ShimmerSkeleton({required this.height});

  @override
  State<_ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<_ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceContainerHighest.withOpacity(0.3);
    final highlightColor = colorScheme.surfaceContainerHighest.withOpacity(0.6);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                -1.0 + (_controller.value * 2),
                -0.3,
              ), // 稍微倾斜
              end: Alignment(
                1.0 + (_controller.value * 2),
                0.3,
              ),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}
