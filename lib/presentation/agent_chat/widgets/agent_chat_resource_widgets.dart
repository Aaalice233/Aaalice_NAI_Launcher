import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/services/gallery/local_gallery_service.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/local_gallery_provider.dart';
import '../../providers/precise_ref_library_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../providers/vibe_library_provider.dart';
import '../services/agent_resource_resolver.dart';
import 'agent_chat_panel_controller.dart';

/// Displays every tool-produced attachment while leaving vertical scrolling to
/// the transcript. Multiple images use a responsive thumbnail grid so a large
/// generation batch remains compact without introducing a competing viewport.
class AgentChatResourceGallery extends StatelessWidget {
  const AgentChatResourceGallery({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final int columns = children.length == 1
            ? 1
            : (availableWidth / 220).floor().clamp(2, 3).toInt();
        final double itemWidth =
            (availableWidth - spacing * (columns - 1)) / columns;
        return Container(
          key: const ValueKey('agent-chat-resource-gallery'),
          margin: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final child in children)
                SizedBox(width: itemWidth, child: child),
            ],
          ),
        );
      },
    );
  }
}

class AgentChatPendingImageCard extends StatelessWidget {
  const AgentChatPendingImageCard({
    super.key,
    required this.image,
    required this.onRemove,
    required this.touchOptimized,
  });

  final PendingAgentChatImage image;
  final VoidCallback onRemove;
  final bool touchOptimized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('agent-chat-pending-image-card'),
      width: touchOptimized ? 190 : 220,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.memory(
              image.bytes,
              width: touchOptimized ? 42 : 34,
              height: touchOptimized ? 42 : 34,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => SizedBox.square(
                dimension: touchOptimized ? 42 : 34,
                child: const Icon(Icons.broken_image_outlined, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(image.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
                Text(
                  _formatBytes(image.bytes.length),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
            constraints: BoxConstraints.tightFor(
              width: touchOptimized ? 40 : 30,
              height: touchOptimized ? 40 : 30,
            ),
          ),
        ],
      ),
    );
  }
}

class AgentChatPendingResourceCard extends StatefulWidget {
  const AgentChatPendingResourceCard({
    super.key,
    required this.reference,
    required this.loadPreview,
    required this.unavailable,
    required this.onRemove,
    required this.touchOptimized,
  });

  final AgentChatResourceReference reference;
  final Future<ResolvedAgentResource?> Function() loadPreview;
  final bool unavailable;
  final VoidCallback onRemove;
  final bool touchOptimized;

  @override
  State<AgentChatPendingResourceCard> createState() =>
      _AgentChatPendingResourceCardState();
}

class _AgentChatPendingResourceCardState
    extends State<AgentChatPendingResourceCard> {
  late Future<ResolvedAgentResource?> _preview;

  @override
  void initState() {
    super.initState();
    _preview = widget.loadPreview();
  }

  @override
  void didUpdateWidget(covariant AgentChatPendingResourceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference) {
      _preview = widget.loadPreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        widget.reference.display['name'] ??
        widget.reference.display['title'] ??
        context.l10n.agentChat_reference;
    return Container(
      key: const ValueKey('agent-chat-pending-resource-card'),
      width: widget.touchOptimized ? 210 : 240,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.unavailable
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.55)
            : theme.colorScheme.secondaryContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          FutureBuilder<ResolvedAgentResource?>(
            future: _preview,
            builder: (context, snapshot) {
              final bytes = snapshot.data?.bytes;
              if (bytes != null && bytes.isNotEmpty) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.memory(
                    bytes,
                    width: widget.touchOptimized ? 42 : 34,
                    height: widget.touchOptimized ? 42 : 34,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => SizedBox.square(
                      dimension: widget.touchOptimized ? 42 : 34,
                      child: const Icon(Icons.broken_image_outlined, size: 18),
                    ),
                  ),
                );
              }
              return SizedBox.square(
                dimension: widget.touchOptimized ? 42 : 34,
                child: Icon(
                  widget.unavailable
                      ? Icons.link_off_outlined
                      : _kindIcon(widget.reference.kind),
                  size: 18,
                  color: widget.unavailable
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSecondaryContainer,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.unavailable
                  ? '$label · ${context.l10n.agentChat_resourceUnavailable}'
                  : label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close, size: 16),
            constraints: BoxConstraints.tightFor(
              width: widget.touchOptimized ? 40 : 30,
              height: widget.touchOptimized ? 40 : 30,
            ),
          ),
        ],
      ),
    );
  }
}

