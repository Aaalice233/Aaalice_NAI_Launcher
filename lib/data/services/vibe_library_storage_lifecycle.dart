part of 'vibe_library_storage_service.dart';

mixin VibeLibraryStorageLifecycle {
  VibeLibraryStorageService get _lifecycleService =>
      this as VibeLibraryStorageService;

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(23)) {
      Hive.registerAdapter(VibeLibraryEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(VibeLibraryCategoryAdapter());
    }
  }

  /// 初始化并注册 Hive adapters
  Future<void> init() async {
    await VibePerformanceDiagnostics.measure('storage.init', () async {
      _registerAdapters();
      await Future.wait([_ensureDisplayEntriesBox(), _ensureCategoriesBox()]);
      AppLogger.d('VibeLibraryStorageService initialized', 'VibeLibrary');
    });
  }

  Future<Box<VibeLibraryEntry>> _openEntriesBox() async {
    return Hive.openBox<VibeLibraryEntry>(
      VibeLibraryStorageService._entriesBoxName,
    );
  }

  Future<LazyBox<VibeLibraryEntry>> _openLazyEntriesBox() async {
    return Hive.openLazyBox<VibeLibraryEntry>(
      VibeLibraryStorageService._entriesBoxName,
    );
  }

  Future<Box<VibeLibraryEntry>> _openDisplayEntriesBox() async {
    return Hive.openBox<VibeLibraryEntry>(
      VibeLibraryStorageService._displayEntriesBoxName,
    );
  }

  Future<Box<Uint8List>> _openThumbnailCacheBox() async {
    return Hive.openBox<Uint8List>(
      VibeLibraryStorageService._thumbnailCacheBoxName,
    );
  }

  Future<Box<VibeLibraryCategory>> _openCategoriesBox() async {
    return Hive.openBox<VibeLibraryCategory>(
      VibeLibraryStorageService._categoriesBoxName,
    );
  }

  Future<void> _ensureEntriesBox() async {
    final service = _lifecycleService;
    var awaitedActiveInit = false;
    var closedLazyBox = false;
    final span = VibePerformanceDiagnostics.start(
      'storage.ensureEntriesBox',
      details: {
        'hadEntriesBox': service._entriesBox?.isOpen == true,
        'hadLazyBox': service._lazyEntriesBox?.isOpen == true,
      },
    );
    try {
      if (service._entriesBox != null && service._entriesBox!.isOpen) {
        return;
      }

      if (service._lazyEntriesBox != null && service._lazyEntriesBox!.isOpen) {
        closedLazyBox = true;
        await service._lazyEntriesBox!.close();
        service._lazyEntriesBox = null;
      }

      _registerAdapters();
      final activeInit = service._entriesInitFuture;
      if (activeInit != null) {
        awaitedActiveInit = true;
        await activeInit;
        return;
      }

      final initFuture = _openEntriesBox().then((box) {
        service._entriesBox = box;
      });
      service._entriesInitFuture = initFuture;
      try {
        await initFuture;
      } catch (e, stackTrace) {
        AppLogger.e(
          'VibeLibrary entries 初始化失败',
          e,
          stackTrace,
          VibeLibraryStorageService._tag,
        );
        rethrow;
      } finally {
        if (identical(service._entriesInitFuture, initFuture)) {
          service._entriesInitFuture = null;
        }
      }
    } finally {
      span.finish(
        details: {
          'awaitedActiveInit': awaitedActiveInit,
          'closedLazyBox': closedLazyBox,
          'entriesBoxOpen': service._entriesBox?.isOpen == true,
        },
      );
    }
  }

  Future<void> _ensureLazyEntriesBox() async {
    final service = _lifecycleService;
    var awaitedActiveInit = false;
    final span = VibePerformanceDiagnostics.start(
      'storage.ensureLazyEntriesBox',
      details: {
        'hadEntriesBox': service._entriesBox?.isOpen == true,
        'hadLazyBox': service._lazyEntriesBox?.isOpen == true,
      },
    );
    try {
      if (service._entriesBox != null && service._entriesBox!.isOpen) {
        return;
      }
      if (service._lazyEntriesBox != null && service._lazyEntriesBox!.isOpen) {
        return;
      }

      _registerAdapters();
      final activeInit = service._lazyEntriesInitFuture;
      if (activeInit != null) {
        awaitedActiveInit = true;
        await activeInit;
        return;
      }

      final initFuture = _openLazyEntriesBox().then((box) {
        service._lazyEntriesBox = box;
      });
      service._lazyEntriesInitFuture = initFuture;
      try {
        await initFuture;
      } catch (e, stackTrace) {
        AppLogger.e(
          'VibeLibrary lazy entries 初始化失败',
          e,
          stackTrace,
          VibeLibraryStorageService._tag,
        );
        rethrow;
      } finally {
        if (identical(service._lazyEntriesInitFuture, initFuture)) {
          service._lazyEntriesInitFuture = null;
        }
      }
    } finally {
      span.finish(
        details: {
          'awaitedActiveInit': awaitedActiveInit,
          'entriesBoxOpen': service._entriesBox?.isOpen == true,
          'lazyBoxOpen': service._lazyEntriesBox?.isOpen == true,
        },
      );
    }
  }

  Future<void> _ensureDisplayEntriesBox() async {
    final service = _lifecycleService;
    var awaitedActiveInit = false;
    final span = VibePerformanceDiagnostics.start(
      'storage.ensureDisplayEntriesBox',
      details: {'hadDisplayBox': service._displayEntriesBox?.isOpen == true},
    );
    try {
      if (service._displayEntriesBox != null &&
          service._displayEntriesBox!.isOpen) {
        return;
      }

      _registerAdapters();
      final activeInit = service._displayEntriesInitFuture;
      if (activeInit != null) {
        awaitedActiveInit = true;
        await activeInit;
        return;
      }

      final initFuture = _openDisplayEntriesBox().then((box) {
        service._displayEntriesBox = box;
      });
      service._displayEntriesInitFuture = initFuture;
      try {
        await initFuture;
      } catch (e, stackTrace) {
        AppLogger.e(
          'VibeLibrary display cache 初始化失败',
          e,
          stackTrace,
          VibeLibraryStorageService._tag,
        );
        rethrow;
      } finally {
        if (identical(service._displayEntriesInitFuture, initFuture)) {
          service._displayEntriesInitFuture = null;
        }
      }
    } finally {
      span.finish(
        details: {
          'awaitedActiveInit': awaitedActiveInit,
          'displayBoxOpen': service._displayEntriesBox?.isOpen == true,
        },
      );
    }
  }

  Future<void> _ensureThumbnailCacheBox() async {
    final service = _lifecycleService;
    var awaitedActiveInit = false;
    final span = VibePerformanceDiagnostics.start(
      'storage.ensureThumbnailCacheBox',
      details: {
        'hadThumbnailCacheBox': service._thumbnailCacheBox?.isOpen == true,
      },
    );
    try {
      if (service._thumbnailCacheBox != null &&
          service._thumbnailCacheBox!.isOpen) {
        return;
      }

      _registerAdapters();
      final activeInit = service._thumbnailCacheInitFuture;
      if (activeInit != null) {
        awaitedActiveInit = true;
        await activeInit;
        return;
      }

      final initFuture = _openThumbnailCacheBox().then((box) {
        service._thumbnailCacheBox = box;
      });
      service._thumbnailCacheInitFuture = initFuture;
      try {
        await initFuture;
      } catch (e, stackTrace) {
        AppLogger.e(
          'VibeLibrary thumbnail cache 初始化失败',
          e,
          stackTrace,
          VibeLibraryStorageService._tag,
        );
        rethrow;
      } finally {
        if (identical(service._thumbnailCacheInitFuture, initFuture)) {
          service._thumbnailCacheInitFuture = null;
        }
      }
    } finally {
      span.finish(
        details: {
          'awaitedActiveInit': awaitedActiveInit,
          'thumbnailCacheBoxOpen': service._thumbnailCacheBox?.isOpen == true,
        },
      );
    }
  }

  Future<void> _ensureCategoriesBox() async {
    final service = _lifecycleService;
    var awaitedActiveInit = false;
    final span = VibePerformanceDiagnostics.start(
      'storage.ensureCategoriesBox',
      details: {'hadCategoriesBox': service._categoriesBox?.isOpen == true},
    );
    try {
      if (service._categoriesBox != null && service._categoriesBox!.isOpen) {
        return;
      }

      _registerAdapters();
      final activeInit = service._categoriesInitFuture;
      if (activeInit != null) {
        awaitedActiveInit = true;
        await activeInit;
        return;
      }

      final initFuture = _openCategoriesBox().then((box) {
        service._categoriesBox = box;
      });
      service._categoriesInitFuture = initFuture;
      try {
        await initFuture;
      } catch (e, stackTrace) {
        AppLogger.e(
          'VibeLibrary categories 初始化失败',
          e,
          stackTrace,
          VibeLibraryStorageService._tag,
        );
        rethrow;
      } finally {
        if (identical(service._categoriesInitFuture, initFuture)) {
          service._categoriesInitFuture = null;
        }
      }
    } finally {
      span.finish(
        details: {
          'awaitedActiveInit': awaitedActiveInit,
          'categoriesBoxOpen': service._categoriesBox?.isOpen == true,
        },
      );
    }
  }

  /// 确保完整条目和分类 Box 已初始化（线程安全）。
  Future<void> _ensureInit() async {
    await VibePerformanceDiagnostics.measure('storage.ensureInit', () async {
      await Future.wait([_ensureEntriesBox(), _ensureCategoriesBox()]);
    });
  }

  Future<bool> _isDisplayCacheReady() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(VibeLibraryStorageService._displayCacheReadyKey) ==
        true;
  }

  Future<void> _setDisplayCacheReady(bool ready) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(VibeLibraryStorageService._displayCacheReadyKey, ready);
  }

  Future<void> _upsertDisplayEntryIfReady(VibeLibraryEntry entry) async {
    final service = _lifecycleService;
    if (!await _isDisplayCacheReady()) {
      return;
    }

    await _ensureDisplayEntriesBox();
    await service._displayEntriesBox!.put(entry.id, entry.toDisplayEntry());
  }

  Future<void> _deleteDisplayEntryIfReady(String id) async {
    final service = _lifecycleService;
    if (!await _isDisplayCacheReady()) {
      return;
    }

    await _ensureDisplayEntriesBox();
    await service._displayEntriesBox!.delete(id);
  }

  Future<void> _deleteDisplayThumbnailCache(String id) async {
    final service = _lifecycleService;
    await _ensureThumbnailCacheBox();
    await service._thumbnailCacheBox!.delete(id);
  }

  /// 关闭存储（清理资源）
  Future<void> close() async {
    final service = _lifecycleService;
    try {
      if (service._entriesBox != null && service._entriesBox!.isOpen) {
        await service._entriesBox!.close();
      }
      if (service._lazyEntriesBox != null && service._lazyEntriesBox!.isOpen) {
        await service._lazyEntriesBox!.close();
      }
      if (service._displayEntriesBox != null &&
          service._displayEntriesBox!.isOpen) {
        await service._displayEntriesBox!.close();
      }
      if (service._thumbnailCacheBox != null &&
          service._thumbnailCacheBox!.isOpen) {
        await service._thumbnailCacheBox!.close();
      }
      if (service._categoriesBox != null && service._categoriesBox!.isOpen) {
        await service._categoriesBox!.close();
      }
      AppLogger.d('VibeLibraryStorageService closed', 'VibeLibrary');
    } catch (e, stackTrace) {
      AppLogger.e('Failed to close storage: $e', 'VibeLibrary', stackTrace);
    }
  }
}
