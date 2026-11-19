import 'image_detail_data.dart';

sealed class ImageDetailDeleteResult {
  const ImageDetailDeleteResult();
}

class ImageDetailDeletePage extends ImageDetailDeleteResult {
  const ImageDetailDeletePage(this.images, {required this.previousPage});

  final List<ImageDetailData> images;
  final bool previousPage;

  int indexAfterRemoving(List<ImageDetailData> oldPage, int deletedIndex) {
    final last = images.length - 1;
    if (previousPage) return last;
    final wasLast = deletedIndex == oldPage.length - 1;
    if (!wasLast) {
      final nextId = oldPage[deletedIndex + 1].identifier;
      final next = images.indexWhere((image) => image.identifier == nextId);
      if (next >= 0) return next;
    }
    if (deletedIndex > 0) {
      final previousId = oldPage[deletedIndex - 1].identifier;
      final previous = images.indexWhere(
        (image) => image.identifier == previousId,
      );
      if (previous >= 0) {
        return wasLast && previous < last ? previous + 1 : previous;
      }
    }
    return deletedIndex.clamp(0, last);
  }
}

class ImageDetailDeletePageError extends ImageDetailDeleteResult {
  const ImageDetailDeletePageError(this.message, {required this.retry});

  final String message;
  final Future<ImageDetailDeleteResult> Function() retry;
}
