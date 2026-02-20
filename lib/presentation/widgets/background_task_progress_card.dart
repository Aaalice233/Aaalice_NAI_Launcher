import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/background_task_provider.dart';

/// 共现数据导入进度卡片（右下角显示）
///
/// 特点：
/// - 固定在右下角
/// - 显示导入进度和消息
/// - 支持确定进度（百分比）和不确定进度（循环动画）
/// - 完成后继续显示3秒，让用户看到结果
class CooccurrenceImportProgressCard extends ConsumerStatefulWidget {
  const CooccurrenceImportProgressCard({super.key});

  @override
  ConsumerState<CooccurrenceImportProgressCard> createState() =>
      _CooccurrenceImportProgressCardState();
}

class _CooccurrenceImportProgressCardState
    extends ConsumerState<CooccurrenceImportProgressCard> {
  BackgroundTask? _lastTask;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backgroundTaskNotifierProvider);

    // 查找共现数据导入任务
    final task = state.tasks.firstWhere(
      (t) => t.id == 'cooccurrence_import',
      orElse: () => const BackgroundTask(
        id: '',
        name: '',
        displayName: '',
      ),
    );

    // 如果没有任务，不显示
    if (task.id.isEmpty) {
      return const SizedBox.shrink();
    }

    // 如果任务正在运行，更新最后显示的任务并取消隐藏定时器
    if (!task.isDone) {
      _lastTask = task;
      _hideTimer?.cancel();
    }

    // 如果任务完成，启动隐藏定时器
    if (task.isDone && _hideTimer == null) {
      _lastTask = task;
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _lastTask = null;
          });
        }
      });
    }

    // 获取要显示的任务
    final displayTask = !task.isDone ? task : _lastTask;

    // 没有要显示的任务
    if (displayTask == null) {
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
          width: 320,
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
                    Icons.sync_alt,
                    size: 18,
                    color: displayTask.isDone
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '导入共现数据',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (displayTask.isDone) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // 进度条（如果有确定进度）
              if (displayTask.progress > 0 && displayTask.progress < 1.0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: displayTask.progress,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 进度指示器
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: displayTask.isDone
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.green,
                          )
                        : displayTask.progress == 0
                            ? CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : CircularProgressIndicator(
                                strokeWidth: 2,
                                value: displayTask.progress,
                                valueColor: AlwaysStoppedAnimation(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                  ),
                  const SizedBox(width: 12),
                  // 详细信息
                  Expanded(
                    child: Text(
                      displayTask.message ?? '准备中...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: displayTask.isDone
                                ? Colors.green
                                : Theme.of(context).colorScheme.onSurfaceVariant,
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
        const CooccurrenceImportProgressCard(),
      ],
    );
  }
}
