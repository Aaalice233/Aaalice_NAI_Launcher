import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/background_task_provider.dart';

/// 画师标签同步进度卡片（右下角显示）
/// 
/// 特点：
/// - 固定在右下角
/// - 显示页数和数量（不是百分比）
/// - 独立的进度显示，不与其他任务混合
class ArtistTagProgressCard extends ConsumerWidget {
  const ArtistTagProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backgroundTaskNotifierProvider);
    
    // 查找画师标签任务
    final artistTask = state.tasks.firstWhere(
      (t) => t.id == 'artist_tags_fetch' && !t.isDone,
      orElse: () => state.tasks.firstWhere(
        (t) => t.id == 'artist_tags_isolate_fetch' && !t.isDone,
        orElse: () => const BackgroundTask(
          id: '',
          name: '',
          displayName: '',
        ),
      ),
    );

    // 没有正在运行的画师标签任务，不显示
    if (artistTask.id.isEmpty || artistTask.isDone) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 16,
      bottom: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Icon(
                    Icons.palette,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '同步画师标签',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // 关闭按钮（点击取消任务）
                  GestureDetector(
                    onTap: () {
                      // TODO: 取消任务
                    },
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 进度指示器（不确定进度，使用循环动画）
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 详细信息（页数/数量，不显示总数）
                  Expanded(
                    child: Text(
                      artistTask.message ?? '准备中...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 全局右下角逐层容器
/// 
/// 用法：将需要显示在右下角的组件放入 Stack 中
class BottomRightOverlay extends StatelessWidget {
  final List<Widget> children;
  
  const BottomRightOverlay({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ...children,
        const ArtistTagProgressCard(),
      ],
    );
  }
}
