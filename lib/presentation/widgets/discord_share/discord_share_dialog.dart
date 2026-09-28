import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../common/image_viewport_surface.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../../data/services/discord_share_service.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/content_sized_adaptive_form.dart';
import '../../utils/asset_protection_guard.dart';
import 'discord_share_error.dart';
import '../../providers/discord_share_task_provider.dart';

class DiscordShareDialog extends ConsumerStatefulWidget {
  const DiscordShareDialog({
    super.key,
    required this.imageBytes,
    required this.fileName,
    required this.metadata,
    this.width,
    this.height,
    this.scrollController,
  });

  final Uint8List imageBytes;
  final String fileName;
  final NaiImageMetadata? metadata;
  final int? width;
  final int? height;
  final ScrollController? scrollController;

  static Future<bool?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    required String fileName,
    NaiImageMetadata? metadata,
    int? width,
    int? height,
  }) {
    return AdaptivePresenter.showForm<bool>(
      context: context,
      barrierDismissible: false,
      dialogWidth: 920,
      titleBuilder: (panelContext) => Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF5865F2).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Color(0xFF5865F2),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  panelContext.l10n.discordShare_title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    panelContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (MediaQuery.textScalerOf(panelContext).scale(1) < 2) ...[
                  const SizedBox(height: 2),
                  Text(
                    panelContext.l10n.discordShare_subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(panelContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        panelContext,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      builder: (panelContext, scrollController) => DiscordShareDialog(
        imageBytes: imageBytes,
        fileName: fileName,
        metadata: metadata,
        width: width,
        height: height,
        scrollController: scrollController,
      ),
    );
  }

  @override
  ConsumerState<DiscordShareDialog> createState() => _DiscordShareDialogState();
}

class _DiscordShareDialogState extends ConsumerState<DiscordShareDialog> {
  final _captionController = TextEditingController();
  final _promptController = TextEditingController();

  DiscordShareSession? _session;
  List<DiscordShareTarget> _targets = const [];
  Set<String> _selectedTargets = {};
  bool _initializing = true;
  bool _authenticating = false;
  bool _sending = false;
  bool _joinRequired = false;
  bool _includeMetadata = false;
  bool _longPromptAsFile = true;
  Object? _error;
  CancelToken? _authenticationCancelToken;
  Future<void> _preferenceWrite = Future<void>.value();
  Timer? _rateLimitTimer;
  Stopwatch? _rateLimitStopwatch;
  Duration? _rateLimitDuration;

  late final Map<_PromptCategory, String> _categoryContent;
  late final Set<_PromptCategory> _preferredCategories;
  late final Set<_PromptCategory> _selectedCategories;

  @override
  void initState() {
    super.initState();
    _categoryContent = _buildCategoryContent(widget.metadata);
    final savedCategoryIds = ref
        .read(discordShareServiceProvider)
        .loadPromptCategoryIds();
    _preferredCategories = savedCategoryIds == null
        ? {_PromptCategory.main, _PromptCategory.characters}
        : _PromptCategory.values
              .where((category) => savedCategoryIds.contains(category.name))
              .toSet();
    _selectedCategories = _preferredCategories
        .where((category) => _categoryContent[category]?.isNotEmpty == true)
        .toSet();
    _rebuildPrompt();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _authenticationCancelToken?.cancel('Discord share dialog closed');
    _rateLimitTimer?.cancel();
    _captionController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final service = ref.read(discordShareServiceProvider);
    _includeMetadata = service.loadIncludeMetadataPreference();
    _longPromptAsFile = service.loadLongPromptAsFilePreference();
    try {
      final saved = await service.loadSession();
      if (saved == null) {
        if (mounted) setState(() => _initializing = false);
        return;
      }
      final session = await service.verifySession(saved);
      final targets = await service.loadTargets(session);
      if (!mounted) return;
      setState(() {
        _session = session;
        _targets = targets;
        _selectedTargets = service.loadSelectedTargetIds(targets);
        _initializing = false;
      });
    } on DiscordShareException catch (error) {
      if (!mounted) return;
      setState(() {
        _joinRequired = error.isNotMember;
        _error = error.isUnauthorized || error.isNotMember ? null : error;
        _initializing = false;
      });
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to initialize Discord sharing',
        error,
        stackTrace,
        'DiscordShare',
      );
      if (!mounted) return;
      setState(() {
        _error = error;
        _initializing = false;
      });
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _joinRequired = false;
      _error = null;
    });
    final service = ref.read(discordShareServiceProvider);
    final cancelToken = CancelToken();
    _authenticationCancelToken = cancelToken;
    try {
      final session = await service.authenticate(cancelToken: cancelToken);
      final targets = await service.loadTargets(session);
      if (!mounted) return;
      setState(() {
        _session = session;
        _targets = targets;
        _selectedTargets = service.loadSelectedTargetIds(targets);
      });
    } on DiscordShareException catch (error) {
      if (!mounted) return;
      setState(() {
        _joinRequired = error.isNotMember;
        _error = error.isNotMember ? null : error;
      });
    } catch (error, stackTrace) {
      AppLogger.e(
        'Discord verification failed',
        error,
        stackTrace,
        'DiscordShare',
      );
      if (mounted) setState(() => _error = error);
    } finally {
      if (identical(_authenticationCancelToken, cancelToken)) {
        _authenticationCancelToken = null;
      }
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _disconnect() async {
    await ref.read(discordShareServiceProvider).clearSession();
    if (!mounted) return;
    setState(() {
      _session = null;
      _targets = const [];
      _selectedTargets = {};
      _joinRequired = false;
      _error = null;
    });
  }

  Future<void> _openCommunity() async {
    await launchUrl(
      Uri.parse(discordCommunityUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  void _toggleCategory(_PromptCategory category, bool selected) {
    setState(() {
      if (selected) {
        _preferredCategories.add(category);
        _selectedCategories.add(category);
      } else {
        _preferredCategories.remove(category);
        _selectedCategories.remove(category);
      }
      _rebuildPrompt();
    });
    _persistPreferences();
  }

  void _toggleTarget(String targetId, bool selected) {
    setState(() {
      if (selected) {
        _selectedTargets.add(targetId);
      } else {
        _selectedTargets.remove(targetId);
      }
    });
    _persistPreferences();
  }

  void _setIncludeMetadata(bool value) {
    setState(() => _includeMetadata = value);
    _persistPreferences();
  }

  void _persistPreferences() {
    final service = ref.read(discordShareServiceProvider);
    final targetIds = Set<String>.of(_selectedTargets);
    final categoryIds = _preferredCategories
        .map((category) => category.name)
        .toSet();
    final includeMetadata = _includeMetadata;
    final longPromptAsFile = _longPromptAsFile;
    final previousWrite = _preferenceWrite;
    _preferenceWrite = () async {
      await previousWrite;
      try {
        await service.savePreferences(
          targetIds: targetIds,
          promptCategoryIds: categoryIds,
          includeMetadata: includeMetadata,
          longPromptAsFile: longPromptAsFile,
        );
      } catch (error, stackTrace) {
        AppLogger.e(
          'Failed to persist Discord share preferences',
          error,
          stackTrace,
          'DiscordShare',
        );
      }
    }();
  }

  void _rebuildPrompt() {
    final metadata = widget.metadata;
    if (metadata == null) {
      _promptController.clear();
      return;
    }
    _promptController.text = metadata.buildPositivePromptSelection(
      includeMainPrompt: _selectedCategories.contains(_PromptCategory.main),
      includeCharacterPrompts: _selectedCategories.contains(
        _PromptCategory.characters,
      ),
      includeQualityTags: _selectedCategories.contains(_PromptCategory.quality),
      includeFixedTags: _selectedCategories.contains(_PromptCategory.fixed),
    );
  }

  Future<void> _send() async {
    final session = _session;
    if (session == null ||
        _selectedTargets.isEmpty ||
        _sending ||
        _rateLimitSecondsRemaining > 0) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final confirmed = await AssetProtectionGuard.confirmExternalImageSend(
        context: context,
        ref: ref,
        targetName: 'Discord',
      );
      if (!confirmed || !mounted) return;

      _persistPreferences();
      await _preferenceWrite;
      if (!mounted) return;
      ref
          .read(discordShareTaskProvider.notifier)
          .submit(
            DiscordShareSubmission(
              session: session,
              bytes: widget.imageBytes,
              fileName: widget.fileName,
              stripMetadata: !_includeMetadata,
              targetIds: _selectedTargets,
              prompt: _promptController.text,
              caption: _captionController.text,
              width: widget.width ?? widget.metadata?.width,
              height: widget.height ?? widget.metadata?.height,
              longPromptAsFile: _longPromptAsFile,
            ),
          );
      Navigator.of(context).pop(true);
    } on DiscordShareException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized || error.isNotMember) {
        setState(() {
          _session = null;
          _targets = const [];
          _selectedTargets = {};
          _joinRequired = error.isNotMember;
          _error = error.isNotMember ? null : error;
        });
      } else if (error.code == 'rate_limited' && error.retryAfter != null) {
        _startRateLimitCooldown(error);
      } else {
        setState(() => _error = error);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  int get _rateLimitSecondsRemaining {
    final duration = _rateLimitDuration;
    final stopwatch = _rateLimitStopwatch;
    if (duration == null || stopwatch == null) return 0;
    final remaining = duration - stopwatch.elapsed;
    if (remaining <= Duration.zero) return 0;
    return (remaining.inMilliseconds / 1000).ceil();
  }

  void _startRateLimitCooldown(DiscordShareException error) {
    _rateLimitTimer?.cancel();
    _rateLimitDuration = error.retryAfter;
    _rateLimitStopwatch = Stopwatch()..start();
    setState(() => _error = error);
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_rateLimitSecondsRemaining <= 0) {
        timer.cancel();
        _rateLimitDuration = null;
        _rateLimitStopwatch = null;
        setState(() {
          if (_error is DiscordShareException &&
              (_error! as DiscordShareException).code == 'rate_limited') {
            _error = null;
          }
        });
        return;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: _initializing
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                heightFactor: 1,
                child: CircularProgressIndicator(),
              ),
            )
          : _session == null
          ? _buildVerificationState(theme)
          : _buildEditor(theme),
    );
  }

  Widget _buildVerificationState(ThemeData theme) {
    final colors = theme.colorScheme;
    final isError = _error != null;
    final icon = _joinRequired
        ? Icons.groups_2_outlined
        : isError
        ? Icons.error_outline
        : Icons.verified_user_outlined;
    final title = _joinRequired
        ? context.l10n.discordShare_joinRequired
        : context.l10n.discordShare_verifyTitle;
    final description = _joinRequired
        ? context.l10n.discordShare_joinDescription
        : context.l10n.discordShare_verifyDescription;
    return SingleChildScrollView(
      key: const ValueKey('discord-share-scroll'),
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: colors.primary),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _InlineNotice(
                  icon: Icons.error_outline,
                  text: _localizedError(_error!),
                  color: colors.error,
                ),
              ],
              const SizedBox(height: 24),
              if (_joinRequired) ...[
                FilledButton(
                  onPressed: _openCommunity,
                  child: _buildVerificationButtonContent(
                    icon: const Icon(Icons.group_add_outlined),
                    label: context.l10n.discordShare_joinServer,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _authenticating ? null : _authenticate,
                  child: _buildVerificationButtonContent(
                    icon: _authenticating
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: context.l10n.discordShare_retryVerification,
                  ),
                ),
              ] else
                FilledButton(
                  onPressed: _authenticating ? null : _authenticate,
                  child: _buildVerificationButtonContent(
                    icon: _authenticating
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.open_in_browser, size: 18),
                    label: _authenticating
                        ? context.l10n.discordShare_verifying
                        : context.l10n.discordShare_verifyButton,
                  ),
                ),
              if (_authenticating) ...[
                const SizedBox(height: 12),
                Text(
                  context.l10n.discordShare_verifyingHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationButtonContent({
    required Widget icon,
    required String label,
  }) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        icon,
        Text(label, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildEditor(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final preview = _buildImagePreview(theme, compact: compact);
        final form = _buildShareForm(theme);
        return ContentSizedAdaptiveForm(
          scrollViewKey: const ValueKey('discord-share-scroll'),
          scrollController: widget.scrollController,
          padding: const EdgeInsets.all(20),
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [const Divider(height: 1), _buildActions()],
          ),
          content: [
            compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [preview, const SizedBox(height: 18), form],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 260, child: preview),
                      const SizedBox(width: 22),
                      Expanded(child: form),
                    ],
                  ),
          ],
        );
      },
    );
  }

  Widget _buildImagePreview(ThemeData theme, {required bool compact}) {
    final colors = theme.colorScheme;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: ImageViewportSurface.background,
        child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact)
          SizedBox(height: 210, child: image)
        else
          AspectRatio(
            aspectRatio:
                (widget.width != null &&
                    widget.width! > 0 &&
                    widget.height != null &&
                    widget.height! > 0)
                ? widget.width! / widget.height!
                : 1,
            child: image,
          ),
        const SizedBox(height: 10),
        Text(
          p.basename(widget.fileName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_outlined, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.l10n.discordShare_account(
                    _session!.user.effectiveName,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: context.l10n.discordShare_disconnect,
                onPressed: _sending ? null : _disconnect,
                icon: const Icon(Icons.logout, size: 17),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShareForm(ThemeData theme) {
    final colors = theme.colorScheme;
    final hasAnyCategory = _categoryContent.values.any(
      (value) => value.isNotEmpty,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.discordShare_channels,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _targets
              .map((target) {
                final selected = _selectedTargets.contains(target.id);
                return FilterChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Icon(
                    selected ? Icons.tag : Icons.tag_outlined,
                    size: 16,
                  ),
                  label: Text(target.label),
                  onSelected: _sending
                      ? null
                      : (value) => _toggleTarget(target.id, value),
                );
              })
              .toList(growable: false),
        ),
        if (_selectedTargets.isEmpty) ...[
          const SizedBox(height: 6),
          Text(
            context.l10n.discordShare_selectChannel,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
          ),
        ],
        const SizedBox(height: 18),
        TextField(
          controller: _captionController,
          enabled: !_sending,
          maxLength: 256,
          maxLines: 2,
          minLines: 1,
          decoration: InputDecoration(
            labelText: context.l10n.discordShare_caption,
            hintText: context.l10n.discordShare_captionHint,
            prefixIcon: const Icon(Icons.chat_bubble_outline, size: 19),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.discordShare_promptCategories,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (!hasAnyCategory)
          _InlineNotice(
            icon: Icons.info_outline,
            text: context.l10n.discordShare_noPromptMetadata,
            color: colors.primary,
          )
        else ...[
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _PromptCategory.values
                .map((category) {
                  final available =
                      _categoryContent[category]?.isNotEmpty == true;
                  return FilterChip(
                    selected: _selectedCategories.contains(category),
                    label: Text(_categoryLabel(category)),
                    onSelected: !_sending && available
                        ? (value) => _toggleCategory(category, value)
                        : null,
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.discordShare_promptEditHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            enabled: !_sending,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: context.l10n.discordShare_promptContent,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _includeMetadata,
          onChanged: _sending ? null : _setIncludeMetadata,
          title: Text(
            context.l10n.discordShare_keepMetadata,
            style: theme.textTheme.titleSmall,
          ),
          subtitle: Text(context.l10n.discordShare_keepMetadataHint),
          secondary: const Icon(Icons.fingerprint_outlined),
        ),
        const SizedBox(height: 6),
        _InlineNotice(
          icon: Icons.privacy_tip_outlined,
          text: context.l10n.discordShare_privacyHint,
          color: colors.tertiary,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _InlineNotice(
            icon: Icons.error_outline,
            text: context.l10n.discordShare_failed(_localizedError(_error!)),
            color: colors.error,
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton.icon(
            onPressed:
                _sending ||
                    _selectedTargets.isEmpty ||
                    _rateLimitSecondsRemaining > 0
                ? null
                : _send,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _sending
                  ? context.l10n.discordShare_sending
                  : context.l10n.discordShare_send,
            ),
          ),
        ],
      ),
    );
  }

  String _localizedError(Object error) => discordShareErrorText(
    context,
    error,
    retrySeconds: _rateLimitSecondsRemaining,
  );

  String _categoryLabel(_PromptCategory category) => switch (category) {
    _PromptCategory.main => context.l10n.discordShare_categoryMain,
    _PromptCategory.characters => context.l10n.discordShare_categoryCharacters,
    _PromptCategory.quality => context.l10n.discordShare_categoryQuality,
    _PromptCategory.fixed => context.l10n.discordShare_categoryFixed,
  };

  Map<_PromptCategory, String> _buildCategoryContent(
    NaiImageMetadata? metadata,
  ) {
    if (metadata == null) {
      return {for (final category in _PromptCategory.values) category: ''};
    }
    final main = metadata.hasSeparatedFields
        ? metadata.mainPrompt.trim()
        : metadata.prompt.trim();
    final characters = metadata.characterPrompts
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .join('\n\n');
    final quality =
        <String>[
              ...metadata.qualityTags,
              if (metadata.hasRecordedTransparentBackgroundTag)
                'transparent background',
            ]
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .join(', ');
    final fixed =
        <String>[...metadata.fixedPrefixTags, ...metadata.fixedSuffixTags]
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .join(', ');
    return {
      _PromptCategory.main: main,
      _PromptCategory.characters: characters,
      _PromptCategory.quality: quality,
      _PromptCategory.fixed: fixed,
    };
  }
}

enum _PromptCategory { main, characters, quality, fixed }

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
