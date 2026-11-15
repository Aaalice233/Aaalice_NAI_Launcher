import 'package:flutter/material.dart';

import '../../../core/autocomplete/autocomplete_settings.dart';
import '../../../core/autocomplete/cooccurrence_data_pack_service.dart';
import '../../../core/autocomplete/completion_models.dart';
import '../../../core/autocomplete/zh_dictionary_service.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import 'completion_non_focusable_icon_button.dart';

class CompletionOverlayFooter extends StatelessWidget {
  const CompletionOverlayFooter({
    super.key,
    required this.state,
    required this.settings,
    required this.dictionaryState,
    required this.cooccurrenceDataPackState,
    required this.onOpenSettings,
  });

  final CompletionState state;
  final AutocompleteSettings settings;
  final ZhDictionaryState dictionaryState;
  final CooccurrenceDataPackState cooccurrenceDataPackState;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minimumHeight = context.interactionPolicy.touchAvailable
        ? context.interactionPolicy.minimumControlExtent
        : 31.0;
    final scaledHeight = MediaQuery.textScalerOf(context).scale(11) * 1.35 + 16;
    final footerHeight = scaledHeight > minimumHeight
        ? scaledHeight
        : minimumHeight;
    return Container(
      key: const ValueKey('autocomplete-popup-footer'),
      height: footerHeight,
      padding: const EdgeInsets.only(left: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final veryCompact = constraints.maxWidth < 430;
          final related = state.query?.relatedTag != null;
          final statuses = <_StatusDescriptor>[
            if (related)
              _relatedStatus(context)
            else if (!veryCompact)
              _baseStatus(context),
            _dictionaryStatus(context),
            _onlineStatus(context),
            if (!compact || settings.llmTranslationEnabled) _aiStatus(context),
          ];
          return Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (var index = 0; index < statuses.length; index++) ...[
                      if (index > 0) const SizedBox(width: 13),
                      Flexible(
                        child: _StatusIndicator(
                          key: ValueKey(statuses[index].key),
                          descriptor: statuses[index],
                          compact: compact,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                height: 19,
                width: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.46),
              ),
              CompletionNonFocusableIconButton(
                key: const ValueKey('autocomplete-popup-settings'),
                tooltip: context.l10n.autocomplete_openSettings,
                icon: Icons.settings_rounded,
                onPressed: onOpenSettings,
              ),
            ],
          );
        },
      ),
    );
  }

  _StatusDescriptor _baseStatus(BuildContext context) => _StatusDescriptor(
    key: 'autocomplete-status-base',
    icon: Icons.storage_rounded,
    label: context.l10n.autocomplete_statusBase,
    value: context.l10n.autocomplete_statusReady,
    tone: _StatusTone.ready,
    tooltip:
        '${context.l10n.autocomplete_baseCatalog}: ${context.l10n.autocomplete_statusReady}',
  );

  _StatusDescriptor _relatedStatus(BuildContext context) {
    if (!settings.relatedTagsEnabled) {
      return _StatusDescriptor(
        key: 'autocomplete-status-related',
        icon: Icons.hub_outlined,
        label: context.l10n.autocomplete_statusRelated,
        value: context.l10n.autocomplete_statusDisabled,
        tone: _StatusTone.inactive,
      );
    }
    if (state.isLocalLoading) {
      return _StatusDescriptor(
        key: 'autocomplete-status-related',
        icon: Icons.hub_outlined,
        label: context.l10n.autocomplete_statusRelated,
        value: context.l10n.autocomplete_statusSearching,
        tone: _StatusTone.loading,
        loading: true,
      );
    }
    if (state.localError?.isNotEmpty == true) {
      return _StatusDescriptor(
        key: 'autocomplete-status-related',
        icon: Icons.hub_outlined,
        label: context.l10n.autocomplete_statusRelated,
        value: context.l10n.autocomplete_statusError,
        tone: _StatusTone.error,
        tooltip: state.localError,
      );
    }
    if (!cooccurrenceDataPackState.hasInstalledData) {
      final downloading =
          cooccurrenceDataPackState.status ==
          CooccurrenceDataPackStatus.downloading;
      return _StatusDescriptor(
        key: 'autocomplete-status-related',
        icon: downloading ? Icons.downloading_rounded : Icons.cloud_outlined,
        label: context.l10n.autocomplete_statusRelated,
        value: context.l10n.autocomplete_statusOnlineOnly,
        tone: downloading ? _StatusTone.loading : _StatusTone.inactive,
        loading: downloading,
        tooltip: context.l10n.autocomplete_statusOnlineOnlyTooltip,
      );
    }
    final localCount = state.candidates
        .where(
          (candidate) =>
              candidate.sources.contains(CompletionSourceKind.cooccurrence),
        )
        .length;
    return _StatusDescriptor(
      key: 'autocomplete-status-related',
      icon: Icons.hub_rounded,
      label: context.l10n.autocomplete_statusRelated,
      value: '$localCount',
      tone: _StatusTone.ready,
      tooltip: context.l10n.autocomplete_sourceRelated,
    );
  }

  _StatusDescriptor _dictionaryStatus(BuildContext context) {
    if (dictionaryState.isBusy) {
      final progress = (dictionaryState.progress * 100).round().clamp(0, 100);
      return _StatusDescriptor(
        key: 'autocomplete-status-dictionary',
        icon: Icons.translate_rounded,
        label: context.l10n.autocomplete_statusDictionary,
        value: context.l10n.autocomplete_statusDownloading(progress),
        tone: _StatusTone.loading,
        loading: true,
      );
    }
    if (dictionaryState.error?.isNotEmpty == true) {
      return _StatusDescriptor(
        key: 'autocomplete-status-dictionary',
        icon: Icons.translate_rounded,
        label: context.l10n.autocomplete_statusDictionary,
        value: context.l10n.autocomplete_statusError,
        tone: _StatusTone.error,
        tooltip: dictionaryState.error,
      );
    }
    if (!dictionaryState.isInstalled) {
      return _StatusDescriptor(
        key: 'autocomplete-status-dictionary',
        icon: Icons.translate_rounded,
        label: context.l10n.autocomplete_statusDictionary,
        value: context.l10n.autocomplete_statusNotInstalled,
        tone: _StatusTone.warning,
        tooltip: context.l10n.autocomplete_zhNotInstalled,
      );
    }
    if (dictionaryState.updateAvailable) {
      return _StatusDescriptor(
        key: 'autocomplete-status-dictionary',
        icon: Icons.translate_rounded,
        label: context.l10n.autocomplete_statusDictionary,
        value: context.l10n.autocomplete_statusUpdateAvailable,
        tone: _StatusTone.warning,
      );
    }
    final translatedCount = state.candidates
        .where((candidate) => candidate.translation?.isNotEmpty == true)
        .length;
    final totalCount = state.candidates.length;
    return _StatusDescriptor(
      key: 'autocomplete-status-dictionary',
      icon: Icons.translate_rounded,
      label: context.l10n.autocomplete_statusDictionary,
      value: totalCount == 0
          ? context.l10n.autocomplete_statusReady
          : '$translatedCount/$totalCount',
      tone: _StatusTone.ready,
      tooltip: totalCount == 0
          ? context.l10n.autocomplete_entryCount(dictionaryState.tagCount)
          : context.l10n.autocomplete_translationCoverage(
              translatedCount,
              totalCount,
            ),
    );
  }

  _StatusDescriptor _onlineStatus(BuildContext context) {
    if (!settings.danbooruEnabled) {
      return _StatusDescriptor(
        key: 'autocomplete-status-online',
        icon: Icons.public_rounded,
        label: context.l10n.autocomplete_statusOnline,
        value: context.l10n.autocomplete_statusDisabled,
        tone: _StatusTone.inactive,
      );
    }
    if (state.isRemoteLoading) {
      return _StatusDescriptor(
        key: 'autocomplete-status-online',
        icon: Icons.public_rounded,
        label: context.l10n.autocomplete_statusOnline,
        value: context.l10n.autocomplete_statusSearching,
        tone: _StatusTone.loading,
        loading: true,
      );
    }
    if (state.remoteError?.isNotEmpty == true) {
      return _StatusDescriptor(
        key: 'autocomplete-status-online',
        icon: Icons.public_off_rounded,
        label: context.l10n.autocomplete_statusOnline,
        value: context.l10n.autocomplete_statusError,
        tone: _StatusTone.error,
        tooltip: state.remoteError,
      );
    }
    return _StatusDescriptor(
      key: 'autocomplete-status-online',
      icon: Icons.public_rounded,
      label: context.l10n.autocomplete_statusOnline,
      value: context.l10n.autocomplete_statusReady,
      tone: _StatusTone.ready,
      tooltip: context.l10n.autocomplete_danbooruPrivacy,
    );
  }

  _StatusDescriptor _aiStatus(BuildContext context) {
    if (!settings.llmTranslationEnabled) {
      return _StatusDescriptor(
        key: 'autocomplete-status-ai',
        icon: Icons.auto_awesome_outlined,
        label: context.l10n.autocomplete_statusAi,
        value: context.l10n.autocomplete_statusDisabled,
        tone: _StatusTone.inactive,
      );
    }
    if (state.candidates.any((candidate) => candidate.isTranslating)) {
      return _StatusDescriptor(
        key: 'autocomplete-status-ai',
        icon: Icons.auto_awesome_rounded,
        label: context.l10n.autocomplete_statusAi,
        value: context.l10n.autocomplete_statusTranslating,
        tone: _StatusTone.loading,
        loading: true,
      );
    }
    if (state.translationError?.isNotEmpty == true) {
      return _StatusDescriptor(
        key: 'autocomplete-status-ai',
        icon: Icons.auto_awesome_outlined,
        label: context.l10n.autocomplete_statusAi,
        value: context.l10n.autocomplete_statusError,
        tone: _StatusTone.error,
        tooltip: state.translationError,
      );
    }
    return _StatusDescriptor(
      key: 'autocomplete-status-ai',
      icon: Icons.auto_awesome_rounded,
      label: context.l10n.autocomplete_statusAi,
      value: context.l10n.autocomplete_statusReady,
      tone: _StatusTone.ready,
    );
  }
}

