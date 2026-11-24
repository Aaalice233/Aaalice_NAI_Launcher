import 'package:html/parser.dart' as html_parser;

import '../../models/online_gallery/gallery_item.dart';

Iterable<String> positiveGalleryCharacterTags(
  Iterable<GalleryMedia> media, {
  Iterable<GalleryCharacterPrompt> workPrompts = const [],
}) => workPrompts
    .followedBy(media.expand((image) => image.characterPrompts))
    .expand((character) => parseGalleryPromptTags(character.prompt));

Iterable<String> parseGalleryPromptTags(String raw) => galleryPlainText(raw)
    .split(RegExp(r'[,\n]+'))
    .map(cleanGalleryPromptTag)
    .where((tag) => tag.isNotEmpty && tag.length <= 200);

String cleanGalleryPromptTag(String raw) {
  var value = raw.trim();
  value = value.replaceAll(RegExp(r'^[{}\[\]()\s]+|[{}\[\]()\s]+$'), '');
  value = value.replaceFirst(RegExp(r'^-?\d+(?:\.\d+)?::'), '');
  value = value.replaceFirst(RegExp(r'::$'), '');
  value = value.replaceFirst(RegExp(r'::-?\d+(?:\.\d+)?$'), '');
  value = value.replaceFirst(RegExp(r':-?\d+(?:\.\d+)?$'), '');
  value = value.replaceAll(RegExp(r'^[{}\[\]()\s]+|[{}\[\]()\s,，;；]+$'), '');
  return value.trim();
}

String galleryPlainText(String html) {
  if (html.isEmpty) return '';
  final withBreaks = html.replaceAll(
    RegExp(r'<br\s*/?>', caseSensitive: false),
    '\n',
  );
  return html_parser.parseFragment(withBreaks).text?.trim() ?? '';
}
