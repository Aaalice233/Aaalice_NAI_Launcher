import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' as md;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../core/agent/agent_types.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/nai_resolution_adapter.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/common/themed_input_dialog.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';
import '../../providers/layout_state_provider.dart';
import '../providers/agent_chat_notifier.dart';
import '../providers/agent_chat_session_view.dart';

/// AI 聊天面板（右侧栏 Tab 之一）。
///
/// 布局：顶部会话工具行 → 消息区（空态为居中欢迎屏）→ 底部圆角
/// 输入容器（内嵌无边框输入框 + 模型标签 + 发送/停止按钮）。
class AgentChatPanel extends ConsumerStatefulWidget {
  const AgentChatPanel({super.key});

  @override
  ConsumerState<AgentChatPanel> createState() => _AgentChatPanelState();
}

class _AgentChatPanelState extends ConsumerState<AgentChatPanel> {
  static const double _scrollDeltaTolerance = 0.5;
  static const double _bottomTolerance = 2.0;

  late final _AgentChatInputController _inputController;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final List<_PendingImage> _pendingImages = [];
  final Map<ImageSource, Uint8List> _messageImageBytes = {};
  final Map<ImageSource, Size> _messageImageSizes = {};
  final Map<String, Uint8List> _markdownDataImageBytes = {};
  bool _autoScroll = true;
  bool _scrollToBottomScheduled = false;
  bool _adjustingScrollPosition = false;
  double? _lastObservedScrollPixels;
  double? _lastObservedMaxScrollExtent;
  int _lastScrollMessageCount = -1;
  String _lastScrollSessionId = '';
  String _lastStreamingText = '';
  List<AgentToolActivity>? _lastActivities;
  OverlayEntry? _inlineImagePreview;

  @override
  void initState() {
    super.initState();
    _inputController = _AgentChatInputController(
      onImageEnter: _showInlineImagePreview,
      onImageExit: _hideInlineImagePreview,
    );
    _scrollController.addListener(_handleScrollPositionChanged);
  }

  @override
  void dispose() {
    _hideInlineImagePreview();
    _inputController.dispose();
    _scrollController.removeListener(_handleScrollPositionChanged);
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _handleScrollPositionChanged() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      return;
    }
    final pixels = position.pixels;
    final maxExtent = position.maxScrollExtent;
    final previousPixels = _lastObservedScrollPixels;
    final previousMaxExtent = _lastObservedMaxScrollExtent;
    _lastObservedScrollPixels = pixels;
    _lastObservedMaxScrollExtent = maxExtent;

    if (_adjustingScrollPosition ||
        previousPixels == null ||
        previousMaxExtent == null) {
      return;
    }

    // 内容范围变化来自图片加载、流式文本或输入区高度变化，不代表用户
    // 离开了底部。只有范围稳定时的真实位移才改变自动跟随状态。
    final delta = pixels - previousPixels;
    final contentRangeChanged =
        (maxExtent - previousMaxExtent).abs() > _scrollDeltaTolerance;
    if (!contentRangeChanged && delta < -_scrollDeltaTolerance) {
      _autoScroll = false;
    } else if (position.extentAfter <= _bottomTolerance) {
      _autoScroll = true;
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (force) {
      _autoScroll = true;
    }
    if (!_autoScroll || _scrollToBottomScheduled) {
      return;
    }
    _scrollToBottomScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottomScheduled = false;
      if (!mounted || !_autoScroll || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      if (!position.hasPixels || !position.hasContentDimensions) {
        return;
      }
      final target = position.maxScrollExtent;
      if (!target.isFinite || (target - position.pixels).abs() < 0.5) {
        return;
      }
      _adjustingScrollPosition = true;
      try {
        _scrollController.jumpTo(target);
        _lastObservedScrollPixels = _scrollController.position.pixels;
        _lastObservedMaxScrollExtent =
            _scrollController.position.maxScrollExtent;
      } finally {
        _adjustingScrollPosition = false;
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    final images = List<_PendingImage>.of(_pendingImages);
    final content = _buildInlineUserContent(text, images);
    if (content.isEmpty) {
      return;
    }
    _hideInlineImagePreview();
    _inputController.clear();
    setState(() => _pendingImages.clear());
    _inputController.imageCount = 0;
    await ref.read(agentChatNotifierProvider.notifier).sendContent(content);
    _inputFocus.requestFocus();
  }

  List<UserContent> _buildInlineUserContent(
    String text,
    List<_PendingImage> images,
  ) {
    final content = <UserContent>[];
    var textStart = 0;
    for (final match in _AgentChatInputController.imagePattern.allMatches(
      text,
    )) {
      final imageNumber = int.tryParse(match.group(1) ?? '');
      if (imageNumber == null ||
          imageNumber < 1 ||
          imageNumber > images.length) {
        continue;
      }
      final leadingText = text.substring(textStart, match.start);
      if (leadingText.trim().isNotEmpty) {
        content.add(UserTextContent(leadingText));
      }
      final image = images[imageNumber - 1];
      content.add(
        UserImageContent(
          ImageContent(
            source: ImageSource.base64(
              mimeType: image.mimeType,
              base64Data: base64Encode(image.bytes),
            ),
          ),
        ),
      );
      textStart = match.end;
    }
    final trailingText = text.substring(textStart);
    if (trailingText.trim().isNotEmpty) {
      content.add(UserTextContent(trailingText));
    }
    return content;
  }

  /// 从本地选择图片附件（多选，数量无上限，魔数校验格式）。
  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || !mounted) {
      return;
    }
    for (final file in result.files) {
      final bytes = await _readImageBytes(file);
      if (!mounted) {
        return;
      }
      if (bytes == null) {
        continue;
      }
      final mimeType = detectImageMime(bytes);
      if (mimeType == null) {
        _showPickError(
          context.l10n.agentChat_unsupportedImageFormat(file.name),
        );
        continue;
      }
      setState(() {
        _pendingImages.add(
          _PendingImage(name: file.name, bytes: bytes, mimeType: mimeType),
        );
      });
      _inputController.imageCount = _pendingImages.length;
      _insertImageToken(_pendingImages.length);
    }
    if (mounted) {
      _inputFocus.requestFocus();
    }
  }

