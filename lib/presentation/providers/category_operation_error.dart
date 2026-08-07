import '../../l10n/app_localizations.dart';

enum CategoryOperationErrorCode {
  loadFailed,
  syncFailed,
  nameEmpty,
  parentNotFound,
  createFailed,
  categoryNotFound,
  renameFailed,
  invalidMove,
  moveFailed,
  hasSubcategories,
  deleteFailed,
  moveImageFailed,
  moveImagesFailed,
  reorderFailed,
}

class CategoryOperationError {
  const CategoryOperationError(this.code, {this.details});

  final CategoryOperationErrorCode code;
  final String? details;

  String localized(AppLocalizations l10n) {
    return switch (code) {
      CategoryOperationErrorCode.loadFailed => l10n.categoryError_loadFailed(
        details ?? '',
      ),
      CategoryOperationErrorCode.syncFailed => l10n.categoryError_syncFailed(
        details ?? '',
      ),
      CategoryOperationErrorCode.nameEmpty => l10n.categoryError_nameEmpty,
      CategoryOperationErrorCode.parentNotFound =>
        l10n.categoryError_parentNotFound,
      CategoryOperationErrorCode.createFailed =>
        l10n.categoryError_createFailed(details ?? ''),
      CategoryOperationErrorCode.categoryNotFound =>
        l10n.categoryError_notFound,
      CategoryOperationErrorCode.renameFailed =>
        l10n.categoryError_renameFailed(details ?? ''),
      CategoryOperationErrorCode.invalidMove => l10n.categoryError_invalidMove,
      CategoryOperationErrorCode.moveFailed => l10n.categoryError_moveFailed(
        details ?? '',
      ),
      CategoryOperationErrorCode.hasSubcategories =>
        l10n.categoryError_hasSubcategories,
      CategoryOperationErrorCode.deleteFailed =>
        l10n.categoryError_deleteFailed(details ?? ''),
      CategoryOperationErrorCode.moveImageFailed =>
        l10n.categoryError_moveImageFailed(details ?? ''),
      CategoryOperationErrorCode.moveImagesFailed =>
        l10n.categoryError_moveImagesFailed(details ?? ''),
      CategoryOperationErrorCode.reorderFailed =>
        l10n.categoryError_reorderFailed(details ?? ''),
    };
  }
}
