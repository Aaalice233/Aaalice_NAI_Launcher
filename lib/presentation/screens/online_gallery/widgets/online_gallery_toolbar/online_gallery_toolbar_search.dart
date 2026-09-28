import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/online_gallery/gallery_tag_query.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/online_gallery/danbooru_post.dart';
import '../../../../providers/online_gallery_provider.dart';
import '../../../../widgets/autocomplete/autocomplete_config.dart';
import '../../../../widgets/autocomplete/autocomplete_wrapper.dart';
import '../../../../widgets/common/app_toast.dart';
import '../../../../widgets/common/input_surface_container.dart';
import '../../../online_gallery/online_gallery_screen_controller.dart';
import 'online_gallery_toolbar.dart';
import 'online_gallery_toolbar_bindings.dart';

class OnlineGalleryToolbarSearch {
  const OnlineGalleryToolbarSearch(this.bindings);

  final OnlineGalleryToolbarBindings bindings;

  BuildContext get context => bindings.context;
  OnlineGalleryState get state => bindings.data.gallery;
  OnlineGalleryScreenController get _controller => bindings.controller;
  OnlineGalleryNotifier get _galleryNotifier => bindings.commands.gallery;

  GallerySourceId _activeSource(OnlineGalleryState state) =>
      switch (state.viewMode) {
        GalleryViewMode.search => state.sourceId,
        GalleryViewMode.popular => state.popularSourceId,
        GalleryViewMode.favorites => state.favoritesSourceId,
      };

  Widget buildMobile(ThemeData theme) => _buildMobileSearchFields(theme, state);
  Widget buildDesktop(ThemeData theme) => _buildSearchFields(theme, state);

  Widget buildPromptField(
    ThemeData theme, {
    required TextEditingController controller,
    required FocusNode focusNode,
  }) => _buildPlainSearchField(
    theme,
    controller: controller,
    focusNode: focusNode,
    hintText: context.l10n.onlineGallery_aiTagPromptQuery,
    icon: Icons.auto_awesome_rounded,
    onSubmitted: () => _submitAiTagSearch(state),
  );

  Widget _buildMobileSearchFields(ThemeData theme, OnlineGalleryState state) {
    final isPopular = state.viewMode == GalleryViewMode.popular;
    final activeSource = _activeSource(state);
    if (state.viewMode == GalleryViewMode.favorites) {
      return _buildPlainSearchField(
        theme,
        controller: _controller.favoriteSearchController,
        focusNode: _controller.favoriteSearchFocusNode,
        hintText: context.l10n.onlineGallery_searchFavorites,
        icon: Icons.search_rounded,
        treatSpacesAsSeparators: true,
        onSubmitted: () => _galleryNotifier.searchFavorites(
          _controller.favoriteSearchController.text,
        ),
      );
    }
    if (activeSource == GallerySourceId.quickTagCloud) {
      return _buildCodexSearchField(theme);
    }
    if (activeSource == GallerySourceId.aiTag) {
      final controller = isPopular
          ? _controller.popularSearchController
          : _controller.searchController;
      final focusNode = isPopular
          ? _controller.popularSearchFocusNode
          : _controller.searchFocusNode;
      return _buildPlainSearchField(
        theme,
        controller: controller,
        focusNode: focusNode,
        hintText: context.l10n.onlineGallery_aiTagQuery,
        icon: Icons.manage_search_rounded,
        treatSpacesAsSeparators: true,
        showTagCount: true,
        onSubmitted: () => _submitAiTagSearch(state),
      );
    }
    return _buildSearchField(
      theme,
      controller: isPopular
          ? _controller.popularSearchController
          : _controller.searchController,
      focusNode: isPopular
          ? _controller.popularSearchFocusNode
          : _controller.searchFocusNode,
      onSubmitted: isPopular
          ? (value) => _galleryNotifier.searchPopular(
              query: value,
              prompt: state.popularPromptQuery,
            )
          : _galleryNotifier.search,
    );
  }

