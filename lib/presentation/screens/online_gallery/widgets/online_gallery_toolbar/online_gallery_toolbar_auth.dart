import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/platform/platform_capabilities.dart';
import '../../../../../core/services/date_formatting_service.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/datasources/remote/danbooru_api_service.dart';
import '../../../../../data/models/online_gallery/danbooru_post.dart';
import '../../../../../data/services/danbooru_auth_service.dart';
import '../../../../../data/services/gelbooru_auth_service.dart';
import '../../../../providers/online_gallery_provider.dart';
import 'online_gallery_auth_dialogs.dart';
import 'online_gallery_toolbar.dart';
import 'online_gallery_toolbar_bindings.dart';

class OnlineGalleryToolbarAuthControls {
  OnlineGalleryToolbarAuthControls(this.bindings);

  final OnlineGalleryToolbarBindings bindings;
  final DateFormattingService _dateFormattingService = DateFormattingService();

  BuildContext get context => bindings.context;
  WidgetRef get ref => bindings.ref;
  OnlineGalleryState get state => bindings.data.gallery;
  OnlineGalleryNotifier get _galleryNotifier => bindings.commands.gallery;
  OnlineGalleryAuthDialogs get _dialogs => OnlineGalleryAuthDialogs(bindings);

  Widget buildUserButton(ThemeData theme, {required bool compact}) =>
      _buildUserButton(
        theme,
        state,
        bindings.data.danbooruAuth,
        bindings.data.gelbooruAuth,
        compact: compact,
      );

  Widget buildPopularOptions(ThemeData theme) =>
      _buildPopularOptions(theme, state);
  GallerySourceId get activeSource => _activeSource(state);
  bool get canWriteFavorites => _canWriteFavorites(state);
  Widget buildGelbooruFavoritesNotice(ThemeData theme) =>
      _buildGelbooruFavoritesNotice(theme);

  Widget _buildUserButton(
    ThemeData theme,
    OnlineGalleryState state,
    DanbooruAuthState authState,
    GelbooruAuthState gelbooruAuthState, {
    required bool compact,
  }) {
    Widget accountControl({
      required String label,
      required IconData icon,
      required Color backgroundColor,
      required Color foregroundColor,
      required Color borderColor,
      IconData? statusIcon,
      Color? statusColor,
      VoidCallback? onTap,
      bool enabled = true,
    }) {
      final content = SizedBox(
        key: const ValueKey('online-gallery-account-avatar'),
        width: galleryToolbarControlHeight,
        height: galleryToolbarControlHeight,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: Icon(icon, size: 18, color: foregroundColor)),
                if (statusIcon != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: statusColor ?? foregroundColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        statusIcon,
                        size: 9,
                        color: theme.colorScheme.surface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      if (onTap == null) {
        return Opacity(opacity: enabled ? 1 : 0.55, child: content);
      }
      return Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: content,
        ),
      );
    }

    final sourceId = _activeSource(state);
    if (sourceId == GallerySourceId.safebooru ||
        sourceId == GallerySourceId.aiTag ||
        sourceId == GallerySourceId.quickTagCloud) {
      final label = sourceId == GallerySourceId.quickTagCloud
          ? context.l10n.onlineGallery_sourceQuickTagCloud
          : sourceId.label;
      return Tooltip(
        message: label,
        child: Semantics(
          enabled: false,
          child: accountControl(
            label: label,
            icon: Icons.person_off_outlined,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            borderColor: theme.colorScheme.outlineVariant,
            enabled: false,
          ),
        ),
      );
    }
    if (sourceId == GallerySourceId.gelbooru) {
      final invalid = gelbooruAuthState.status == GelbooruAuthStatus.invalid;
      final ready = gelbooruAuthState.isAuthenticated;
      final message = invalid
          ? context.l10n.onlineGallery_gelbooruApiInvalid
          : ready
          ? context.l10n.onlineGallery_gelbooruApiReady
          : context.l10n.onlineGallery_configureGelbooruApi;
      return Tooltip(
        message: message,
        child: Semantics(
          button: true,
          label: message,
          child: accountControl(
            label: compact ? 'API' : message,
            icon: invalid
                ? Icons.person_off_outlined
                : ready
                ? Icons.person
                : Icons.person_outline,
            backgroundColor: invalid
                ? theme.colorScheme.errorContainer
                : ready
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHigh,
            foregroundColor: invalid
                ? theme.colorScheme.onErrorContainer
                : ready
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            borderColor: invalid
                ? theme.colorScheme.error
                : ready
                ? theme.colorScheme.primary.withValues(alpha: 0.45)
                : theme.colorScheme.outlineVariant,
            statusIcon: invalid
                ? Icons.priority_high
                : ready
                ? Icons.check
                : Icons.key,
            statusColor: invalid
                ? theme.colorScheme.error
                : ready
                ? Colors.green.shade600
                : theme.colorScheme.tertiary,
            onTap: () => _dialogs.showGelbooruCredentials(context),
          ),
        ),
      );
    }

