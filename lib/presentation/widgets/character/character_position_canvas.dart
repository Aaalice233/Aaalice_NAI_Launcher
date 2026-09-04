import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/character_position_canvas_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/composition_guide_provider.dart';
import '../../providers/generation/generation_params_selectors.dart';
import '../../providers/image_generation_provider.dart';
import '../common/composition_guide.dart';
import '../common/decoded_memory_image.dart';
import 'composition_guide_button.dart';

/// 芯片显示信息：性别符号 + 显示名
typedef CharacterChipDisplay = ({IconData? genderIcon, String? label});

/// 解析角色切换芯片的显示信息（官网规则）
///
/// - 性别符号：仅当提示词**第一个 tag** 为 girl/boy 系（girl/1girl/boy/1boy，
///   大小写不敏感）时显示，判断依据是提示词内容而非 gender 字段
/// - 显示名：用户自定义过名称（不匹配默认 `Character N`，含词库导入名）
///   优先用名称；否则取提示词第一个 tag，第一个是性别 tag 则取第二个
CharacterChipDisplay resolveCharacterChipDisplay(CharacterPrompt character) {
  final tags = character.prompt
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  // 性别符号与配色同源：依提示词首 tag 推导的有效性别
  final genderIcon = switch (character.effectiveGender) {
    CharacterGender.female when tags.isNotEmpty => Icons.female,
    CharacterGender.male when tags.isNotEmpty => Icons.male,
    _ => null,
  };
  var labelFromPrompt = tags.isNotEmpty ? tags.first : null;
  if (genderIcon != null) {
    labelFromPrompt = tags.length > 1 ? tags[1] : null;
  }

  final hasCustomName = !RegExp(
    r'^Character \d+$',
  ).hasMatch(character.name.trim());
  final label = hasCustomName ? character.name.trim() : labelFromPrompt;

  return (genderIcon: genderIcon, label: label);
}

/// 角色位置画布
///
/// 占据图像预览区：在当前预览图（或按生成参数宽高比的空底）上
/// 直接拖动角色锚点设置构图位置。坐标连续生效（0-1 百分比），
/// 拖到哪 API 就收到哪，无格线、无量化。
///
/// - 顶栏：标题 + AI 选择/自定义分段 + 关闭
/// - 芯片条：每个角色一个切换芯片，点击选中（与角色卡编辑态联动）
/// - AI 选择模式：锚点隐藏，位置数据保留，切回自定义原样恢复
class CharacterPositionCanvasView extends ConsumerStatefulWidget {
  const CharacterPositionCanvasView({super.key});

  @override
  ConsumerState<CharacterPositionCanvasView> createState() =>
      _CharacterPositionCanvasViewState();
}