enum _StatusTone { ready, loading, warning, error, inactive }

class _StatusDescriptor {
  const _StatusDescriptor({
    required this.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.loading = false,
    this.tooltip,
  });

  final String key;
  final IconData icon;
  final String label;
  final String value;
  final _StatusTone tone;
  final bool loading;
  final String? tooltip;
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    super.key,
    required this.descriptor,
    required this.compact,
  });

  final _StatusDescriptor descriptor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toneColor = switch (descriptor.tone) {
      _StatusTone.ready => const Color(0xff4fb77b),
      _StatusTone.loading => theme.colorScheme.primary,
      _StatusTone.warning => const Color(0xffd99a3b),
      _StatusTone.error => theme.colorScheme.error,
      _StatusTone.inactive => theme.colorScheme.outline,
    };
    final tooltip = descriptor.tooltip?.isNotEmpty == true
        ? '${descriptor.label}: ${descriptor.value}\n${descriptor.tooltip}'
        : '${descriptor.label}: ${descriptor.value}';
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: '${descriptor.label}: ${descriptor.value}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (descriptor.loading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  value: MediaQuery.disableAnimationsOf(context) ? 0.75 : null,
                  strokeWidth: 1.7,
                  color: toneColor,
                ),
              )
            else
              Icon(descriptor.icon, size: 14, color: toneColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (!compact)
                      TextSpan(
                        text: '${descriptor.label} ',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    TextSpan(
                      text: descriptor.value,
                      style: TextStyle(
                        color: descriptor.tone == _StatusTone.error
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