class AgentChatSentResourceCard extends StatefulWidget {
  const AgentChatSentResourceCard({
    super.key,
    required this.reference,
    required this.loadPreview,
    required this.touchOptimized,
  });

  final AgentChatResourceReference reference;
  final Future<ResolvedAgentResource?> Function() loadPreview;
  final bool touchOptimized;

  @override
  State<AgentChatSentResourceCard> createState() =>
      _AgentChatSentResourceCardState();
}

class _AgentChatSentResourceCardState extends State<AgentChatSentResourceCard> {
  late Future<ResolvedAgentResource?> _preview;

  @override
  void initState() {
    super.initState();
    _preview = widget.loadPreview();
  }

  @override
  void didUpdateWidget(covariant AgentChatSentResourceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference) {
      _preview = widget.loadPreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackLabel =
        widget.reference.display['name'] ??
        widget.reference.display['title'] ??
        context.l10n.agentChat_reference;
    final dimension = widget.touchOptimized ? 24.0 : 21.0;
    return FutureBuilder<ResolvedAgentResource?>(
      future: _preview,
      builder: (context, snapshot) {
        final preview = snapshot.data;
        final resolvedLabel = preview?.label.trim();
        final label = fallbackLabel.trim().isNotEmpty
            ? fallbackLabel
            : resolvedLabel == null || resolvedLabel.isEmpty
            ? widget.reference.resourceId
            : resolvedLabel;
        final unavailable =
            snapshot.connectionState == ConnectionState.done &&
            (snapshot.hasError || preview == null);
        final bytes = preview?.bytes;
        return Semantics(
          label: '${context.l10n.agentChat_reference}: $label',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Container(
              height: widget.touchOptimized ? 30 : 27,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.72,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bytes != null && bytes.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.memory(
                        bytes,
                        width: dimension,
                        height: dimension,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => SizedBox.square(
                          dimension: dimension,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox.square(
                      dimension: dimension,
                      child: Icon(
                        unavailable
                            ? Icons.link_off_outlined
                            : _kindIcon(widget.reference.kind),
                        size: 14,
                        color: unavailable
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Tooltip(
                      message: label,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

abstract final class AgentChatResourcePicker {
  static Future<void> showReferenceGallery({
    required BuildContext context,
    required WidgetRef ref,
    required Future<void> Function(AgentChatResourceReference) onSelected,
  }) => _show(
    context,
    _AgentChatResourcePickerBody(
      mode: _PickerMode.gallery,
      onSelected: onSelected,
    ),
  );

  static Future<void> showResourceLibrary({
    required BuildContext context,
    required WidgetRef ref,
    required Future<void> Function(AgentChatResourceReference) onSelected,
  }) async {
    await Future.wait([
      ref.read(vibeLibraryNotifierProvider.notifier).initialize(),
      ref.read(preciseRefLibraryNotifierProvider.notifier).initialize(),
    ]);
    if (!context.mounted) return;
    await _show(
      context,
      _AgentChatResourcePickerBody(
        mode: _PickerMode.library,
        onSelected: onSelected,
      ),
    );
  }

  static Future<void> _show(BuildContext context, Widget child) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    if (compact) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: child,
          ),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
          child: child,
        ),
      ),
    );
  }
}

enum _PickerMode { gallery, library }

class _AgentChatResourcePickerBody extends ConsumerStatefulWidget {
  const _AgentChatResourcePickerBody({
    required this.mode,
    required this.onSelected,
  });

  final _PickerMode mode;
  final Future<void> Function(AgentChatResourceReference) onSelected;

  @override
  ConsumerState<_AgentChatResourcePickerBody> createState() =>
      _AgentChatResourcePickerBodyState();
}

class _AgentChatResourcePickerBodyState
    extends ConsumerState<_AgentChatResourcePickerBody> {
  static const _localPageSize = 50;

  final _searchController = TextEditingController();
  final _localScrollController = ScrollController();
  Timer? _searchDebounce;
  LocalGalleryService? _localGalleryService;
  List<LocalImageRecord> _localRecords = const [];
  Object? _localError;
  var _tab = 0;
  var _adding = false;
  var _query = '';
  var _localPage = -1;
  var _localHasMore = true;
  var _localLoading = false;
  var _localRequestSerial = 0;

  bool get _isLocalGalleryTab =>
      widget.mode == _PickerMode.gallery && _tab == 1;

  @override
  void initState() {
    super.initState();
    _localScrollController.addListener(_handleLocalScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _localRequestSerial++;
    _localScrollController
      ..removeListener(_handleLocalScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tabs = widget.mode == _PickerMode.gallery
        ? [l10n.agentChat_generationHistory, l10n.agentChat_localGallery]
        : [
            l10n.agentChat_tagLibrary,
            l10n.agentChat_vibeLibrary,
            l10n.agentChat_preciseRefLibrary,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.mode == _PickerMode.gallery
                      ? l10n.agentChat_referenceGallery
                      : l10n.agentChat_resourceLibrary,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SegmentedButton<int>(
            segments: [
              for (var index = 0; index < tabs.length; index++)
                ButtonSegment(value: index, label: Text(tabs[index])),
            ],
            selected: {_tab},
            onSelectionChanged: (value) => _setTab(value.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            key: const ValueKey('agent-chat-resource-search'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: _setQuery,
            decoration: InputDecoration(
              hintText: l10n.common_search,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      onPressed: () {
                        _searchController.clear();
                        _setQuery('');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildItems()),
      ],
    );
  }

  Widget _buildItems() {
    if (widget.mode == _PickerMode.gallery) {
      if (_tab == 0) {
        final generatedImageLabel = context.l10n.agentChat_generatedImage;
        final images = ref
            .watch(imageGenerationNotifierProvider)
            .mergedPanelImages
            .where(
              (image) =>
                  image.kind == GeneratedImageKind.completed &&
                  _matchesQuery([
                    generatedImageLabel,
                    image.id,
                    '${image.width} × ${image.height}',
                  ]),
            )
            .toList(growable: false);
        return _list(
          images.map(
            (image) => _PickerItem(
              key: ValueKey('agent-chat-gallery-${image.id}'),
              imageBytes: image.bytes,
              title: context.l10n.agentChat_generatedImage,
              subtitle: '${image.width} × ${image.height}',
              onTap: () => _select(
                AgentChatResourceReference(
                  kind: AgentChatResourceKind.generatedImage,
                  source: 'generation_history',
                  resourceId: image.id,
                  display: {'name': context.l10n.agentChat_generatedImage},
                ),
              ),
            ),
          ),
        );
      }
      return _buildLocalGallery();
    }

    if (_tab == 0) {
      final entries = ref
          .watch(tagLibraryPageNotifierProvider)
          .filteredEntries
          .where(
            (entry) => _matchesQuery([entry.displayName, entry.contentPreview]),
          );
      return _list(
        entries.map(
          (entry) => _PickerItem(
            key: ValueKey('agent-chat-tag-${entry.id}'),
            imageFile: entry.hasThumbnail ? File(entry.thumbnail!) : null,
            title: entry.displayName,
            subtitle: entry.contentPreview,
            onTap: () => _select(
              AgentChatResourceReference(
                kind: AgentChatResourceKind.tagLibraryEntry,
                source: 'tag_library',
                resourceId: entry.id,
                display: {'name': entry.displayName},
              ),
            ),
          ),
        ),
      );
    }
    if (_tab == 1) {
      final entries = ref
          .watch(vibeLibraryNotifierProvider)
          .filteredEntries
          .where((entry) => _matchesQuery([entry.displayName]));
      return _list(
        entries.map(
          (entry) => _PickerItem(
            key: ValueKey('agent-chat-vibe-${entry.id}'),
            imageBytes:
                entry.thumbnail ?? entry.vibeThumbnail ?? entry.rawImageData,
            title: entry.displayName,
            subtitle: context.l10n.agentChat_vibeLibrary,
            onTap: () => _select(
              AgentChatResourceReference(
                kind: AgentChatResourceKind.vibeLibraryEntry,
                source: 'vibe_library',
                resourceId: entry.id,
                display: {'name': entry.displayName},
              ),
            ),
          ),
        ),
      );
    }
    final entries = ref
        .watch(preciseRefLibraryNotifierProvider)
        .filteredEntries
        .where((entry) => _matchesQuery([entry.name, entry.type.name]));
    return _list(
      entries.map(
        (entry) => _PickerItem(
          key: ValueKey('agent-chat-precise-${entry.id}'),
          imageFile: File(entry.imagePath),
          title: entry.name,
          subtitle: entry.type.name,
          onTap: () => _select(
            AgentChatResourceReference(
              kind: AgentChatResourceKind.preciseRefLibraryEntry,
              source: 'precise_reference_library',
              resourceId: entry.id,
              display: {'name': entry.name},
            ),
          ),
        ),
      ),
    );
  }

  void _setTab(int tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    if (_isLocalGalleryTab && _localPage < 0 && !_localLoading) {
      unawaited(_loadLocalGallery(reset: true));
    }
  }

  void _setQuery(String value) {
    final query = value.trim();
    setState(() => _query = query);
    _searchDebounce?.cancel();
    if (_isLocalGalleryTab) {
      _searchDebounce = Timer(
        const Duration(milliseconds: 250),
        () => unawaited(_loadLocalGallery(reset: true)),
      );
    }
  }

  void _handleLocalScroll() {
    if (!_isLocalGalleryTab ||
        !_localScrollController.hasClients ||
        _localLoading ||
        _localError != null ||
        !_localHasMore) {
      return;
    }
    if (_localScrollController.position.extentAfter < 180) {
      unawaited(_loadLocalGallery());
    }
  }

  Widget _buildLocalGallery() {
    if (_localPage < 0 && !_localLoading && _localError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isLocalGalleryTab && _localPage < 0) {
          unawaited(_loadLocalGallery(reset: true));
        }
      });
    }

    if (_localLoading && _localRecords.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_localError != null && _localRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${context.l10n.common_error}: $_localError',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => unawaited(_loadLocalGallery(reset: true)),
                child: Text(context.l10n.common_retry),
              ),
            ],
          ),
        ),
      );
    }
    if (_localRecords.isEmpty) {
      return Center(child: Text(context.l10n.agentChat_noResources));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_isLocalGalleryTab ||
          !_localScrollController.hasClients ||
          _localLoading ||
          _localError != null ||
          !_localHasMore) {
        return;
      }
      if (_localScrollController.position.extentAfter < 180) {
        unawaited(_loadLocalGallery());
      }
    });

    return ListView.separated(
      key: const ValueKey('agent-chat-local-gallery-list'),
      controller: _localScrollController,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount:
          _localRecords.length + (_localLoading || _localError != null ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        if (index == _localRecords.length) {
          if (_localError != null) {
            return Center(
              child: TextButton.icon(
                onPressed: () => unawaited(_loadLocalGallery()),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.common_retry),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final record = _localRecords[index];
        return _PickerItem(
          key: ValueKey('agent-chat-local-${record.path}'),
          imageFile: File(record.path),
          title: p.basename(record.path),
          subtitle: _formatBytes(record.size),
          onTap: () => _selectLocalRecord(record),
        );
      },
    );
  }

  Future<void> _loadLocalGallery({bool reset = false}) async {
    if (_localLoading && !reset) return;
    final requestSerial = ++_localRequestSerial;
    final requestedQuery = _query;
    final requestedPage = reset ? 0 : _localPage + 1;
    setState(() {
      _localLoading = true;
      _localError = null;
      if (reset) {
        _localRecords = const [];
        _localPage = -1;
        _localHasMore = true;
      }
    });

    try {
      var service = _localGalleryService;
      if (service == null) {
        final notifier = ref.read(localGalleryNotifierProvider.notifier);
        await notifier.initialize();
        if (!mounted || requestSerial != _localRequestSerial) return;
        final galleryState = ref.read(localGalleryNotifierProvider);
        if (galleryState.error case final error?) {
          throw StateError(error.details ?? error.code.name);
        }
        service = await notifier.getService();
        _localGalleryService = service;
      }
      final result = await service.queryPage(
        page: requestedPage,
        pageSize: _localPageSize,
        searchQuery: requestedQuery,
      );
      if (!mounted || requestSerial != _localRequestSerial) return;

      final nextRecords = reset
          ? result.records
          : <LocalImageRecord>[
              ..._localRecords,
              ...result.records.where(
                (candidate) => !_localRecords.any(
                  (record) => record.path == candidate.path,
                ),
              ),
            ];
      setState(() {
        _localRecords = nextRecords;
        _localPage = result.page;
        _localHasMore = result.hasMore;
        _localLoading = false;
      });
    } on Object catch (error) {
      if (!mounted || requestSerial != _localRequestSerial) return;
      setState(() {
        _localError = error;
        _localLoading = false;
      });
    }
  }

  Future<void> _selectLocalRecord(LocalImageRecord record) async {
    if (_adding) return;
    final unavailableMessage = context.l10n.agentChat_resourceUnavailable;
    setState(() => _adding = true);
    try {
      final notifier = ref.read(localGalleryNotifierProvider.notifier);
      final service = _localGalleryService ??= await notifier.getService();
      final id = await service.getImageIdByPath(record.path);
      if (id == null) {
        throw StateError(unavailableMessage);
      }
      await widget.onSelected(
        AgentChatResourceReference(
          kind: AgentChatResourceKind.localGalleryImage,
          source: 'local_gallery',
          resourceId: '$id',
          display: {'name': p.basename(record.path)},
        ),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(context.l10n.agentChat_addResourceFailed('$error')),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  bool _matchesQuery(Iterable<String> values) {
    final query = _query.toLowerCase();
    if (query.isEmpty) return true;
    return values.any((value) => value.toLowerCase().contains(query));
  }

  Widget _list(Iterable<Widget> items) {
    final children = items.toList(growable: false);
    if (children.isEmpty) {
      return Center(child: Text(context.l10n.agentChat_noResources));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, index) => children[index],
    );
  }

  Future<void> _select(AgentChatResourceReference reference) async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      await widget.onSelected(reference);
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(context.l10n.agentChat_addResourceFailed('$error')),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }
}

class _PickerItem extends StatelessWidget {
  const _PickerItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.imageBytes,
    this.imageFile,
  });

  final String title;
  final String subtitle;
  final Future<void> Function() onTap;
  final Uint8List? imageBytes;
  final File? imageFile;

  @override
  Widget build(BuildContext context) {
    final preview = imageBytes != null
        ? Image.memory(imageBytes!, fit: BoxFit.cover)
        : imageFile != null && imageFile!.existsSync()
        ? Image.file(imageFile!, fit: BoxFit.cover)
        : const Icon(Icons.bookmark_outline_rounded);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: SizedBox.square(dimension: 44, child: preview),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.add_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _kindIcon(AgentChatResourceKind kind) => switch (kind) {
  AgentChatResourceKind.generatedImage ||
  AgentChatResourceKind.localGalleryImage ||
  AgentChatResourceKind.onlineGalleryMedia ||
  AgentChatResourceKind.inpaintDraft => Icons.image_outlined,
  AgentChatResourceKind.vibeLibraryEntry => Icons.auto_awesome_outlined,
  AgentChatResourceKind.preciseRefLibraryEntry => Icons.center_focus_strong,
  AgentChatResourceKind.fixedTag ||
  AgentChatResourceKind.tagLibraryEntry => Icons.bookmark_outline_rounded,
};

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