class _CharacterPositionCanvasViewState
    extends ConsumerState<CharacterPositionCanvasView> {
  /// 拖动中的角色与本地坐标（松手才写入 provider，避免高频写盘）
  String? _draggingId;
  double _dragRow = 0.5;
  double _dragColumn = 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final config = ref.watch(characterPromptNotifierProvider);
    final characters = config.characters;
    final selectedId = ref.watch(selectedCharacterIdProvider);

    return Column(
      children: [
        _buildHeader(context, theme, l10n, config.globalAiChoice),
        if (characters.isNotEmpty)
          _ChipBar(characters: characters, selectedId: selectedId),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Center(child: _buildCanvas(context, theme, l10n, config)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            config.globalAiChoice
                ? l10n.characterCanvas_aiHint
                : l10n.characterCanvas_dragHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 顶栏 ====================

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    bool globalAiChoice,
  ) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.control_camera, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            l10n.characterCanvas_title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const CompositionGuideButton(),
          IconButton(
            onPressed: () =>
                ref.read(characterPositionCanvasProvider.notifier).close(),
            icon: const Icon(Icons.close, size: 20),
            tooltip: l10n.common_close,
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 画布 ====================

  Widget _buildCanvas(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    CharacterPromptConfig config,
  ) {
    final colorScheme = theme.colorScheme;
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final previewDimensions = ref.watch(
      generationParamsNotifierProvider.select(selectPreviewDimensionsViewData),
    );
    final guide = ref.watch(compositionGuideNotifierProvider);

    final backgroundImage = generationState.displayImages.isNotEmpty
        ? generationState.displayImages.first
        : null;
    // 锚点坐标用于下一次请求；历史预览只作背景，不能决定画布尺寸。
    final aspectRatio = previewDimensions.width / previewDimensions.height;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                if (backgroundImage != null) ...[
                  DecodedMemoryImage(
                    bytes: backgroundImage.bytes,
                    fit: BoxFit.cover,
                    maxLogicalWidth: size.width,
                    maxLogicalHeight: size.height,
                    gaplessPlayback: true,
                  ),
                  // 轻微暗化，让锚点在亮图上也清晰
                  const ColoredBox(color: Color(0x26000000)),
                ] else
                  ColoredBox(color: colorScheme.surfaceContainerLow),
                if (config.globalAiChoice)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.characterCanvas_aiHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < config.characters.length; i++)
                    _buildAnchor(
                      context,
                      config,
                      config.characters[i],
                      i,
                      size,
                    ),
                // 参考线压在锚点之上，才看得清锚点落在哪条线的哪一侧
                CompositionGuideOverlay(
                  mode: guide.mode,
                  columns: guide.columns,
                  rows: guide.rows,
                ),
                // 浮签独立成层且始终位于列表尾部：拖动开始时插入它
                // 不会挤动锚点的 Element 位置（锚点手势不被打断）
                if (!config.globalAiChoice && _draggingId != null)
                  _buildDragLabel(size),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 锚点显示坐标：拖动中用本地值，否则使用与请求层一致的有效位置。
  ({double row, double column}) _anchorPosition(
    CharacterPromptConfig config,
    CharacterPrompt character,
  ) {
    if (_draggingId == character.id) {
      return (row: _dragRow, column: _dragColumn);
    }
    final position = config.resolvePosition(character);
    return (row: position.row, column: position.column);
  }

  /// 拖动中的坐标浮签（独立于锚点渲染，避免打断手势）
  Widget _buildDragLabel(Size canvasSize) {
    final centerX = _dragColumn * canvasSize.width;
    final centerY = _dragRow * canvasSize.height;

    return Positioned(
      key: const ValueKey('canvas-drag-label'),
      left: (centerX - 40).clamp(0.0, math.max(0.0, canvasSize.width - 80)),
      top: (centerY - 50).clamp(0.0, math.max(0.0, canvasSize.height - 22)),
      child: IgnorePointer(
        child: Container(
          width: 80,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${(_dragColumn * 100).round()}% , '
            '${(_dragRow * 100).round()}%',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildAnchor(
    BuildContext context,
    CharacterPromptConfig config,
    CharacterPrompt character,
    int index,
    Size canvasSize,
  ) {
    final selectedId = ref.watch(selectedCharacterIdProvider);
    final isSelected = selectedId == character.id;
    final isDragging = _draggingId == character.id;
    final position = _anchorPosition(config, character);
    final diameter = isDragging ? 40.0 : (isSelected ? 36.0 : 32.0);
    final centerX = position.column * canvasSize.width;
    final centerY = position.row * canvasSize.height;

    // 稳定 key：选中/拖动引发的重建不丢失 Element，
    // 进行中的 pan 手势识别器得以存活，按下即可直接拖动
    return Positioned(
      key: ValueKey('canvas-anchor-${character.id}'),
      left: centerX - diameter / 2,
      top: centerY - diameter / 2,
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveAnchorIntent(
            dx: -0.02,
          ),
          SingleActivator(LogicalKeyboardKey.arrowRight): _MoveAnchorIntent(
            dx: 0.02,
          ),
          SingleActivator(LogicalKeyboardKey.arrowUp): _MoveAnchorIntent(
            dy: -0.02,
          ),
          SingleActivator(LogicalKeyboardKey.arrowDown): _MoveAnchorIntent(
            dy: 0.02,
          ),
        },
        actions: {
          _MoveAnchorIntent: CallbackAction<_MoveAnchorIntent>(
            onInvoke: (intent) {
              _moveAnchorWithKeyboard(character, position, intent);
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          selected: isSelected,
          label:
              '${character.name}, ${(position.column * 100).round()}%, '
              '${(position.row * 100).round()}%',
          onTap: () => ref
              .read(selectedCharacterIdProvider.notifier)
              .select(character.id),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) {
              ref
                  .read(selectedCharacterIdProvider.notifier)
                  .select(character.id);
              setState(() {
                _draggingId = character.id;
                _dragRow = position.row;
                _dragColumn = position.column;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _dragColumn =
                    (_dragColumn + details.delta.dx / canvasSize.width).clamp(
                      0.0,
                      1.0,
                    );
                _dragRow = (_dragRow + details.delta.dy / canvasSize.height)
                    .clamp(0.0, 1.0);
              });
            },
            onPanEnd: (_) => _commitDrag(character),
            onPanCancel: () => _commitDrag(character),
            child: _AnchorDot(
              character: character,
              index: index,
              diameter: diameter,
              emphasized: isSelected || isDragging,
            ),
          ),
        ),
      ),
    );
  }

  void _moveAnchorWithKeyboard(
    CharacterPrompt character,
    ({double row, double column}) position,
    _MoveAnchorIntent intent,
  ) {
    final next = CharacterPosition(
      mode: CharacterPositionMode.custom,
      row: (position.row + intent.dy).clamp(0.0, 1.0),
      column: (position.column + intent.dx).clamp(0.0, 1.0),
    );
    ref.read(selectedCharacterIdProvider.notifier).select(character.id);
    ref
        .read(characterPromptNotifierProvider.notifier)
        .updateCharacter(
          character.copyWith(
            positionMode: CharacterPositionMode.custom,
            customPosition: next,
          ),
        );
  }

  void _commitDrag(CharacterPrompt character) {
    if (_draggingId != character.id) return;
    ref
        .read(characterPromptNotifierProvider.notifier)
        .updateCharacter(
          character.copyWith(
            positionMode: CharacterPositionMode.custom,
            customPosition: CharacterPosition(
              mode: CharacterPositionMode.custom,
              row: _dragRow,
              column: _dragColumn,
            ),
          ),
        );
    setState(() => _draggingId = null);
  }
}

class _MoveAnchorIntent extends Intent {
  const _MoveAnchorIntent({this.dx = 0, this.dy = 0});

  final double dx;
  final double dy;
}

/// 位置模式分段（AI 选择 / 自定义 / 画布入口）
///
/// 绑定全局 globalAiChoice，常驻在角色模块头部。
/// 「自定义」右侧的图标是位置画布的唯一入口（官网同款布局）。
class CharacterPositionModeSegments extends ConsumerWidget {
  const CharacterPositionModeSegments({
    super.key,
    this.forceExitMaximizedPrompt = false,
  });

  final bool forceExitMaximizedPrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final globalAiChoice = ref.watch(
      characterPromptNotifierProvider.select((c) => c.globalAiChoice),
    );
    final canvasOpen = ref.watch(characterPositionCanvasProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeSegment(
          selected: globalAiChoice,
          radius: const BorderRadius.horizontal(left: Radius.circular(6)),
          onTap: () => ref
              .read(characterPromptNotifierProvider.notifier)
              .setGlobalAiChoice(true),
          child: Text(
            l10n.characterCanvas_aiChoice,
            style: _segmentTextStyle(context, globalAiChoice),
          ),
        ),
        _ModeSegment(
          selected: !globalAiChoice,
          radius: BorderRadius.zero,
          onTap: () => ref
              .read(characterPromptNotifierProvider.notifier)
              .setGlobalAiChoice(false),
          child: Text(
            l10n.characterCanvas_custom,
            style: _segmentTextStyle(context, !globalAiChoice),
          ),
        ),
        // 位置画布入口
        Tooltip(
          message: l10n.characterCanvas_title,
          waitDuration: const Duration(milliseconds: 500),
          child: _ModeSegment(
            selected: canvasOpen,
            radius: const BorderRadius.horizontal(right: Radius.circular(6)),
            onTap: () => ref
                .read(characterPositionCanvasProvider.notifier)
                .toggle(forceExitMaximizedPrompt: forceExitMaximizedPrompt),
            child: Icon(
              Icons.control_camera,
              size: 15,
              color: canvasOpen
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  TextStyle? _segmentTextStyle(BuildContext context, bool selected) {
    final theme = Theme.of(context);
    return theme.textTheme.labelMedium?.copyWith(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
  }
}

/// 分段按钮外壳
class _ModeSegment extends StatelessWidget {
  final bool selected;
  final BorderRadius radius;
  final VoidCallback onTap;
  final Widget child;

  const _ModeSegment({
    required this.selected,
    required this.radius,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controlExtent = context.interactionPolicy.minimumControlExtent;

    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        constraints: BoxConstraints(minHeight: controlExtent),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.14)
              : colorScheme.surfaceContainer,
          borderRadius: radius,
        ),
        child: child,
      ),
    );
  }
}

/// 角色切换芯片条
class _ChipBar extends ConsumerWidget {
  final List<CharacterPrompt> characters;
  final String? selectedId;

  const _ChipBar({required this.characters, required this.selectedId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 34,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < characters.length; i++) ...[
              _CharacterChip(
                character: characters[i],
                index: i,
                selected: characters[i].id == selectedId,
                onTap: () => ref
                    .read(selectedCharacterIdProvider.notifier)
                    .select(characters[i].id),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单个角色切换芯片：序号 + 性别符号（依提示词首 tag）+ 显示名
class _CharacterChip extends StatelessWidget {
  final CharacterPrompt character;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _CharacterChip({
    required this.character,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final display = resolveCharacterChipDisplay(character);
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.14)
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${index + 1}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (display.genderIcon != null) ...[
              const SizedBox(width: 3),
              Icon(display.genderIcon, size: 14, color: foreground),
            ],
            if (display.label != null) ...[
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  display.label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 锚点圆点：性别色填充（词库角色显示圆形缩略图）+ 序号 + 白描边
class _AnchorDot extends StatelessWidget {
  final CharacterPrompt character;
  final int index;
  final double diameter;
  final bool emphasized;

  const _AnchorDot({
    required this.character,
    required this.index,
    required this.diameter,
    required this.emphasized,
  });

  static Color _genderColor(CharacterGender gender) {
    switch (gender) {
      case CharacterGender.female:
        return const Color(0xFFEC4899);
      case CharacterGender.male:
        return const Color(0xFF3B82F6);
      case CharacterGender.other:
        return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasThumbnail =
        character.thumbnailPath != null && character.thumbnailPath!.isNotEmpty;

    final anchor = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: _genderColor(character.effectiveGender),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: emphasized ? 2.5 : 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasThumbnail)
            Image.file(
              File(character.thumbnailPath!),
              fit: BoxFit.cover,
              cacheWidth: DecodedMemoryImage.resolveCacheDimension(
                logicalSize: math.max(diameter, 40),
                constrainedSize: null,
                pixelRatio: MediaQuery.devicePixelRatioOf(context),
              ),
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: Colors.white,
                fontSize: diameter * 0.4,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      message: character.name,
      waitDuration: const Duration(milliseconds: 600),
      child: AnimatedOpacity(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        opacity: character.enabled ? 1.0 : 0.45,
        child: anchor,
      ),
    );
  }
}