  void _submitAiTagSearch(OnlineGalleryState state) {
    final isPopular = state.viewMode == GalleryViewMode.popular;
    final queryController = isPopular
        ? _controller.popularSearchController
        : _controller.searchController;
    final promptController = isPopular
        ? _controller.popularPromptSearchController
        : _controller.promptSearchController;
    if (!_validateTagQuery(queryController.text)) return;
    if (isPopular) {
      unawaited(
        _galleryNotifier.searchPopular(
          query: queryController.text,
          prompt: promptController.text,
        ),
      );
    } else {
      unawaited(
        _galleryNotifier.searchWithPrompt(
          queryController.text,
          prompt: promptController.text,
        ),
      );
    }
  }

  Widget _buildSearchFields(ThemeData theme, OnlineGalleryState state) {
    final isPopular = state.viewMode == GalleryViewMode.popular;
    final isFavorites = state.viewMode == GalleryViewMode.favorites;
    final activeSource = switch (state.viewMode) {
      GalleryViewMode.search => state.sourceId,
      GalleryViewMode.popular => state.popularSourceId,
      GalleryViewMode.favorites => state.favoritesSourceId,
    };
    if (isFavorites) {
      return _buildPlainSearchField(
        theme,
        controller: _controller.favoriteSearchController,
        focusNode: _controller.favoriteSearchFocusNode,
        hintText: context.l10n.onlineGallery_searchFavorites,
        icon: Icons.search_rounded,
        treatSpacesAsSeparators: true,
        onSubmitted: () => _galleryNotifier.searchFavorites(
          _controller.favoriteSearchController.text,
        ),
      );
    }
    if (activeSource == GallerySourceId.quickTagCloud) {
      return _buildCodexSearchField(theme);
    }
    if (activeSource != GallerySourceId.aiTag) {
      return _buildSearchField(
        theme,
        controller: isPopular
            ? _controller.popularSearchController
            : _controller.searchController,
        focusNode: isPopular
            ? _controller.popularSearchFocusNode
            : _controller.searchFocusNode,
        onSubmitted: isPopular
            ? (value) => _galleryNotifier.searchPopular(
                query: value,
                prompt: state.popularPromptQuery,
              )
            : _galleryNotifier.search,
      );
    }
    final queryController = isPopular
        ? _controller.popularSearchController
        : _controller.searchController;
    final promptController = isPopular
        ? _controller.popularPromptSearchController
        : _controller.promptSearchController;
    final queryFocus = isPopular
        ? _controller.popularSearchFocusNode
        : _controller.searchFocusNode;
    final promptFocus = isPopular
        ? _controller.popularPromptSearchFocusNode
        : _controller.promptSearchFocusNode;
    void submit() {
      if (!_validateTagQuery(queryController.text)) return;
      if (isPopular) {
        _galleryNotifier.searchPopular(
          query: queryController.text,
          prompt: promptController.text,
        );
      } else {
        _galleryNotifier.searchWithPrompt(
          queryController.text,
          prompt: promptController.text,
        );
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Row(
        children: [
          Expanded(
            child: _buildPlainSearchField(
              theme,
              controller: queryController,
              focusNode: queryFocus,
              hintText: context.l10n.onlineGallery_aiTagQuery,
              icon: Icons.manage_search,
              treatSpacesAsSeparators: true,
              showTagCount: true,
              onSubmitted: submit,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPlainSearchField(
              theme,
              controller: promptController,
              focusNode: promptFocus,
              hintText: context.l10n.onlineGallery_aiTagPromptQuery,
              icon: Icons.auto_awesome,
              onSubmitted: submit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainSearchField(
    ThemeData theme, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    required VoidCallback onSubmitted,
    bool treatSpacesAsSeparators = false,
    bool showTagCount = false,
  }) {
    final fieldHeight = gallerySearchFieldHeightFor(context);
    return AutocompleteWrapper(
      controller: controller,
      focusNode: focusNode,
      config: AutocompleteConfig(
        autoInsertComma: false,
        treatSpacesAsSeparators: treatSpacesAsSeparators,
      ),
      onSuggestionSelected: (_) => onSubmitted(),
      child: InputSurfaceContainer(
        height: fieldHeight,
        borderRadius: fieldHeight / 2,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            focusNode: focusNode,
            style: theme.textTheme.bodyMedium,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
                fontSize: 13,
              ),
              prefixIcon: Icon(icon, size: 18),
              suffixIcon: showTagCount
                  ? _buildTagCountSuffix(
                      theme,
                      controller,
                      onClear: () {
                        controller.clear();
                        focusNode.requestFocus();
                      },
                    )
                  : value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n.common_clear,
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.65,
                        ),
                      ),
                      onPressed: () {
                        controller.clear();
                        focusNode.requestFocus();
                      },
                    ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
      ),
    );
  }

  Widget _buildCodexSearchField(ThemeData theme) {
    final fieldHeight = gallerySearchFieldHeightFor(context);
    return InputSurfaceContainer(
      height: fieldHeight,
      constraints: const BoxConstraints(maxWidth: 520),
      borderRadius: fieldHeight / 2,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller.searchController,
        builder: (context, value, _) => TextField(
          controller: _controller.searchController,
          focusNode: _controller.searchFocusNode,
          style: theme.textTheme.bodyMedium,
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: context.l10n.onlineGallery_codexSearchHint,
            filled: false,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            suffixIcon: _buildTagCountSuffix(
              theme,
              _controller.searchController,
              onClear: () {
                _controller.searchController.clear();
                _galleryNotifier.search('');
              },
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
          onSubmitted: (value) =>
              _submitTagSearch(value, onValid: _galleryNotifier.search),
        ),
      ),
    );
  }

  bool _validateTagQuery(String value) {
    if (GalleryTagQueryParser.parse(value).isValid) return true;
    AppToast.warning(
      context,
      context.l10n.onlineGallery_maxTagsExceeded(maxGallerySearchTags),
    );
    return false;
  }

  void _submitTagSearch(String value, {required ValueChanged<String> onValid}) {
    if (_validateTagQuery(value)) onValid(value);
  }

  Widget _buildTagCountSuffix(
    ThemeData theme,
    TextEditingController controller, {
    required VoidCallback onClear,
  }) {
    final count = GalleryTagQueryParser.parse(controller.text).ordinaryTagCount;
    final exceeded = count > maxGallerySearchTags;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count/$maxGallerySearchTags',
          key: const ValueKey('online-gallery-tag-count'),
          style: theme.textTheme.labelSmall?.copyWith(
            color: exceeded
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (controller.text.isNotEmpty)
          IconButton(
            tooltip: context.l10n.common_clear,
            icon: Icon(
              Icons.close,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            onPressed: onClear,
          ),
      ],
    );
  }

  Widget _buildSearchField(
    ThemeData theme, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onSubmitted,
  }) {
    final fieldHeight = gallerySearchFieldHeightFor(context);
    return AutocompleteWrapper(
      controller: controller,
      focusNode: focusNode,
      config: const AutocompleteConfig(
        autoInsertComma: false,
        treatSpacesAsSeparators: true,
      ),
      onSuggestionSelected: (value) {
        // 选择补全建议后立即触发搜索
        _controller.searchDebounceTimer?.cancel();
        _submitTagSearch(value, onValid: onSubmitted);
      },
      child: InputSurfaceContainer(
        height: fieldHeight,
        constraints: const BoxConstraints(maxWidth: 400),
        borderRadius: fieldHeight / 2,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, _, __) => TextField(
            controller: controller,
            focusNode: focusNode,
            style: theme.textTheme.bodyMedium,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: context.l10n.onlineGallery_searchTags,
              filled: false,
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
              suffixIcon: _buildTagCountSuffix(
                theme,
                controller,
                onClear: () {
                  controller.clear();
                  onSubmitted('');
                },
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 64),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
            onSubmitted: (value) =>
                _submitTagSearch(value, onValid: onSubmitted),
          ),
        ),
      ),
    );
  }
}
