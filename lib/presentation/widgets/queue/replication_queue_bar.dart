import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../providers/replication_queue_provider.dart';

class ReplicationQueueBar extends ConsumerStatefulWidget {
  const ReplicationQueueBar({super.key});

  @override
  ConsumerState<ReplicationQueueBar> createState() => _ReplicationQueueBarState();
}

class _ReplicationQueueBarState extends ConsumerState<ReplicationQueueBar> {
  bool _isExpanded = false;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(replicationQueueNotifierProvider);
    final tasks = queueState.tasks;
    final isEmpty = queueState.isEmpty;

    // Use a bottom margin to avoid hugging the very edge, looks better floating
    const double bottomMargin = 16.0;
    const double horizontalMargin = 16.0;

    return AnimatedSlide(
      offset: isEmpty ? const Offset(0, 2) : Offset.zero,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          horizontalMargin,
          0,
          horizontalMargin,
          bottomMargin,
        ),
        child: Material(
          elevation: 8,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            height: _isExpanded ? 400 : 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header / Collapsed View
                SizedBox(
                  height: 72,
                  child: InkWell(
                    onTap: _toggleExpand,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Badge
                          _buildBadge(context, tasks.length),
                          const SizedBox(width: 12),
                          
                          // Thumbnails Preview (only in collapsed or expanded? 
                          // Prompt says: "Collapsed: Badge + Thumbnails + Expand Btn")
                          // In expanded, we show the full list. So maybe hide thumbnails in header when expanded?
                          // Or keep them? The prompt says "Expanded: Show full list". 
                          // Usually header stays or transforms. 
                          // Let's keep the header simple: 
                          // If expanded, maybe change the header to "Queue (N)" title?
                          // Let's stick to the prompt: "Collapsed: ... thumbnails ...". 
                          // I will fade out thumbnails when expanded to keep it clean.
                          Expanded(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isExpanded ? 0.0 : 1.0,
                              child: _isExpanded 
                                ? const SizedBox() 
                                : _buildThumbnailsPreview(tasks),
                            ),
                          ),
                          
                          // Controls
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isExpanded)
                                IconButton(
                                  icon: const Icon(Icons.delete_sweep_outlined),
                                  tooltip: '清空队列',
                                  onPressed: () {
                                    ref.read(replicationQueueNotifierProvider.notifier).clear();
                                    setState(() {
                                      _isExpanded = false;
                                    });
                                  },
                                ),
                              IconButton(
                                icon: Icon(_isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
                                onPressed: _toggleExpand,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Expanded List
                if (_isExpanded)
                  Expanded(
                    child: _buildReorderableList(tasks),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, int count) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildThumbnailsPreview(List<ReplicationTask> tasks) {
    // Show max 5 thumbnails
    final previewTasks = tasks.take(5).toList();
    
    return SizedBox(
      height: 40,
      child: Stack(
        children: List.generate(previewTasks.length, (index) {
          final task = previewTasks[index];
          // Overlap effect
          return Positioned(
            left: index * 24.0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  width: 2,
                ),
                image: task.thumbnailUrl != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(task.thumbnailUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: task.thumbnailUrl == null
                  ? Icon(Icons.image, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant)
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildReorderableList(List<ReplicationTask> tasks) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: tasks.length,
      onReorder: (oldIndex, newIndex) {
        ref.read(replicationQueueNotifierProvider.notifier).reorder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildListItem(context, task, index);
      },
    );
  }

  Widget _buildListItem(BuildContext context, ReplicationTask task, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: colorScheme.onErrorContainer),
      ),
      onDismissed: (_) {
        ref.read(replicationQueueNotifierProvider.notifier).remove(task.id);
      },
      child: ListTile(
        key: ValueKey(task.id),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: colorScheme.surfaceContainerHighest,
            image: task.thumbnailUrl != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(task.thumbnailUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: task.thumbnailUrl == null
              ? Icon(Icons.image, color: colorScheme.onSurfaceVariant)
              : null,
        ),
        title: Text(
          task.prompt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, height: 1.2),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                ref.read(replicationQueueNotifierProvider.notifier).remove(task.id);
              },
            ),
            Icon(Icons.drag_handle, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
