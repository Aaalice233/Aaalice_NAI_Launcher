import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/cache/online_gallery_prefetch_coordinator.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../providers/online_gallery_provider.dart';
import '../../widgets/online_gallery/online_gallery_hover_controller.dart';

/// Owns the ephemeral input, focus, scrolling, anchor and prefetch lifecycle for
/// [OnlineGalleryScreen]. Provider state remains the source of truth for the
/// current gallery query and loaded items.
class OnlineGalleryScreenController extends ChangeNotifier {
  OnlineGalleryScreenController({required this.prefetchCoordinator});

  final searchController = TextEditingController();
  final promptSearchController = TextEditingController();
  final popularSearchController = TextEditingController();
  final popularPromptSearchController = TextEditingController();
  final favoriteSearchController = TextEditingController();
  final searchFocusNode = FocusNode();
  final promptSearchFocusNode = FocusNode();
  final popularSearchFocusNode = FocusNode();
  final popularPromptSearchFocusNode = FocusNode();
  final favoriteSearchFocusNode = FocusNode();
  final scrollController = ScrollController();
  final pageController = TextEditingController();
  final pageFocusNode = FocusNode();
  final hoverController = OnlineGalleryHoverController();
  final OnlineGalleryPrefetchCoordinator prefetchCoordinator;
  final dateRangeLayerLink = LayerLink();
  final anchorRestoreKey = GlobalKey();
  final primarySearchRevealKey = GlobalKey();
  final scrolling = ValueNotifier<bool>(false);

  final Map<int, ({GalleryItem item, double itemWidth, double visibleTop})>
  visibleItems = {};
  final Set<String> pendingGalleryDetails = <String>{};

  Timer? searchDebounceTimer;
  Timer? scrollStopTimer;
  Timer? idlePrefetchTimer;
  Timer? _pageFocusNotificationTimer;
  OverlayEntry? dateRangeOverlayEntry;
  String? pendingAnchorStableKey;
  double pendingAnchorLocalOffset = 0;
  double lastScrollOffset = 0;
  int scrollDirection = 1;
  int lookaheadItemCount = 12;
  bool get isScrolling => scrolling.value;
  bool isEditingPage = false;
  GalleryViewMode? lastViewMode;
  GallerySourceId? lastFavoritesSource;
  String? lastCacheKey;
  bool? lastRandomEnabled;
  int? lastRandomDrawRevision;
  String? scheduledAutoLoadCacheKey;
  bool restoreInitialPositionPending = false;
  bool branchVisible = true;

  void synchronizeQueries(OnlineGalleryState state) {
    _setText(searchController, state.searchQuery);
    _setText(promptSearchController, state.promptQuery);
    _setText(popularSearchController, state.popularQuery);
    _setText(popularPromptSearchController, state.popularPromptQuery);
    _setText(favoriteSearchController, state.favoriteSearchQuery);
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text != value) controller.text = value;
  }

  void setScrolling(bool value) {
    if (isScrolling == value) return;
    scrolling.value = value;
  }

  bool recordVisibleItem({
    required int index,
    required GalleryItem item,
    required double itemWidth,
    required double visibleTop,
  }) {
    final previous = visibleItems[index];
    visibleItems[index] = (
      item: item,
      itemWidth: itemWidth,
      visibleTop: visibleTop,
    );
    return previous?.item.stableKey != item.stableKey;
  }

  void beginPageEditing(int currentPage) {
    isEditingPage = true;
    pageController.text = currentPage.toString();
    pageController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: pageController.text.length,
    );
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pageFocusNode.requestFocus();
    });
  }

  int? finishPageEditing() {
    final parsed = int.tryParse(pageController.text.trim());
    isEditingPage = false;
    notifyListeners();
    return parsed != null && parsed >= 1 ? parsed : null;
  }

  void cancelPageEditingWhenUnfocused() {
    if (pageFocusNode.hasFocus || !isEditingPage) return;
    // Focus changes can occur while a route is being finalized. Deferring the
    // notification avoids rebuilding pagination during the focus dispatch.
    _pageFocusNotificationTimer?.cancel();
    _pageFocusNotificationTimer = Timer(Duration.zero, () {
      if (pageFocusNode.hasFocus || !isEditingPage) return;
      isEditingPage = false;
      notifyListeners();
    });
  }

  void cancelTimers() {
    searchDebounceTimer?.cancel();
    scrollStopTimer?.cancel();
    idlePrefetchTimer?.cancel();
    _pageFocusNotificationTimer?.cancel();
  }

  @override
  void dispose() {
    cancelTimers();
    dateRangeOverlayEntry?.remove();
    dateRangeOverlayEntry = null;
    hoverController.dispose();
    prefetchCoordinator.dispose();
    searchController.dispose();
    promptSearchController.dispose();
    popularSearchController.dispose();
    popularPromptSearchController.dispose();
    favoriteSearchController.dispose();
    searchFocusNode.dispose();
    promptSearchFocusNode.dispose();
    popularSearchFocusNode.dispose();
    popularPromptSearchFocusNode.dispose();
    favoriteSearchFocusNode.dispose();
    scrollController.dispose();
    pageController.dispose();
    pageFocusNode.dispose();
    scrolling.dispose();
    super.dispose();
  }
}