    if (authState.isLoggedIn) {
      final username = authState.credentials?.username ?? 'Danbooru';
      return PopupMenuButton<String>(
        tooltip: username,
        onSelected: (value) {
          if (value == 'logout') {
            ref.read(danbooruAuthProvider.notifier).logout();
          }
        },
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username, style: theme.textTheme.titleSmall),
                if (authState.user != null)
                  Text(
                    authState.user!.levelName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                const Icon(Icons.logout, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.onlineGallery_logout),
              ],
            ),
          ),
        ],
        child: accountControl(
          label: username,
          icon: Icons.person,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          borderColor: theme.colorScheme.primary.withValues(alpha: 0.45),
          statusIcon: Icons.check,
          statusColor: Colors.green.shade600,
        ),
      );
    }

    return Tooltip(
      message: context.l10n.onlineGallery_login,
      child: Semantics(
        button: true,
        label: context.l10n.onlineGallery_login,
        child: accountControl(
          label: context.l10n.onlineGallery_login,
          icon: Icons.person_outline,
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          borderColor: theme.colorScheme.outlineVariant,
          statusIcon: Icons.login,
          statusColor: theme.colorScheme.primary,
          onTap: () => _dialogs.showDanbooruLogin(context),
        ),
      ),
    );
  }

  Widget _buildPopularOptions(ThemeData theme, OnlineGalleryState state) {
    if (state.popularSourceId == GallerySourceId.aiTag) {
      final months = state.aiTagConfig?.rankMonths ?? const <String>[];
      final values = ['current', ...months, 'older'];
      final selected = values.contains(state.aiTagPopularPeriod)
          ? state.aiTagPopularPeriod
          : 'current';
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              items: values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        value == 'current'
                            ? context.l10n.onlineGallery_aiTagCurrentMonthly
                            : value == 'older'
                            ? context.l10n.onlineGallery_aiTagOlderMonthly
                            : value,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  _galleryNotifier.setAiTagPopularPeriod(value);
                }
              },
            ),
          ),
          Text(
            context.l10n.onlineGallery_imageCount(
              state.posts.length.toString(),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<PopularScale>(
          segments: [
            ButtonSegment(
              value: PopularScale.day,
              label: Text(context.l10n.onlineGallery_dayRank),
            ),
            ButtonSegment(
              value: PopularScale.week,
              label: Text(context.l10n.onlineGallery_weekRank),
            ),
            ButtonSegment(
              value: PopularScale.month,
              label: Text(context.l10n.onlineGallery_monthRank),
            ),
          ],
          selected: {state.popularScale},
          onSelectionChanged: (selected) {
            _galleryNotifier.setPopularScale(selected.first);
          },
          style: ButtonStyle(
            visualDensity: PlatformCapabilities.current.isMobile
                ? VisualDensity.standard
                : VisualDensity.compact,
            tapTargetSize: PlatformCapabilities.current.isMobile
                ? MaterialTapTargetSize.padded
                : MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        TextButton.icon(
          onPressed: () => _selectDate(context, state),
          icon: const Icon(Icons.calendar_today, size: 14),
          label: Text(
            state.popularDate != null
                ? _dateFormattingService.formatWithPattern(
                    state.popularDate!,
                    'yyyy-MM-dd',
                  )
                : context.l10n.onlineGallery_today,
            style: const TextStyle(fontSize: 13),
          ),
          style: TextButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            visualDensity: PlatformCapabilities.current.isMobile
                ? VisualDensity.standard
                : VisualDensity.compact,
          ),
        ),
        if (state.popularDate != null)
          IconButton(
            onPressed: () => _galleryNotifier.setPopularDate(null),
            icon: const Icon(Icons.close, size: 16),
            tooltip: context.l10n.onlineGallery_clear,
          ),
        Text(
          context.l10n.onlineGallery_imageCount(state.posts.length.toString()),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    OnlineGalleryState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.popularDate ?? now,
      firstDate: DateTime(2005),
      lastDate: now,
    );
    if (picked != null) {
      _galleryNotifier.setPopularDate(picked);
    }
  }

  GallerySourceId _activeSource(OnlineGalleryState state) {
    return switch (state.viewMode) {
      GalleryViewMode.search => state.sourceId,
      GalleryViewMode.favorites => state.favoritesSourceId,
      GalleryViewMode.popular => state.popularSourceId,
    };
  }

  bool _canWriteFavorites(OnlineGalleryState state) {
    final sourceId = _activeSource(state);
    final capabilities = gallerySourceCapabilities[sourceId]!;
    return capabilities.supportsWritableFavorites ||
        capabilities.supportsLocalFavorites;
  }

  Widget _buildGelbooruFavoritesNotice(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 15,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            context.l10n.onlineGallery_gelbooruReadOnly,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              context.l10n.onlineGallery_gelbooruFavoritesSortHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
