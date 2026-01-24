import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../data/repositories/local_gallery_repository.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/selection_mode_provider.dart';
import '../../widgets/common/pagination_bar.dart';
import '../../widgets/grouped_grid_view.dart';
import '../../widgets/local_image_card.dart';

/// 本地画廊屏幕
class LocalGalleryScreen extends ConsumerStatefulWidget {
  const LocalGalleryScreen({super.key});

  @override
  ConsumerState<LocalGalleryScreen> createState() => _LocalGalleryScreenState();
}

class _LocalGalleryScreenState extends ConsumerState<LocalGalleryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  /// Key for accessing GroupedGridView's scrollToGroup method
  /// 用于访问 GroupedGridView 的 scrollToGroup 方法的键
  final GlobalKey<GroupedGridViewState> _groupedGridViewKey = GlobalKey<GroupedGridViewState>();

  @override
  void initState() {
    super.initState();
    // 首次加载时检查权限并扫描图片
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissionsAndScan();
      await _showFirstTimeTip();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 搜索防抖
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(localGalleryNotifierProvider.notifier).setSearchQuery(value);
    });
  }

  /// 批量加入队列
  Future<void> _addSelectedToQueue() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final galleryState = ref.read(localGalleryNotifierProvider);

    final selectedImages = galleryState.currentImages
        .where((img) => selectionState.selectedIds.contains(img.path))
        .toList();

    if (selectedImages.isEmpty) return;

    final tasks = selectedImages
        .where((img) => img.metadata?.prompt.isNotEmpty == true)
        .map(
          (img) => ReplicationTask.create(
            prompt: img.metadata!.prompt,
            thumbnailUrl: img.path, // 本地路径
            source: ReplicationTaskSource.local,
          ),
        )
        .toList();

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选中的图片没有 Prompt 信息')),
      );
      return;
    }

    final addedCount =
        await ref.read(replicationQueueNotifierProvider.notifier).addAll(tasks);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 $addedCount 个任务到队列')),
      );
      ref.read(localGallerySelectionNotifierProvider.notifier).exit();
    }
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
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        title: Text(
          '需要存储权限',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          '本地画廊需要访问存储权限才能扫描您生成的图片。\n\n'
          '请在设置中授予权限后重试。',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '取消',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              PermissionUtils.openAppSettings();
            },
            child: Text(
              '打开设置',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
              ),
            ),
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

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        title: Text(
          '💡 使用提示',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          '右键点击（桌面端）或长按（移动端）图片可以：\n\n'
          '• 复制 Prompt\n'
          '• 复制 Seed\n'
          '• 查看完整元数据',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '知道了',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 打开图片保存文件夹
  Future<void> _openImageFolder() async {
    try {
      final dir = await LocalGalleryRepository.instance.getImageDirectory();

      // 确保目录存在
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 获取绝对路径
      final absolutePath = dir.absolute.path;

      // 显示路径信息（调试用）
      debugPrint('Opening folder: $absolutePath');

      // 使用系统资源管理器打开文件夹
      if (Platform.isWindows) {
        // Windows: 将正斜杠替换为反斜杠，直接使用 explorer.exe
        final windowsPath = absolutePath.replaceAll('/', '\\');
        debugPrint('Windows path: $windowsPath');

        // 直接调用 explorer.exe，路径作为参数
        await Process.run('explorer.exe', [windowsPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [absolutePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [absolutePath]);
      } else {
        // 其他平台使用 url_launcher
        final uri = Uri.directory(absolutePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开文件夹: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localGalleryNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    // 计算列数（200px/列，最少2列，最多8列）
    final columns = (screenWidth / 200).floor().clamp(2, 8);
    final itemWidth = screenWidth / columns;

    return Scaffold(
      body: Column(
        children: [
          // 顶部工具栏
          _buildToolbar(theme, state),
          // 主体内容
          Expanded(
            child: state.error != null
                ? _buildErrorState(theme, state)
                : state.isIndexing
                    ? _buildIndexingState()
                    : state.allFiles.isEmpty
                        ? _buildEmptyState(context)
                        : _buildContent(theme, state, columns, itemWidth),
          ),
          // 底部分页条
          if (!state.isIndexing &&
              state.filteredFiles.isNotEmpty &&
              state.totalPages > 1)
            PaginationBar(
              currentPage: state.currentPage,
              totalPages: state.totalPages,
              onPageChanged: (p) =>
                  ref.read(localGalleryNotifierProvider.notifier).loadPage(p),
            ),
        ],
      ),
    );
  }

  /// 构建顶部工具栏
  Widget _buildToolbar(ThemeData theme, LocalGalleryState state) {
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);
    final isDark = theme.brightness == Brightness.dark;

    if (selectionState.isActive) {
      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.primaryContainer.withOpacity(0.85)
                  : theme.colorScheme.primaryContainer.withOpacity(0.7),
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(isDark ? 0.2 : 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                _RoundedIconButton(
                  icon: Icons.close,
                  tooltip: '退出多选',
                  onPressed: () => ref.read(localGallerySelectionNotifierProvider.notifier).exit(),
                ),
                const SizedBox(width: 8),
                Text(
                  '已选择 ${selectionState.selectedIds.length} 项',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _RoundedIconButton(
                  icon: Icons.playlist_add,
                  tooltip: '加入队列',
                  onPressed: selectionState.selectedIds.isNotEmpty ? _addSelectedToQueue : null,
                ),
                // 本地画廊不需要批量下载和收藏
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHigh.withOpacity(0.9)
                : theme.colorScheme.surface.withOpacity(0.8),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(isDark ? 0.2 : 0.3),
              ),
            ),
          ),
          child: Column(
            children: [
              // 第一行：标题 + 操作按钮
              Row(
                children: [
                  Text(
                    '本地画廊',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 图片计数
                  if (!state.isIndexing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.colorScheme.primaryContainer.withOpacity(0.4)
                            : theme.colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        state.hasFilters
                            ? '${state.filteredCount} / ${state.totalCount}'
                            : '${state.totalCount}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const Spacer(),
                  // 多选模式切换
                  _RoundedIconButton(
                    icon: Icons.checklist,
                    tooltip: '多选模式',
                    onPressed: () {
                      ref.read(localGallerySelectionNotifierProvider.notifier).enter();
                    },
                  ),
                  const SizedBox(width: 8),
                  // 打开文件夹按钮
                  _RoundedTextButton(
                    icon: Icons.folder_open,
                    label: '打开文件夹',
                    onPressed: _openImageFolder,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  // 刷新按钮
                  if (state.isIndexing)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    _RoundedTextButton(
                      icon: Icons.refresh,
                      label: '刷新',
                      onPressed: () {
                        ref.read(localGalleryNotifierProvider.notifier).refresh();
                      },
                      color: theme.colorScheme.secondary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // 第二行：搜索框 + 日期过滤
              Row(
                children: [
                  // 搜索框
                  Expanded(
                    child: _buildSearchField(theme, state),
                  ),
                  const SizedBox(width: 12),
                  // 日期范围过滤按钮
                  _buildDateRangeButton(theme, state),
                  const SizedBox(width: 8),
                  // 日期选择器按钮（跳转到指定日期）
                  _buildDatePickerButton(theme),
                  // 清除过滤按钮
                  if (state.hasFilters) ...[
                    const SizedBox(width: 8),
                    _RoundedIconButton(
                      icon: Icons.filter_alt_off,
                      tooltip: '清除所有过滤',
                      onPressed: () {
                        _searchController.clear();
                        ref.read(localGalleryNotifierProvider.notifier).clearAllFilters();
                      },
                      color: theme.colorScheme.error,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建搜索框
  Widget _buildSearchField(ThemeData theme, LocalGalleryState state) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.6)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: _searchController,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: '搜索文件名或 Prompt...',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(isDark ? 0.6 : 0.5),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(isDark ? 0.7 : 0.6),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(isDark ? 0.7 : 0.6),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(localGalleryNotifierProvider.notifier)
                        .setSearchQuery('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: (value) {
          setState(() {}); // 更新清除按钮显示状态
          _onSearchChanged(value);
        },
        onSubmitted: (value) {
          _debounceTimer?.cancel();
          ref.read(localGalleryNotifierProvider.notifier).setSearchQuery(value);
        },
      ),
    );
  }

  /// 构建日期范围按钮
  Widget _buildDateRangeButton(ThemeData theme, LocalGalleryState state) {
    final hasDateRange = state.dateStart != null || state.dateEnd != null;

    return OutlinedButton.icon(
      onPressed: () => _selectDateRange(context, state),
      icon: Icon(
        Icons.date_range,
        size: 16,
        color: hasDateRange ? theme.colorScheme.primary : null,
      ),
      label: Text(
        hasDateRange
            ? _formatDateRange(state.dateStart, state.dateEnd)
            : '日期过滤',
        style: TextStyle(
          fontSize: 12,
          color: hasDateRange ? theme.colorScheme.primary : null,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
        side:
            hasDateRange ? BorderSide(color: theme.colorScheme.primary) : null,
      ),
    );
  }

  /// 格式化日期范围显示
  String _formatDateRange(DateTime? start, DateTime? end) {
    final format = DateFormat('MM-dd');
    if (start != null && end != null) {
      return '${format.format(start)}~${format.format(end)}';
    } else if (start != null) {
      return '${format.format(start)}~';
    } else if (end != null) {
      return '~${format.format(end)}';
    }
    return '';
  }

  /// 构建日期选择器按钮（跳转到指定日期）
  Widget _buildDatePickerButton(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return OutlinedButton.icon(
      onPressed: () => _pickDateAndJump(context),
      icon: const Icon(
        Icons.calendar_today,
        size: 16,
      ),
      label: Text(
        l10n.localGallery_jumpToDate,
        style: const TextStyle(fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// 选择日期范围
  Future<void> _selectDateRange(
      BuildContext context, LocalGalleryState state,) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: state.dateStart != null && state.dateEnd != null
          ? DateTimeRange(start: state.dateStart!, end: state.dateEnd!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)), end: now,),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(localGalleryNotifierProvider.notifier).setDateRange(
            picked.start,
            picked.end,
          );
    }
  }

  /// 选择日期并跳转到对应分组
  /// Select date and jump to corresponding group
  Future<void> _pickDateAndJump(BuildContext context) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (pickerContext, child) {
        return Theme(
          data: Theme.of(pickerContext).copyWith(
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      // 确保分组视图已激活
      // Ensure grouped view is activated
      final currentState = ref.read(localGalleryNotifierProvider);
      final notifier = ref.read(localGalleryNotifierProvider.notifier);
      if (!currentState.isGroupedView) {
        notifier.setGroupedView(true);
      }

      // 等待分组数据加载完成
      // Wait for grouped data to load
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // 计算选中日期属于哪个分组
      // Calculate which group the selected date belongs to
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final selectedDate = DateTime(picked.year, picked.month, picked.day);

      ImageDateGroup? targetGroup;

      if (selectedDate == today) {
        targetGroup = ImageDateGroup.today;
      } else if (selectedDate == yesterday) {
        targetGroup = ImageDateGroup.yesterday;
      } else if (selectedDate.isAfter(thisWeekStart) && selectedDate.isBefore(today)) {
        targetGroup = ImageDateGroup.thisWeek;
      } else {
        targetGroup = ImageDateGroup.earlier;
      }

      // 跳转到对应分组
      // Jump to corresponding group
      _groupedGridViewKey.currentState?.scrollToGroup(targetGroup);

      // 显示提示消息
      // Show hint message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已跳转到 ${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 构建错误状态
  Widget _buildErrorState(ThemeData theme, LocalGalleryState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败: ${state.error}',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(localGalleryNotifierProvider.notifier).refresh(),
            child: Text(
              '重试',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建索引状态
  Widget _buildIndexingState() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '索引本地图片中...',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(isDark ? 0.6 : 1.0),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无本地图片',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '生成的图片将保存在此处',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(isDark ? 0.7 : 1.0),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建内容区
  Widget _buildContent(ThemeData theme, LocalGalleryState state, int columns, double itemWidth) {
    // 分组视图
    // Grouped view
    if (state.isGroupedView) {
      // 分组视图中加载骨架屏
      // Loading skeleton in grouped view
      if (state.isGroupedLoading) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '加载分组图片中...',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      }

      // 分组视图无结果
      // No results in grouped view
      if (state.groupedImages.isEmpty) {
        final isDark = theme.brightness == Brightness.dark;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(isDark ? 0.6 : 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                '无匹配结果',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  ref.read(localGalleryNotifierProvider.notifier).clearAllFilters();
                },
                icon: const Icon(Icons.filter_alt_off, size: 16),
                label: const Text('清除过滤'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      }

      // 显示分组视图
      // Show grouped view
      final selectionState = ref.watch(localGallerySelectionNotifierProvider);

      return GroupedGridView(
        key: _groupedGridViewKey,
        images: state.groupedImages,
        columns: columns,
        itemWidth: itemWidth,
        selectionMode: selectionState.isActive,
        buildSelected: (path) => selectionState.selectedIds.contains(path),
        buildCard: (record) {
          final isSelected = selectionState.selectedIds.contains(record.path);
          return LocalImageCard(
            record: record,
            itemWidth: itemWidth,
            selectionMode: selectionState.isActive,
            isSelected: isSelected,
            onSelectionToggle: () {
              ref.read(localGallerySelectionNotifierProvider.notifier).toggle(record.path);
            },
            onLongPress: () {
              if (!selectionState.isActive) {
                ref.read(localGallerySelectionNotifierProvider.notifier).enterAndSelect(record.path);
              }
            },
            onDeleted: () {
              // 刷新分组视图
              ref.read(localGalleryNotifierProvider.notifier).refresh();
            },
          );
        },
      );
    }

    // 过滤后无结果
    if (state.filteredFiles.isEmpty && state.hasFilters) {
      final isDark = theme.brightness == Brightness.dark;

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(isDark ? 0.6 : 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '无匹配结果',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                ref
                    .read(localGalleryNotifierProvider.notifier)
                    .clearAllFilters();
              },
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('清除过滤'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    // 加载中骨架屏
    if (state.isPageLoading) {
      return GridView.builder(
        key: const PageStorageKey<String>('local_gallery_grid_loading'),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: itemWidth / 250, // 固定宽高比
        ),
        itemCount: state.currentImages.isNotEmpty
            ? state.currentImages.length
            : 20,
        itemBuilder: (c, i) {
          return const Card(
            clipBehavior: Clip.antiAlias,
            child: _ShimmerSkeleton(height: 250),
          );
        },
      );
    }

    // 正常内容
    return GridView.builder(
      key: const PageStorageKey<String>('local_gallery_grid'),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: itemWidth / 250, // 固定宽高比
      ),
      itemCount: state.currentImages.length,
      itemBuilder: (c, i) {
        final record = state.currentImages[i];
        final selectionState = ref.watch(localGallerySelectionNotifierProvider);
        final isSelected = selectionState.selectedIds.contains(record.path);

        return LocalImageCard(
          record: record,
          itemWidth: itemWidth,
          selectionMode: selectionState.isActive,
          isSelected: isSelected,
          onSelectionToggle: () {
            ref
                .read(localGallerySelectionNotifierProvider.notifier)
                .toggle(record.path);
          },
          onLongPress: () {
            if (!selectionState.isActive) {
              ref
                  .read(localGallerySelectionNotifierProvider.notifier)
                  .enterAndSelect(record.path);
            }
          },
          onDeleted: () {
            // 刷新当前页
            ref
                .read(localGalleryNotifierProvider.notifier)
                .loadPage(state.currentPage);
          },
        );
      },
    );
  }
}

/// 圆角图标按钮（带悬停动画）
class _RoundedIconButton extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  const _RoundedIconButton({
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.color,
  });

  @override
  State<_RoundedIconButton> createState() => _RoundedIconButtonState();
}

class _RoundedIconButtonState extends State<_RoundedIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveColor = widget.color ?? theme.colorScheme.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _isHovered
              ? effectiveColor.withOpacity(isDark ? 0.2 : 0.15)
              : effectiveColor.withOpacity(isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: effectiveColor.withOpacity(isDark ? 0.15 : 0.2),
            width: 1,
          ),
        ),
        child: IconButton(
          icon: Icon(widget.icon),
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
          color: effectiveColor,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

/// 圆角文本按钮（带悬停动画）
class _RoundedTextButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const _RoundedTextButton({
    required this.icon,
    required this.label,
    this.onPressed,
    required this.color,
  });

  @override
  State<_RoundedTextButton> createState() => _RoundedTextButtonState();
}

class _RoundedTextButtonState extends State<_RoundedTextButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _isHovered
              ? widget.color.withOpacity(isDark ? 0.25 : 0.2)
              : widget.color.withOpacity(isDark ? 0.12 : 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.color.withOpacity(isDark ? 0.25 : 0.3),
            width: 1,
          ),
        ),
        child: TextButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: 18),
          label: Text(widget.label),
          style: TextButton.styleFrom(
            foregroundColor: widget.color,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
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
    final isDark = colorScheme.brightness == Brightness.dark;

    // Dark mode: use lighter shimmer on dark surface
    // Light mode: use darker shimmer on light surface
    final baseColor = isDark
        ? colorScheme.surfaceContainerHighest.withOpacity(0.2)
        : colorScheme.surfaceContainerHighest.withOpacity(0.3);
    final highlightColor = isDark
        ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
        : colorScheme.surfaceContainerHighest.withOpacity(0.6);

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
