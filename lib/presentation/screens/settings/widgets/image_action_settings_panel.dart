import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/image_action_settings_provider.dart';
import '../../../widgets/common/image_card_action.dart';

/// 图片操作按钮配置面板
///
/// 包含四大业务场景（历史记录、画布预览、图片详情、本地图库）的独立配置：
/// 上半区：功能启用与停用复选池
/// 下半区：所见即所得的卡片预览图，支持直接拖拽按钮调整显示顺序并自动换行
class ImageActionSettingsPanel extends ConsumerStatefulWidget {
  const ImageActionSettingsPanel({super.key});

  @override
  ConsumerState<ImageActionSettingsPanel> createState() =>
      _ImageActionSettingsPanelState();
}

class _ImageActionSettingsPanelState
    extends ConsumerState<ImageActionSettingsPanel> {
  ImageActionScene _selectedScene = ImageActionScene.historyCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsState = ref.watch(imageActionSettingsProvider);
    final notifier = ref.read(imageActionSettingsProvider.notifier);

    final pool = ImageActionRegistry.getPool(_selectedScene);
    final activeActions = settingsState.forScene(_selectedScene);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 场景切换 Tab 栏
        _buildSceneTabBar(theme, colorScheme),

        const SizedBox(height: 16),

        // 上半区：功能勾选池
        _buildCheckboxSection(
          context,
          theme,
          colorScheme,
          pool,
          activeActions,
          notifier,
        ),

        const SizedBox(height: 20),

        // 分隔线
        Divider(
          height: 1,
          thickness: 1,
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),

        const SizedBox(height: 20),

        // 下半区：所见即所得卡片预览与直接拖拽重排
        _buildPreviewSection(
          context,
          theme,
          colorScheme,
          activeActions,
          notifier,
        ),
      ],
    );
  }

  /// 场景 Tab 切换栏
  Widget _buildSceneTabBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final scene in ImageActionScene.values)
            Expanded(
              child: _SceneTabButton(
                scene: scene,
                isSelected: _selectedScene == scene,
                onTap: () {
                  if (_selectedScene != scene) {
                    setState(() {
                      _selectedScene = scene;
                    });
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  /// 上半区：功能池复选框
  Widget _buildCheckboxSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<ImageCardActionId> pool,
    List<ImageCardActionId> activeActions,
    ImageActionSettingsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '功能启用管理',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '已启用 ${activeActions.length} / 可选 ${pool.length} 项',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('恢复默认', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                await notifier.resetToDefault(_selectedScene);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 动态自适应网格或包裹排布
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final actionId in pool)
              _ActionCheckboxChip(
                meta: ImageActionRegistry.getMeta(actionId),
                isChecked: activeActions.contains(actionId),
                onChanged: (checked) {
                  notifier.toggleAction(_selectedScene, actionId, checked);
                },
              ),
          ],
        ),
      ],
    );
  }

  /// 下半区：所见即所得卡片预览与直接拖拽重排
  Widget _buildPreviewSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<ImageCardActionId> activeActions,
    ImageActionSettingsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '真实效果预览与排序',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '（长按或拖拽按钮可调整顺序，宽度不足时自动换行）',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 居中呈现模拟真实场景卡片
        Center(
          child: _buildMockSceneCard(
            context,
            theme,
            colorScheme,
            activeActions,
            notifier,
          ),
        ),

        const SizedBox(height: 14),

        // 顺序指示条
        if (activeActions.isNotEmpty)
          _buildSequenceBar(theme, colorScheme, activeActions),
      ],
    );
  }

  /// 构建不同场景的真实效果卡片
  Widget _buildMockSceneCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    List<ImageCardActionId> activeActions,
    ImageActionSettingsNotifier notifier,
  ) {
    final double cardWidth = switch (_selectedScene) {
      ImageActionScene.historyCard => 260.0,
      ImageActionScene.canvasPreview => 340.0,
      ImageActionScene.imageDetail => 380.0,
      ImageActionScene.localGallery => 240.0,
    };

    final double cardHeight = switch (_selectedScene) {
      ImageActionScene.historyCard => 260.0,
      ImageActionScene.canvasPreview => 220.0,
      ImageActionScene.imageDetail => 160.0,
      ImageActionScene.localGallery => 260.0,
    };

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1E2025),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 模拟图片背景
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2B303C),
                    const Color(0xFF16191F),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      switch (_selectedScene) {
                        ImageActionScene.historyCard => Icons.history_rounded,
                        ImageActionScene.canvasPreview => Icons.brush_rounded,
                        ImageActionScene.imageDetail => Icons.fullscreen_rounded,
                        ImageActionScene.localGallery => Icons.photo_library_rounded,
                      },
                      size: 40,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedScene.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 场景对应的真实按钮排布区域
          switch (_selectedScene) {
            ImageActionScene.historyCard ||
            ImageActionScene.localGallery =>
              // 右上角从右往左流式换行排布
              Positioned(
                top: 8,
                right: 8,
                left: 8,
                child: Align(
                  alignment: Alignment.topRight,
                  child: activeActions.isEmpty
                      ? _buildEmptyHint()
                      : Wrap(
                          textDirection: TextDirection.rtl,
                          alignment: WrapAlignment.start,
                          spacing: 5,
                          runSpacing: 5,
                          children: [
                            for (int i = 0; i < activeActions.length; i++)
                              _DraggableActionItem(
                                index: i,
                                meta: ImageActionRegistry.getMeta(activeActions[i]),
                                scene: _selectedScene,
                                onReorder: (from, to) {
                                  notifier.reorderAction(_selectedScene, from, to);
                                },
                              ),
                          ],
                        ),
                ),
              ),

            ImageActionScene.canvasPreview =>
              // 底部中央浮动条，水平居中换行
              Positioned(
                bottom: 12,
                left: 8,
                right: 8,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: activeActions.isEmpty
                        ? _buildEmptyHint()
                        : Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              for (int i = 0; i < activeActions.length; i++)
                                _DraggableActionItem(
                                  index: i,
                                  meta: ImageActionRegistry.getMeta(
                                    activeActions[i],
                                  ),
                                  scene: _selectedScene,
                                  onReorder: (from, to) {
                                    notifier.reorderAction(
                                      _selectedScene,
                                      from,
                                      to,
                                    );
                                  },
                                ),
                            ],
                          ),
                  ),
                ),
              ),

            ImageActionScene.imageDetail =>
              // 顶栏右侧按钮组
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.close, color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        '1 / 10',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const Spacer(),
                      Flexible(
                        child: activeActions.isEmpty
                            ? _buildEmptyHint()
                            : Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (int i = 0; i < activeActions.length; i++)
                                    _DraggableActionItem(
                                      index: i,
                                      meta: ImageActionRegistry.getMeta(
                                        activeActions[i],
                                      ),
                                      scene: _selectedScene,
                                      onReorder: (from, to) {
                                        notifier.reorderAction(
                                          _selectedScene,
                                          from,
                                          to,
                                        );
                                      },
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
          },
        ],
      ),
    );
  }

  Widget _buildEmptyHint() {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Text(
        '未启用任何按钮',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }

  /// 顺序说明小条
  Widget _buildSequenceBar(
    ThemeData theme,
    ColorScheme colorScheme,
    List<ImageCardActionId> activeActions,
  ) {
    final isRtlLayout =
        _selectedScene == ImageActionScene.historyCard ||
        _selectedScene == ImageActionScene.localGallery;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_list_numbered_rounded,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            isRtlLayout ? '排布顺序（由右至左）：' : '排布顺序：',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (int i = 0; i < activeActions.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${i + 1}. ${ImageActionRegistry.getMeta(activeActions[i]).label}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (i < activeActions.length - 1)
                    Text(
                      '→',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 场景 Tab 项
class _SceneTabButton extends StatelessWidget {
  const _SceneTabButton({
    required this.scene,
    required this.isSelected,
    required this.onTap,
  });

  final ImageActionScene scene;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            scene.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// 功能选择复选 Chip
class _ActionCheckboxChip extends StatelessWidget {
  const _ActionCheckboxChip({
    required this.meta,
    required this.isChecked,
    required this.onChanged,
  });

  final ImageActionMeta meta;
  final bool isChecked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!isChecked),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isChecked
                ? colorScheme.primary.withValues(alpha: 0.12)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isChecked
                  ? colorScheme.primary.withValues(alpha: 0.45)
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: Checkbox(
                  value: isChecked,
                  onChanged: (val) => onChanged(val ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                meta.icon,
                size: 15,
                color: isChecked
                    ? (meta.isDanger ? colorScheme.error : colorScheme.primary)
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                meta.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isChecked ? FontWeight.w500 : FontWeight.w400,
                  color: isChecked
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 可拖拽与接收拖放的按钮项
class _DraggableActionItem extends StatelessWidget {
  const _DraggableActionItem({
    required this.index,
    required this.meta,
    required this.scene,
    required this.onReorder,
  });

  final int index;
  final ImageActionMeta meta;
  final ImageActionScene scene;
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) {
        onReorder(details.data, index);
      },
      builder: (context, candidateData, rejectedData) {
        final isHoveredTarget = candidateData.isNotEmpty;

        return Draggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.15,
              child: _ButtonVisual(
                meta: meta,
                isHighlight: true,
                borderPulse: true,
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: _ButtonVisual(meta: meta),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: isHoveredTarget
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colorScheme.primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  )
                : null,
            child: _ButtonVisual(meta: meta),
          ),
        );
      },
    );
  }
}

/// 模拟卡片上的按钮外观
class _ButtonVisual extends StatelessWidget {
  const _ButtonVisual({
    required this.meta,
    this.isHighlight = false,
    this.borderPulse = false,
  });

  final ImageActionMeta meta;
  final bool isHighlight;
  final bool borderPulse;

  @override
  Widget build(BuildContext context) {
    final isDanger = meta.isDanger;
    final baseColor = isDanger ? const Color(0xFFE53935) : Colors.white;

    return Tooltip(
      message: '${meta.label} (长按拖拽排序)',
      waitDuration: const Duration(milliseconds: 200),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isHighlight
              ? Colors.black.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.65),
          border: Border.all(
            color: borderPulse
                ? Colors.blueAccent
                : (isHighlight
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.25)),
            width: isHighlight ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            meta.icon,
            size: 16,
            color: baseColor.withValues(alpha: isHighlight ? 1.0 : 0.9),
          ),
        ),
      ),
    );
  }
}