  void _insertImageToken(int imageNumber) {
    final value = _inputController.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;
    final needsLeadingSpace =
        start > 0 && !RegExp(r'\s').hasMatch(value.text[start - 1]);
    final needsTrailingSpace =
        end < value.text.length && !RegExp(r'\s').hasMatch(value.text[end]);
    final insertion =
        '${needsLeadingSpace ? ' ' : ''}[image$imageNumber]'
        '${needsTrailingSpace || end == value.text.length ? ' ' : ''}';
    final updatedText = value.text.replaceRange(start, end, insertion);
    _inputController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
  }

  Future<Uint8List?> _readImageBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes;
    }
    final path = file.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    return File(path).readAsBytes();
  }

  void _showPickError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          width: 320,
        ),
      );
  }

  void _showInlineImagePreview(int imageNumber, Offset pointerPosition) {
    _hideInlineImagePreview();
    if (!mounted || imageNumber < 1 || imageNumber > _pendingImages.length) {
      return;
    }
    final image = _pendingImages[imageNumber - 1];
    final dimensions = NaiResolutionAdapter.readImageSize(image.bytes);
    const maxSize = 240.0;
    final Size previewSize;
    if (dimensions == null || dimensions.$1 <= 0 || dimensions.$2 <= 0) {
      previewSize = const Size(maxSize, maxSize);
    } else {
      final widthScale = maxSize / dimensions.$1;
      final heightScale = maxSize / dimensions.$2;
      final scale = widthScale < heightScale ? widthScale : heightScale;
      previewSize = Size(dimensions.$1 * scale, dimensions.$2 * scale);
    }
    final viewport = MediaQuery.sizeOf(context);
    var left = pointerPosition.dx + 12;
    if (left + previewSize.width > viewport.width - 12) {
      left = pointerPosition.dx - previewSize.width - 12;
    }
    left = left.clamp(12.0, viewport.width - previewSize.width - 12).toDouble();
    var top = pointerPosition.dy + 16;
    if (top + previewSize.height > viewport.height - 12) {
      top = pointerPosition.dy - previewSize.height - 16;
    }
    top = top.clamp(12.0, viewport.height - previewSize.height - 12).toDouble();

    final entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        left: left,
        top: top,
        width: previewSize.width,
        height: previewSize.height,
        child: IgnorePointer(
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            color: Theme.of(overlayContext).colorScheme.surface,
            child: Image.memory(
              image.bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Theme.of(overlayContext).colorScheme.outline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _inlineImagePreview = entry;
    Overlay.of(context).insert(entry);
  }

  void _hideInlineImagePreview() {
    _inlineImagePreview?.remove();
    _inlineImagePreview = null;
  }

  /// 在光标处插入换行（Ctrl+Enter 截断全局快捷键后手动执行）。
  void _insertNewline() {
    final value = _inputController.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;
    final newText = value.text.replaceRange(start, end, '\n');
    _inputController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final state = ref.watch(agentChatNotifierProvider);

    final isEmpty =
        state.messages.isEmpty &&
        !(state.status == AgentChatRunStatus.running ||
            state.streamingText.isNotEmpty ||
            state.activities.isNotEmpty);

    final sessionChanged = state.activeSessionId != _lastScrollSessionId;
    final contentChanged =
        state.messages.length != _lastScrollMessageCount ||
        state.streamingText != _lastStreamingText ||
        !identical(state.activities, _lastActivities);
    _lastScrollSessionId = state.activeSessionId;
    _lastScrollMessageCount = state.messages.length;
    _lastStreamingText = state.streamingText;
    _lastActivities = state.activities;
    if (sessionChanged) {
      _messageImageBytes.clear();
      _messageImageSizes.clear();
      _markdownDataImageBytes.clear();
      _lastObservedScrollPixels = null;
      _lastObservedMaxScrollExtent = null;
      _scrollToBottom(force: true);
    } else if (contentChanged) {
      _scrollToBottom();
    }

    return Column(
      children: [
        _buildSessionRow(theme, l10n, state),
        const Divider(height: 1),
        Expanded(
          child: isEmpty && !state.routeReady
              ? _buildSetupHint(theme, state)
              : isEmpty
              ? _buildHero(theme, l10n, state)
              : _buildMessageList(theme, state),
        ),
        if (state.error.isNotEmpty) _buildErrorBar(theme, state),
        if (state.compacting) _buildCompactingBar(theme, l10n),
        if (state.approvalRequest != null)
          _buildApprovalBar(theme, l10n, state.approvalRequest!),
        _buildInputContainer(theme, l10n, state),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 顶部会话工具行（统一 header：折叠按钮 + 标题 + 会话控制，一行）
  // -------------------------------------------------------------------------

  Widget _buildSessionRow(
    ThemeData theme,
    AppLocalizations l10n,
    AgentChatState state,
  ) {
    final sessionActionsEnabled = canManageAgentChatSessions(state);
    // 统一 32x32 图标按钮，与标题、选择器垂直居中对齐。
    Widget iconButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onTap,
    }) {
      return SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          icon: Icon(icon, size: 18),
          tooltip: tooltip,
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
      );
    }

    // 与历史页 header 同款 padding/标题样式，单行容纳全部会话控制。
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 4, top: 12, bottom: 12),
      child: Row(
        children: [
          // 折叠按钮（收起整个右侧面板）
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => ref
                  .read(layoutStateNotifierProvider.notifier)
                  .setRightPanelExpanded(false),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Text(
              l10n.agentChat_tab,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          iconButton(
            icon: Icons.add_comment_outlined,
            tooltip: l10n.agentChat_newChat,
            onTap: sessionActionsEnabled
                ? () =>
                      ref.read(agentChatNotifierProvider.notifier).newSession()
                : null,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: SizedBox(
                  height: 30,
                  child: _buildSessionSelector(theme, l10n, state),
                ),
              ),
            ),
          ),
          if (state.skills.isNotEmpty)
            SizedBox(
              width: 32,
              height: 32,
              child: Tooltip(
                message: state.skills.map((s) => s.name).take(6).join(', '),
                child: Center(
                  child: Icon(
                    Icons.extension_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionModeButton(
    ThemeData theme,
    AppLocalizations l10n,
    bool running,
  ) {
    final mode = ref.watch(promptAssistantConfigProvider).agentPermissionMode;
    final icon = switch (mode) {
      AgentPermissionMode.safe => Icons.shield_outlined,
      AgentPermissionMode.askBeforeSensitiveActions => Icons.gpp_maybe_outlined,
      AgentPermissionMode.fullAccess => Icons.lock_open_outlined,
    };
    return PopupMenuButton<AgentPermissionMode>(
      enabled: !running,
      tooltip:
          '${l10n.agentChat_permissionMode}: '
          '${_permissionModeLabel(l10n, mode)}',
      onSelected: (value) =>
          ref.read(agentChatNotifierProvider.notifier).setPermissionMode(value),
      itemBuilder: (context) => [
        for (final value in AgentPermissionMode.values)
          PopupMenuItem(
            value: value,
            height: 52,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: value == mode
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _permissionModeLabel(l10n, value),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        _permissionModeDescription(l10n, value),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(
          icon,
          size: 17,
          color: theme.colorScheme.onSurface.withValues(
            alpha: running ? 0.25 : 0.6,
          ),
        ),
      ),
    );
  }

  String _permissionModeLabel(
    AppLocalizations l10n,
    AgentPermissionMode mode,
  ) => switch (mode) {
    AgentPermissionMode.safe => l10n.agentChat_permissionSafe,
    AgentPermissionMode.askBeforeSensitiveActions =>
      l10n.agentChat_permissionAsk,
    AgentPermissionMode.fullAccess => l10n.agentChat_permissionFull,
  };

  String _permissionModeDescription(
    AppLocalizations l10n,
    AgentPermissionMode mode,
  ) => switch (mode) {
    AgentPermissionMode.safe => l10n.agentChat_permissionSafeDescription,
    AgentPermissionMode.askBeforeSensitiveActions =>
      l10n.agentChat_permissionAskDescription,
    AgentPermissionMode.fullAccess => l10n.agentChat_permissionFullDescription,
  };

  static const String _menuNewSession = '__new_session__';
  static const String _menuRenamePrefix = 'rename:';
  static const String _menuDeletePrefix = 'delete:';

  /// 会话下拉：顶部「新会话」项 + 历史会话列表（悬停出现重命名/删除）。
  Widget _buildSessionSelector(
    ThemeData theme,
    AppLocalizations l10n,
    AgentChatState state,
  ) {
    final current = state.sessions
        .where((s) => s.id == state.activeSessionId)
        .firstOrNull;
    final label = (current == null || current.name.isEmpty)
        ? l10n.agentChat_untitled
        : current.name;
    return PopupMenuButton<String>(
      key: const ValueKey('agent-chat-session-selector'),
      enabled: canManageAgentChatSessions(state),
      tooltip: label,
      onSelected: _onSessionMenuSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _menuNewSession,
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.add_comment_outlined,
                size: 15,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.agentChat_newChat,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (state.sessions.isEmpty)
          PopupMenuItem(
            enabled: false,
            height: 36,
            child: Text(
              l10n.agentChat_untitled,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        for (final session in state.sessions)
          PopupMenuItem(
            value: session.id,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _SessionMenuRow(
              session: session,
              label: session.name.isEmpty
                  ? l10n.agentChat_untitled
                  : session.name,
              active: session.id == state.activeSessionId,
              onRename: () =>
                  Navigator.of(context).pop('$_menuRenamePrefix${session.id}'),
              onDelete: () =>
                  Navigator.of(context).pop('$_menuDeletePrefix${session.id}'),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  /// 下拉选择结果分发：切换会话 / 弹重命名对话框 / 弹删除确认。
  Future<void> _onSessionMenuSelected(String value) async {
    if (value == _menuNewSession) {
      await ref.read(agentChatNotifierProvider.notifier).newSession();
      return;
    }
    if (value.startsWith(_menuRenamePrefix)) {
      await _renameSessionDialog(value.substring(_menuRenamePrefix.length));
      return;
    }
    if (value.startsWith(_menuDeletePrefix)) {
      await _deleteSessionDialog(value.substring(_menuDeletePrefix.length));
      return;
    }
    if (value.isNotEmpty) {
      await ref.read(agentChatNotifierProvider.notifier).switchSession(value);
    }
  }

  Future<void> _renameSessionDialog(String sessionId) async {
    final l10n = context.l10n;
    final summary = ref
        .read(agentChatNotifierProvider)
        .sessions
        .where((s) => s.id == sessionId)
        .firstOrNull;
    final name = await ThemedInputDialog.show(
      context: context,
      title: l10n.common_rename,
      labelText: l10n.agentChat_renameHint,
      initialValue: (summary == null || summary.name.isEmpty)
          ? null
          : summary.name,
    );
    if (name == null || !mounted) {
      return;
    }
    await ref
        .read(agentChatNotifierProvider.notifier)
        .renameSession(sessionId, name);
  }

  Future<void> _deleteSessionDialog(String sessionId) async {
    final l10n = context.l10n;
    final summary = ref
        .read(agentChatNotifierProvider)
        .sessions
        .where((s) => s.id == sessionId)
        .firstOrNull;
    final confirmed = await ThemedConfirmDialog.showDelete(
      context: context,
      itemName: (summary == null || summary.name.isEmpty)
          ? l10n.agentChat_untitled
          : summary.name,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await ref.read(agentChatNotifierProvider.notifier).deleteSession(sessionId);
  }

  // -------------------------------------------------------------------------
  // 空态欢迎屏（居中图标 + 标题 + 副标题 + 建议 + 能力清单）
  // -------------------------------------------------------------------------

  Widget _buildHero(
    ThemeData theme,
    AppLocalizations l10n,
    AgentChatState state,
  ) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final suggestions = [
      l10n.agentChat_suggestion1,
      l10n.agentChat_suggestion2,
      l10n.agentChat_suggestion3,
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 应用图标 + 标题（窄面板时自动换行居中，不溢出）
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/icons/Icon.png',
                      width: 44,
                      height: 44,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.smart_toy_outlined,
                          size: 26,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    l10n.agentChat_heroTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.agentChat_heroSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // 快捷建议：点击填入输入框（不自动发送，留确认余地）
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final suggestion in suggestions)
                  ActionChip(
                    label: Text(
                      suggestion,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                    tooltip: suggestion,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.25),
                    ),
                    onPressed: () {
                      setState(() => _inputController.text = suggestion);
                      _inputFocus.requestFocus();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupHint(ThemeData theme, AgentChatState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              state.routeError.isEmpty
                  ? context.l10n.agentChat_needSetup
                  : state.routeError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 消息列表
  // -------------------------------------------------------------------------

  Widget _buildMessageList(ThemeData theme, AgentChatState state) {
    // 消息高度由 Markdown、工具结果和图片共同决定。使用完整 Column 参与
    // 布局，避免 ListView.builder 在滚动时重新估算总高度导致滑块忽长忽短。
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final message in state.messages)
            _buildMessageTile(theme, message),
          _buildLiveTile(theme, state),
        ],
      ),
    );
  }

  Uint8List? _bytesForMessageImage(ImageSource source) {
    final cached = _messageImageBytes[source];
    if (cached != null) {
      return cached;
    }
    final encoded = source.base64Data;
    if (encoded == null) {
      return null;
    }
    try {
      final bytes = base64Decode(encoded);
      _messageImageBytes[source] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Size _displaySizeForMessageImage(ImageSource source, Uint8List bytes) {
    final cached = _messageImageSizes[source];
    if (cached != null) {
      return cached;
    }
    const maxWidth = 200.0;
    const maxHeight = 180.0;
    final dimensions = NaiResolutionAdapter.readImageSize(bytes);
    if (dimensions == null || dimensions.$1 <= 0 || dimensions.$2 <= 0) {
      const fallback = Size(160, 120);
      _messageImageSizes[source] = fallback;
      return fallback;
    }
    final widthScale = maxWidth / dimensions.$1;
    final heightScale = maxHeight / dimensions.$2;
    final scale = widthScale < heightScale ? widthScale : heightScale;
    final size = Size(dimensions.$1 * scale, dimensions.$2 * scale);
    _messageImageSizes[source] = size;
    return size;
  }

  Widget _buildUserMessageImage(ThemeData theme, ImageContent image) {
    final source = image.source;
    final bytes = _bytesForMessageImage(source);
    final Size size;
    final Widget imageWidget;
    if (bytes != null) {
      size = _displaySizeForMessageImage(source, bytes);
      imageWidget = Image.memory(
        bytes,
        width: size.width,
        height: size.height,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _buildBrokenMessageImage(theme),
      );
    } else if (source.url case final url?) {
      size = const Size(180, 140);
      imageWidget = Image.network(
        url,
        width: size.width,
        height: size.height,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _buildBrokenMessageImage(theme),
      );
    } else {
      size = const Size(160, 120);
      imageWidget = _buildBrokenMessageImage(theme);
    }
    return SizedBox(
      width: size.width,
      height: size.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageWidget,
      ),
    );
  }

  Widget _buildBrokenMessageImage(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 20,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildMarkdownMessageImage(ThemeData theme, Uri uri, String? alt) {
    Widget image;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') {
      image = Image.network(
        uri.toString(),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _buildBrokenMessageImage(theme),
      );
    } else if (scheme == 'data') {
      try {
        final key = uri.toString();
        final bytes = _markdownDataImageBytes.putIfAbsent(
          key,
          () => uri.data!.contentAsBytes(),
        );
        image = Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _buildBrokenMessageImage(theme),
        );
      } catch (_) {
        image = _buildBrokenMessageImage(theme);
      }
    } else if (scheme == 'resource') {
      image = Image.asset(
        uri.path,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _buildBrokenMessageImage(theme),
      );
    } else {
      try {
        final file = scheme == 'file'
            ? File.fromUri(uri)
            : File(uri.toFilePath(windows: Platform.isWindows));
        image = Image.file(
          file,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _buildBrokenMessageImage(theme),
        );
      } catch (_) {
        image = _buildBrokenMessageImage(theme);
      }
    }
    return Semantics(
      label: alt,
      image: true,
      child: SizedBox(
        width: 320,
        height: 220,
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
      ),
    );
  }

  Widget _buildMessageTile(ThemeData theme, Message message) {
    if (message is UserMessage) {
      final hasText = message.text.trim().isNotEmpty;
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 28),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.images.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: hasText ? 6 : 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      for (final image in message.images)
                        _buildUserMessageImage(theme, image),
                    ],
                  ),
                ),
              if (hasText)
                Text(
                  message.text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (message is AssistantMessage) {
      if (message.text.trim().isEmpty && message.toolCalls.isEmpty) {
        return const SizedBox.shrink();
      }
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10, right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: md.MarkdownBody(
          data: message.text.isEmpty ? ' ' : message.text,
          selectable: true,
          imageBuilder: (uri, _, alt) =>
              _buildMarkdownMessageImage(theme, uri, alt),
          styleSheet: md.MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            code: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.6),
            ),
            codeblockDecoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            blockquoteDecoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }
    if (message is ToolResultMessage) {
      return _ToolResultTile(result: message);
    }
    return const SizedBox.shrink();
  }

  Widget _buildLiveTile(ThemeData theme, AgentChatState state) {
    // 只显示仍在执行的活动；已完成的工具结果固化在消息流中，
    // 这里重复显示会造成“结束后顺序错位/重复”的观感。
    final runningActivities = state.activities
        .where((activity) => activity.status == AgentToolActivityStatus.running)
        .toList();
    final hasActivities = runningActivities.isNotEmpty;
    final hasStreaming = state.streamingText.isNotEmpty;
    final running = state.status == AgentChatRunStatus.running;
    if (!hasActivities && !hasStreaming && !running) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final activity in runningActivities)
          _ToolActivityTile(activity: activity),
        if (hasStreaming)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10, right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              state.streamingText,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        if (running && !hasStreaming && !hasActivities)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.agentChat_thinking,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 错误条
  // -------------------------------------------------------------------------

  Widget _buildErrorBar(ThemeData theme, AgentChatState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              state.error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => state.error.isEmpty
                ? null
                : ref.read(agentChatNotifierProvider.notifier).dismissError(),
            child: Icon(
              Icons.close,
              size: 14,
              color: theme.colorScheme.onErrorContainer.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalBar(
    ThemeData theme,
    AppLocalizations l10n,
    AgentToolApprovalRequest request,
  ) {
    var args = const JsonEncoder.withIndent('  ').convert(request.args);
    if (args.length > 1200) {
      args = '${args.substring(0, 1200)}…';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.45),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gpp_maybe_outlined,
                size: 17,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.agentChat_approvalTitle(request.toolName),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.agentChat_approvalDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer.withValues(
                alpha: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 96),
            padding: const EdgeInsets.all(6),
            color: theme.colorScheme.surface.withValues(alpha: 0.6),
            child: SingleChildScrollView(
              child: SelectableText(
                args,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => ref
                    .read(agentChatNotifierProvider.notifier)
                    .resolveToolApproval(false),
                icon: const Icon(Icons.close, size: 16),
                label: Text(l10n.agentChat_approvalDeny),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: () => ref
                    .read(agentChatNotifierProvider.notifier)
                    .resolveToolApproval(true),
                icon: const Icon(Icons.check, size: 16),
                label: Text(l10n.agentChat_approvalAllow),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 底部输入容器：参考图布局——文本区在上（最小 3 行），控制行在下；
  // 控制行左侧为「+」操作菜单（新会话/重命名/压缩/删除），右侧为
  // 模型选择器与发送/停止按钮。
  // -------------------------------------------------------------------------

  Widget _buildInputContainer(
    ThemeData theme,
    AppLocalizations l10n,
    AgentChatState state,
  ) {
    final running = state.status == AgentChatRunStatus.running;
    final controlsLocked = running || state.sessionTransitioning;
    final canSend =
        state.routeReady && state.initialized && !state.sessionTransitioning;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 文本区：最小 3 行，保证输入主体地位。
            // Enter 发送；Ctrl/Cmd+Enter 换行。两者均截断事件传播，
            // 防止冒泡到全局快捷键（如 Ctrl+Enter 生成）。
            Focus(
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                final key = event.logicalKey;
                if (key != LogicalKeyboardKey.enter &&
                    key != LogicalKeyboardKey.numpadEnter) {
                  return KeyEventResult.ignored;
                }
                if (HardwareKeyboard.instance.isControlPressed ||
                    HardwareKeyboard.instance.isMetaPressed) {
                  _insertNewline();
                  return KeyEventResult.handled;
                }
                if (_inputController.text.trim().isNotEmpty ||
                    _pendingImages.isNotEmpty) {
                  _send();
                }
                return KeyEventResult.handled;
              },
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocus,
                enabled: state.initialized,
                minLines: 3,
                maxLines: 8,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.agentChat_inputHint,
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  border: InputBorder.none,
                ),
              ),
            ),
            // 控制行：附件、「+」操作菜单与权限模式居左；模型选择 + 发送居右
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 8, 6),
              child: Row(
                children: [
                  _buildAttachButton(theme, l10n, state),
                  _buildPlusMenu(theme, l10n, state),
                  const SizedBox(width: 2),
                  _buildPermissionModeButton(theme, l10n, controlsLocked),
                  const SizedBox(width: 2),
                  if (state.queuedCount > 0)
                    Flexible(
                      child: Text(
                        l10n.agentChat_queued,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const Spacer(),
                  _buildModelSelector(theme, l10n, state),
                  const SizedBox(width: 4),
                  _SendButton(
                    running: running,
                    enabled: canSend,
                    onSend: _send,
                    onStop: () =>
                        ref.read(agentChatNotifierProvider.notifier).abort(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 附件按钮：打开本地图片选择器（未初始化时禁用）。
  Widget _buildAttachButton(
    ThemeData theme,
    AppLocalizations l10n,
    AgentChatState state,
  ) {
    final enabled = state.initialized;
    return Tooltip(
      message: l10n.agentChat_attachImage,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: enabled ? _pickImages : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.image_outlined,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(
              alpha: enabled ? 0.65 : 0.25,
            ),
          ),
        ),
      ),
    );
  }

  /// 「+」操作菜单：新会话 / 重命名 / 压缩上下文 / 删除会话。
  Widget _buildPlusMenu(
    ThemeData theme,
    AppLocalizations l10n,
    AgentChatState state,
  ) {
    final actionsEnabled = canManageAgentChatSessions(state);
    return PopupMenuButton<String>(
      tooltip: l10n.agentChat_moreActions,
      onSelected: (action) => _handlePlusAction(action, state),
      itemBuilder: (context) => [
        _plusItem(
          theme,
          value: 'new',
          icon: Icons.add_comment_outlined,
          label: l10n.agentChat_newChat,
          enabled: actionsEnabled,
        ),
        _plusItem(
          theme,
          value: 'rename',
          icon: Icons.edit_outlined,
          label: l10n.common_rename,
          enabled: actionsEnabled,
        ),
        _plusItem(
          theme,
          value: 'compact',
          icon: Icons.compress_outlined,
          label: l10n.agentChat_compact,
          enabled: actionsEnabled,
        ),
        _plusItem(
          theme,
          value: 'delete',
          icon: Icons.delete_outline,
          label: l10n.common_delete,
          enabled: actionsEnabled,
          danger: true,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          Icons.add,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
        ),
      ),
    );
  }

  PopupMenuItem<String> _plusItem(
    ThemeData theme, {
    required String value,
    required IconData icon,
    required String label,
    required bool enabled,
    bool danger = false,
  }) {
    final color = danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface.withValues(alpha: 0.8);
    return PopupMenuItem(
      value: value,
      enabled: enabled,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: enabled ? color : color.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePlusAction(String action, AgentChatState state) async {
    final notifier = ref.read(agentChatNotifierProvider.notifier);
    switch (action) {
      case 'new':
        await notifier.newSession();
      case 'rename':
        await _renameSessionDialog(state.activeSessionId);
      case 'compact':
        await notifier.compactNow();
      case 'delete':
        await _deleteSessionDialog(state.activeSessionId);
    }
  }

  /// 模型选择器：显示当前 chat 模型，菜单按供应商分组列出可用模型。
  Widget _buildModelSelector(
    ThemeData theme,
    AppLocalizations l10n,
    AgentChatState state,
  ) {
    final config = ref.watch(promptAssistantConfigProvider);
    final enabled = config.providers.where((p) => p.enabled).toList();
    if (enabled.isEmpty || !state.routeReady) {
      return Tooltip(
        message: state.routeError.isNotEmpty
            ? state.routeError
            : l10n.agentChat_noModel,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: theme.colorScheme.error.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            Text(
              l10n.agentChat_noModel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      );
    }
    final activeProviderId = config.routing.providerIdFor(
      AssistantTaskType.chat,
    );
    final activeModel = config.routing.modelFor(AssistantTaskType.chat);
    var label = '';
    for (final provider in enabled) {
      if (provider.id != activeProviderId) {
        continue;
      }
      for (final model in config.modelsForProviderTask(
        providerId: provider.id,
        taskType: AssistantTaskType.chat,
      )) {
        if (model.name == activeModel) {
          label = model.displayName;
          break;
        }
      }
      if (label.isNotEmpty) {
        break;
      }
    }
    if (label.isEmpty) {
      label = activeModel.isEmpty ? state.routeLabel : activeModel;
    }
    return PopupMenuButton<(String, String)>(
      enabled: canManageAgentChatSessions(state),
      tooltip: l10n.agentChat_model,
      onSelected: (route) => ref
          .read(agentChatNotifierProvider.notifier)
          .selectChatModel(route.$1, route.$2),
      itemBuilder: (context) => [
        for (final provider in enabled) ...[
          PopupMenuItem<(String, String)>(
            enabled: false,
            height: 30,
            child: Text(
              provider.name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final model
              in config
                  .modelsForProviderTask(
                    providerId: provider.id,
                    taskType: AssistantTaskType.chat,
                  )
                  .where((m) => !m.isPlaceholder))
            PopupMenuItem(
              value: (provider.id, model.name),
              height: 36,
              child: Row(
                children: [
                  if (provider.id == activeProviderId &&
                      model.name == activeModel)
                    Icon(
                      Icons.check,
                      size: 14,
                      color: theme.colorScheme.primary,
                    )
                  else
                    const SizedBox(width: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      model.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        constraints: const BoxConstraints(maxWidth: 140),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.expand_more,
              size: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  /// 上下文压缩进行中提示条（输入容器上方）。
  Widget _buildCompactingBar(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.agentChat_compacting,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// 会话下拉菜单行：勾选态 + 名称 + 时间；悬停时时间替换为重命名/删除按钮。
class _SessionMenuRow extends StatefulWidget {
  const _SessionMenuRow({
    required this.session,
    required this.label,
    required this.active,
    required this.onRename,
    required this.onDelete,
  });

  final AgentChatSessionSummary session;
  final String label;
  final bool active;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<_SessionMenuRow> createState() => _SessionMenuRowState();
}

class _SessionMenuRowState extends State<_SessionMenuRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedTime = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Row(
        children: [
          if (widget.active)
            Icon(Icons.check, size: 14, color: theme.colorScheme.primary)
          else
            const SizedBox(width: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          if (_hovering) ...[
            _MenuIconAction(
              icon: Icons.edit_outlined,
              tooltip: context.l10n.common_rename,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              onTap: widget.onRename,
            ),
            const SizedBox(width: 2),
            _MenuIconAction(
              icon: Icons.delete_outline,
              tooltip: context.l10n.common_delete,
              color: theme.colorScheme.error.withValues(alpha: 0.8),
              onTap: widget.onDelete,
            ),
          ] else
            Text(
              _formatTime(widget.session.updatedAt),
              style: theme.textTheme.labelSmall?.copyWith(color: mutedTime),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final local = time.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.month}/${local.day}';
  }
}

/// 菜单行内的小图标操作按钮（重命名/删除）。
class _MenuIconAction extends StatelessWidget {
  const _MenuIconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

/// 发送/停止按钮：复用项目图标按钮的 hover 风格（InkWell + 圆角 4 +
/// 图标着色），与角色卡操作按钮一致。
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.running,
    required this.enabled,
    required this.onSend,
    required this.onStop,
  });

  final bool running;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final color = running
        ? theme.colorScheme.error
        : enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.3);
    return Tooltip(
      message: running ? l10n.agentChat_stop : l10n.agentChat_send,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: running ? onStop : (enabled ? onSend : null),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            running ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// 待发送图片附件（内存字节，发送时转 base64 内联内容块）。
class _PendingImage {
  const _PendingImage({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
}

/// 将 [imageN] 渲染成文本中的附件 token，并把悬停事件交给面板浮层。
class _AgentChatInputController extends TextEditingController {
  _AgentChatInputController({
    required this.onImageEnter,
    required this.onImageExit,
  });

  static final RegExp imagePattern = RegExp(r'\[image(\d+)\]');

  final void Function(int imageNumber, Offset pointerPosition) onImageEnter;
  final VoidCallback onImageExit;
  int _imageCount = 0;

  set imageCount(int value) {
    if (_imageCount == value) {
      return;
    }
    _imageCount = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final theme = Theme.of(context);
    final tokenStyle = (style ?? const TextStyle()).copyWith(
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.55,
      ),
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
    );
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in imagePattern.allMatches(text)) {
      if (match.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final imageNumber = int.tryParse(match.group(1) ?? '');
      if (imageNumber != null &&
          imageNumber >= 1 &&
          imageNumber <= _imageCount) {
        children.add(
          TextSpan(
            text: match.group(0),
            style: tokenStyle,
            mouseCursor: SystemMouseCursors.click,
            onEnter: (event) => onImageEnter(imageNumber, event.position),
            onExit: (_) => onImageExit(),
          ),
        );
      } else {
        children.add(TextSpan(text: match.group(0)));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }
}

/// 工具活动卡片（运行中/成功/失败）。
class _ToolActivityTile extends StatelessWidget {
  const _ToolActivityTile({required this.activity});

  final AgentToolActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final (icon, color, label) = switch (activity.status) {
      AgentToolActivityStatus.running => (
        Icons.hourglass_top,
        theme.colorScheme.onSurface.withValues(alpha: 0.5),
        l10n.agentChat_toolRunning,
      ),
      AgentToolActivityStatus.succeeded => (
        Icons.check_circle_outline,
        theme.colorScheme.tertiary,
        activity.toolName,
      ),
      AgentToolActivityStatus.failed => (
        Icons.error_outline,
        theme.colorScheme.error,
        activity.toolName,
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label · ${_summarize(activity)}',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _summarize(AgentToolActivity activity) {
    if (activity.status == AgentToolActivityStatus.running) {
      return activity.toolName;
    }
    final text = activity.content.trim();
    if (text.isEmpty) {
      return activity.toolName;
    }
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    return normalized.length <= 60
        ? normalized
        : '${normalized.substring(0, 60)}…';
  }
}

/// 历史中的工具结果条目：工具名 + 可选图片（文件引用，默认大图显示）。
class _ToolResultTile extends StatelessWidget {
  const _ToolResultTile({required this.result});

  final ToolResultMessage result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = _extractImageFiles(result);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isError
                    ? Icons.error_outline
                    : Icons.build_circle_outlined,
                size: 12,
                color: result.isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  result.toolName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final path in files)
                    _ToolResultImage(key: ValueKey(path), path: path),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 提取生成图片的本地文件路径：优先 details（运行中），回退解析
/// 文本 content 里的 JSON 报告（持久化在会话转录中，切换会话后仍可用）。
List<String> _extractImageFiles(ToolResultMessage result) {
  final details = result.details;
  if (details is Map && details['files'] is List) {
    final files = [
      for (final file in details['files'] as List)
        if (file is String) file,
    ];
    if (files.isNotEmpty) {
      return files;
    }
  }
  for (final content in result.content) {
    if (content is! ToolResultTextContent) {
      continue;
    }
    final text = content.text.trim();
    if (!text.startsWith('{')) {
      continue;
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded['images'] is List) {
        return [
          for (final image in decoded['images'] as List)
            if (image is Map && image['file'] is String)
              image['file'] as String,
        ];
      }
    } catch (_) {
      // 非 JSON 文本，跳过。
    }
  }
  return const [];
}

/// 工具结果图片在首帧读取少量文件头来确定比例。解析失败时使用固定的
/// 4:3 比例，不再异步替换占位高度，避免图片解码期间反复改变滚动范围。
class _ToolResultImage extends StatelessWidget {
  const _ToolResultImage({super.key, required this.path});

  static const int _maxHeaderBytes = 64 * 1024;
  static final Map<String, double> _aspectCache = {};

  final String path;

  double _readAspect(File file) {
    final cached = _aspectCache[path];
    if (cached != null) {
      return cached;
    }
    var aspect = 4 / 3;
    RandomAccessFile? handle;
    try {
      final length = file.lengthSync();
      final headerLength = length < _maxHeaderBytes ? length : _maxHeaderBytes;
      handle = file.openSync();
      final dimensions = NaiResolutionAdapter.readImageSize(
        handle.readSync(headerLength),
      );
      if (dimensions != null && dimensions.$1 > 0 && dimensions.$2 > 0) {
        aspect = dimensions.$1 / dimensions.$2;
      }
    } catch (_) {
      // 文件损坏或格式无法从头部识别时保留稳定的 4:3 占位比例。
    } finally {
      handle?.closeSync();
    }
    _aspectCache[path] = aspect;
    return aspect;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(path);
    if (!file.existsSync()) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '找不到图片：$path',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
          child: AspectRatio(
            aspectRatio: _readAspect(file),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    '找不到图片：$path',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
