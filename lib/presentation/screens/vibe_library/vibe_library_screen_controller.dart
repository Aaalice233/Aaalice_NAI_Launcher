import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

import '../../../data/models/vibe/vibe_import_progress.dart';

class VibeLibraryScreenController extends ChangeNotifier {
  VibeLibraryScreenController({
    Future<List<PlatformFile>?> Function()? pickImportFiles,
    required Future<void> Function(String query) onSearch,
  }) : _injectedPicker = pickImportFiles,
       _onSearch = onSearch;

  final Future<List<PlatformFile>?> Function()? _injectedPicker;
  final Future<void> Function(String query) _onSearch;

  final TextEditingController searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _showCategoryPanel = true;
  bool _isDragging = false;
  bool _isImporting = false;
  bool _isPickingFile = false;
  bool _isMarkingEncodingModel = false;
  ImportProgress _importProgress = const ImportProgress();
  Set<String>? _reservedImportNames;
  int _operationEpoch = 0;
  bool _dialogLocked = false;

  bool get showCategoryPanel => _showCategoryPanel;
  bool get isDragging => _isDragging;
  bool get isImporting => _isImporting;
  bool get isPickingFile => _isPickingFile;
  bool get isMarkingEncodingModel => _isMarkingEncodingModel;
  bool get isBusy => _isImporting || _isPickingFile;
  ImportProgress get importProgress => _importProgress;
  int get operationEpoch => _operationEpoch;

  void toggleCategoryPanel() {
    _showCategoryPanel = !_showCategoryPanel;
    notifyListeners();
  }

  void setDragging(bool value) {
    if (_isDragging == value) return;
    _isDragging = value;
    notifyListeners();
  }

  void searchChanged(String value) {
    notifyListeners();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_onSearch(value));
    });
  }

  Future<void> submitSearch(String value) => _onSearch(value);

  Future<void> clearSearch() async {
    _searchDebounce?.cancel();
    searchController.clear();
    notifyListeners();
    await _onSearch('');
  }

  int beginOperation({ImportProgress progress = const ImportProgress()}) {
    _operationEpoch++;
    _isImporting = true;
    _importProgress = progress;
    notifyListeners();
    return _operationEpoch;
  }

  bool isCurrentOperation(int epoch) => epoch == _operationEpoch;

  void updateProgress(int epoch, ImportProgress progress) {
    if (!isCurrentOperation(epoch)) return;
    _importProgress = progress;
    notifyListeners();
  }

  void finishOperation(int epoch) {
    if (!isCurrentOperation(epoch)) return;
    _isImporting = false;
    _importProgress = const ImportProgress();
    notifyListeners();
  }

  void setMarkingEncodingModel(bool value) {
    if (_isMarkingEncodingModel == value) return;
    _isMarkingEncodingModel = value;
    notifyListeners();
  }

  void beginImportSession(Iterable<String> existingNames) {
    _reservedImportNames = existingNames
        .map((name) => name.toLowerCase())
        .toSet();
  }

  void endImportSession() {
    _reservedImportNames = null;
  }

  String reserveUniqueName(String baseName) {
    final names = _reservedImportNames ?? <String>{};
    final normalized = baseName.toLowerCase();
    if (names.add(normalized)) return baseName;

    var index = 2;
    while (!names.add('$normalized ($index)')) {
      index++;
    }
    return '$baseName ($index)';
  }

  Future<List<PlatformFile>?> pickFiles({
    required List<String> allowedExtensions,
    required String dialogTitle,
    bool allowMultiple = true,
    bool useInjectedPicker = true,
  }) async {
    if (_isPickingFile) return null;
    _isPickingFile = true;
    notifyListeners();
    try {
      if (useInjectedPicker && _injectedPicker != null) {
        return await _injectedPicker();
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        dialogTitle: dialogTitle,
        withData: false,
        lockParentWindow: true,
      );
      return result?.files;
    } finally {
      _isPickingFile = false;
      notifyListeners();
    }
  }

  Future<T?> runDialogLocked<T>(Future<T?> Function() showDialog) async {
    if (_dialogLocked) return null;
    _dialogLocked = true;
    try {
      return await showDialog();
    } finally {
      _dialogLocked = false;
    }
  }

  @override
  void dispose() {
    _operationEpoch++;
    _searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }
}
