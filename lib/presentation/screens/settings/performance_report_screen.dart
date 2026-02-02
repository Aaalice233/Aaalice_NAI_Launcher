import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../core/services/warmup_metrics_service.dart';
import '../../../data/models/warmup/warmup_metrics.dart';
import '../../widgets/common/app_toast.dart';

/// 启动性能报告页面
class PerformanceReportScreen extends ConsumerStatefulWidget {
  const PerformanceReportScreen({super.key});

  @override
  ConsumerState<PerformanceReportScreen> createState() =>
      _PerformanceReportScreenState();
}

class _PerformanceReportScreenState
    extends ConsumerState<PerformanceReportScreen> {
  List<List<WarmupTaskMetrics>> _sessions = [];
  Map<String, Map<String, int>?> _taskStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final metricsService = ref.read(warmupMetricsServiceProvider);
    final sessions = await metricsService.getRecentSessions(10);
    
    // 预加载所有任务统计数据
    final taskStats = <String, Map<String, int>?>{};
    final taskNames = <String>{};
    for (final session in sessions) {
      for (final task in session) {
        taskNames.add(task.taskName);
      }
    }
    for (final taskName in taskNames) {
      taskStats[taskName] = await metricsService.getStatsForTask(taskName);
    }
    
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _taskStats = taskStats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metricsService = ref.watch(warmupMetricsServiceProvider);
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.performanceReport_title),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final sessions = _sessions;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.performanceReport_title),
        actions: [
          if (sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: context.l10n.common_clear,
              onPressed: () => _confirmClear(context, metricsService),
            ),
        ],
      ),
      body: sessions.isEmpty
          ? _buildEmptyState(context, theme)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 总体统计
                _buildOverallStats(context, theme, sessions),
                const SizedBox(height: 24),

                // 任务统计
                _buildSectionHeader(
                  theme,
                  context.l10n.performanceReport_taskStats,
                ),
                const SizedBox(height: 8),
                _buildTaskStats(context, theme, sessions),
              ],
            ),
      floatingActionButton: sessions.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _exportReport(context, metricsService, sessions),
              icon: const Icon(Icons.download),
              label: Text(context.l10n.performanceReport_export),
            )
          : null,
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.speed_outlined,
            size: 64,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无性能数据',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '完成预热后此页面将显示统计数据',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建总体统计
  Widget _buildOverallStats(
    BuildContext context,
    ThemeData theme,
    List<List<WarmupTaskMetrics>> sessions,
  ) {
    final totalSessions = sessions.length;
    final totalTasks = sessions.fold<int>(
      0,
      (sum, session) => sum + session.length,
    );

    // 计算总成功率
    int successCount = 0;
    int totalTasksCount = 0;
    for (final session in sessions) {
      for (final task in session) {
        totalTasksCount++;
        if (task.isSuccess) {
          successCount++;
        }
      }
    }
    final successRate = totalTasksCount > 0
        ? (successCount / totalTasksCount * 100).round()
        : 0;

    // 计算平均总耗时
    final avgTotalDuration = sessions.isEmpty
        ? 0
        : sessions
                .map(
                  (session) => session.fold<int>(
                    0,
                    (sum, task) => sum + task.durationMs,
                  ),
                )
                .reduce((a, b) => a + b) ~/
            sessions.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '总体统计',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    theme,
                    Icons.history,
                    '预热次数',
                    '$totalSessions',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    theme,
                    Icons.task_alt,
                    '总任务数',
                    '$totalTasks',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    theme,
                    Icons.timer_outlined,
                    '平均总耗时',
                    _formatDuration(avgTotalDuration),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    theme,
                    Icons.check_circle_outline,
                    context.l10n.performanceReport_successRate,
                    '$successRate%',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 构建任务统计列表
  Widget _buildTaskStats(
    BuildContext context,
    ThemeData theme,
    List<List<WarmupTaskMetrics>> sessions,
  ) {
    // 收集所有唯一的任务名称
    final taskNames = <String>{};
    for (final session in sessions) {
      for (final task in session) {
        taskNames.add(task.taskName);
      }
    }

    // 按任务名称分组并计算统计信息
    final taskStats = <String, Map<String, dynamic>>{};
    for (final taskName in taskNames) {
      final stats = _taskStats[taskName];
      if (stats != null) {
        // 计算成功率
        int successCount = 0;
        int totalCount = 0;
        for (final session in sessions) {
          final task = session.firstWhere(
            (t) => t.taskName == taskName,
            orElse: () => session.first,
          );
          totalCount++;
          if (task.isSuccess) {
            successCount++;
          }
        }
        final successRate =
            totalCount > 0 ? (successCount / totalCount * 100).round() : 0;

        taskStats[taskName] = {
          ...stats,
          'successRate': successRate,
          'totalCount': totalCount,
        };
      }
    }

    if (taskStats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('暂无任务统计数据'),
        ),
      );
    }

    return Column(
      children: taskStats.entries.map((entry) {
        final taskName = entry.key;
        final stats = entry.value;
        final translatedName = _translateTaskName(context, taskName);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text('${stats['successRate']}%'),
            ),
            title: Text(translatedName),
            subtitle: Text(
              '次数: ${stats['count']} | '
              '平均: ${_formatDuration(stats['average'])} | '
              '最小: ${_formatDuration(stats['min'])} | '
              '最大: ${_formatDuration(stats['max'])}',
            ),
            trailing: _buildStatusIcon(theme, stats['successRate'] as int),
          ),
        );
      }).toList(),
    );
  }

  /// 构建状态图标
  Widget _buildStatusIcon(ThemeData theme, int successRate) {
    if (successRate >= 90) {
      return const Icon(
        Icons.check_circle,
        color: Colors.green,
      );
    } else if (successRate >= 70) {
      return const Icon(
        Icons.warning,
        color: Colors.orange,
      );
    } else {
      return const Icon(
        Icons.error,
        color: Colors.red,
      );
    }
  }

  /// 构建分组标题
  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 翻译任务名称
  String _translateTaskName(BuildContext context, String taskKey) {
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
      default:
        return taskKey;
    }
  }

  /// 格式化时长
  String _formatDuration(int ms) {
    if (ms < 1000) {
      return '${ms}ms';
    } else if (ms < 60000) {
      final seconds = (ms / 1000).toStringAsFixed(1);
      return '${seconds}s';
    } else {
      final minutes = (ms / 60000).toStringAsFixed(1);
      return '${minutes}m';
    }
  }

  /// 确认清空数据
  void _confirmClear(
    BuildContext context,
    WarmupMetricsService metricsService,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空性能数据'),
        content: const Text('确定要清空所有性能统计数据吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldContext = context;
              Navigator.pop(dialogContext);
              await metricsService.clear();
              if (scaffoldContext.mounted) {
                await _loadData(); // 刷新数据
                if (scaffoldContext.mounted) {
                  AppToast.success(scaffoldContext, '性能数据已清空');
                }
              }
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 导出报告
  Future<void> _exportReport(
    BuildContext context,
    WarmupMetricsService metricsService,
    List<List<WarmupTaskMetrics>> sessions,
  ) async {
    try {
      // 准备导出数据
      final exportData = {
        'exportedAt': DateTime.now().toIso8601String(),
        'totalSessions': sessions.length,
        'sessions': sessions.map((session) {
          return session.map((task) => task.toJson()).toList();
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // 选择保存位置
      final result = await FilePicker.platform.saveFile(
        dialogTitle: context.l10n.performanceReport_export,
        fileName: 'warmup_report_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && context.mounted) {
        final file = File(result);
        await file.writeAsString(jsonString);

        if (context.mounted) {
          AppToast.success(
            context,
            context.l10n.performanceReport_exportSuccess,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(
          context,
          '${context.l10n.common_error}: ${e.toString()}',
        );
      }
    }
  }
}
