// 工具结果里落盘图片的预览卡片：文件探测与宽高读取都在 build 之外完成。

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/utils/lru_cache.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/mosaic_settings_provider.dart';
import '../../providers/watermark_settings_provider.dart';
import '../../services/image_send_action_dispatcher.dart';
import '../../utils/image_detail_opener.dart';
import '../../widgets/common/image_card_context_menu.dart';
import '../../widgets/common/image_card_hover_motion.dart';
import '../../widgets/common/image_detail/file_image_detail_data.dart';
import '../../widgets/gallery/draggable_image_card.dart';
import '../../widgets/gallery/local_image_context_menu.dart';

// 宽高比按路径命中；固定上限避免长会话里无界增长
@visibleForTesting
final LRUCache<String, double> agentChatToolResultAspectCache = LRUCache(
  maxSize: 256,
);

const Map<String, Object> _agentChatImageDragLocalData = {
  'source': 'agent_chat_internal',
};

const BoxConstraints _cardConstraints = BoxConstraints(
  maxWidth: 320,
  maxHeight: 320,
);

const double _fallbackAspect = 4 / 3;
const int _maxHeaderBytes = 64 * 1024;

class AgentChatToolResultImageInfo {
  const AgentChatToolResultImageInfo({
    required this.record,
    required this.aspect,
  });

  final LocalImageRecord record;
  final double aspect;
}

typedef AgentChatToolResultImageResolver =
    Future<AgentChatToolResultImageInfo?> Function(String path);

/// 文件不存在时返回 null；宽高比优先命中缓存，未命中才读文件头。
Future<AgentChatToolResultImageInfo?> resolveAgentChatToolResultImage(
  String path,
) async {
  final file = File(path);
  final stat = await file.stat();
  if (stat.type != FileSystemEntityType.file) return null;
  final aspect =
      agentChatToolResultAspectCache.get(path) ??
      await _readAspect(file, stat.size);
  agentChatToolResultAspectCache.put(path, aspect);
  return AgentChatToolResultImageInfo(
    record: LocalImageRecord(
      path: path,
      size: stat.size,
      modifiedAt: stat.modified,
    ),
    aspect: aspect,
  );
}

// widget test 的 fake async 推不动真实磁盘 IO，探测入口留成可替换的
@visibleForTesting
AgentChatToolResultImageResolver agentChatToolResultImageResolver =
    resolveAgentChatToolResultImage;

Future<double> _readAspect(File file, int length) async {
  RandomAccessFile? handle;
  try {
    handle = await file.open();
    final headerLength = length < _maxHeaderBytes ? length : _maxHeaderBytes;
    final dimensions = NaiResolutionAdapter.readImageSize(
      await handle.read(headerLength),
    );
    if (dimensions != null && dimensions.$1 > 0 && dimensions.$2 > 0) {
      return dimensions.$1 / dimensions.$2;
    }
  } catch (_) {
    // Keep a stable placeholder ratio for damaged or unsupported files.
  } finally {
    await handle?.close();
  }
  return _fallbackAspect;
}

Future<void> _showAgentChatImageSendMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Offset position,
  required String fileName,
  required Future<List<int>> Function() loadBytes,
}) async {
  var isKritaConnected = false;
  try {
    isKritaConnected =
        ref.read(kritaBridgeNotifierProvider).status ==
        KritaBridgeStatus.connected;
  } catch (_) {
    // The remaining image actions stay available during service restoration.
  }
  final watermarkEnabled = ref.read(
    watermarkSettingsProvider.select((state) => state.configuration.enabled),
  );
  final mosaicEnabled = ref.read(
    mosaicSettingsProvider.select((state) => state.configuration.enabled),
  );
  await ImageCardContextMenu.show(
    context: context,
    position: position,
    actions: LocalImageContextMenu.buildSendActions(
      context,
      isKritaConnected: isKritaConnected,
      watermarkEnabled: watermarkEnabled,
      mosaicEnabled: mosaicEnabled,
      onAction: (action) => ImageSendActionDispatcher.handle(
        context: context,
        ref: ref,
        action: action,
        fileName: fileName,
        loadBytes: () async => Uint8List.fromList(await loadBytes()),
      ),
    ),
  );
}

class AgentChatToolResultFileImage extends ConsumerStatefulWidget {
  const AgentChatToolResultFileImage({super.key, required this.path});

  final String path;

  @override
  ConsumerState<AgentChatToolResultFileImage> createState() =>
      _AgentChatToolResultFileImageState();
}

class _AgentChatToolResultFileImageState
    extends ConsumerState<AgentChatToolResultFileImage> {
  bool _isHovering = false;
  bool _missingFile = false;
  int _probeGeneration = 0;
  late LocalImageRecord _record;
  late double _aspect;

  @override
  void initState() {
    super.initState();
    _resetForPath();
    unawaited(_probe());
  }

  @override
  void didUpdateWidget(covariant AgentChatToolResultFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path == widget.path) return;
    _resetForPath();
    unawaited(_probe());
  }

  // 首帧就挂出卡片，size/modifiedAt 等 stat 回填；拖拽链路只消费 record.path
  void _resetForPath() {
    _missingFile = false;
    _aspect =
        agentChatToolResultAspectCache.get(widget.path) ?? _fallbackAspect;
    _record = LocalImageRecord(
      path: widget.path,
      size: 0,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Future<void> _probe() async {
    final generation = ++_probeGeneration;
    final info = await agentChatToolResultImageResolver(widget.path);
    if (!mounted || generation != _probeGeneration) return;
    setState(() {
      if (info == null) {
        _missingFile = true;
        return;
      }
      _record = info.record;
      _aspect = info.aspect;
    });
  }

  void _openDetail() {
    ImageDetailOpener.showSingleImmediate(
      context,
      image: FileImageDetailData(filePath: widget.path),
      showMetadataPanel: true,
    );
  }

  void _showSendMenu(TapUpDetails details) {
    unawaited(
      _showAgentChatImageSendMenu(
        context: context,
        ref: ref,
        position: details.globalPosition,
        fileName: widget.path.split(RegExp(r'[/\\]')).last,
        loadBytes: () => File(widget.path).readAsBytes(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_missingFile) return _missing(theme);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: _cardConstraints,
          child: DraggableImageCard(
            record: _record,
            localData: _agentChatImageDragLocalData,
            feedbackWidth: 240,
            child: AspectRatio(
              aspectRatio: _aspect,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isHovering = true),
                onExit: (_) => setState(() => _isHovering = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openDetail,
                  onSecondaryTapUp: _showSendMenu,
                  child: ImageCardHoverMotion(
                    hovered: _isHovering,
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      foregroundDecoration: BoxDecoration(
                        color: _isHovering
                            ? theme.colorScheme.primary.withValues(alpha: 0.07)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(widget.path),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => _missing(theme),
                        ),
                      ),
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

  Widget _missing(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      '找不到图片：${widget.path}',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    ),
  );
}
