import 'dart:typed_data';

import 'danbooru_post.dart';

List<DanbooruPost> parseGelbooruHtmlPosts(String html) {
  final articles = RegExp(
    r'<article\b[^>]*\bthumbnail-preview\b[^>]*>.*?</article>',
    caseSensitive: false,
    dotAll: true,
  ).allMatches(html);

  final posts = <DanbooruPost>[];
  for (final articleMatch in articles) {
    final article = articleMatch.group(0)!;
    final idText = RegExp(
      r'''<a\b[^>]*\bid=["']p(\d+)["']''',
      caseSensitive: false,
    ).firstMatch(article)?.group(1);
    final id = parseBooruInt(idText);
    if (id == null) continue;

    final imgTag = RegExp(
      r'<img\b[^>]*>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(article)?.group(0);
    if (imgTag == null) continue;

    final previewUrl = _htmlAttribute(imgTag, 'src');
    if (previewUrl == null || previewUrl.isEmpty) continue;

    final title = _htmlAttribute(imgTag, 'title') ?? '';
    final tags = _extractGelbooruTitleTags(title);
    final score =
        parseBooruInt(
          RegExp(
            r'(?:^|\s)score:([-+]?\d+)(?:\s|$)',
          ).firstMatch(title)?.group(1),
        ) ??
        0;
    final rating = normalizeBooruRating(
      RegExp(r'(?:^|\s)rating:([^\s]+)(?:\s|$)').firstMatch(title)?.group(1),
    );
    final md5 =
        RegExp(
          r'thumbnail_([0-9a-fA-F]{32})\.',
        ).firstMatch(previewUrl)?.group(1) ??
        '';
    final width = parseBooruInt(_htmlAttribute(imgTag, 'width')) ?? 0;
    final height = parseBooruInt(_htmlAttribute(imgTag, 'height')) ?? 0;
    final fileExt = _gelbooruHtmlFileExtension(previewUrl, tags);

    posts.add(
      DanbooruPost(
        id: id,
        site: 'gelbooru',
        score: score,
        md5: md5,
        rating: rating,
        width: width,
        height: height,
        tagString: tags.join(' '),
        fileExt: fileExt,
        previewFileUrl: previewUrl,
      ),
    );
  }

  return posts;
}

String normalizeBooruRating(Object? value) {
  final rating = value?.toString().trim().toLowerCase() ?? '';
  switch (rating) {
    case 'general':
    case 'safe':
    case 'g':
      return 'g';
    case 'sensitive':
    case 's':
      return 's';
    case 'questionable':
    case 'q':
      return 'q';
    case 'explicit':
    case 'e':
      return 'e';
    default:
      return rating.isEmpty ? 'g' : rating;
  }
}

String gelbooruRatingName(String rating) {
  switch (normalizeBooruRating(rating)) {
    case 'g':
      return 'general';
    case 's':
      return 'sensitive';
    case 'q':
      return 'questionable';
    case 'e':
      return 'explicit';
    default:
      return rating;
  }
}

int? parseBooruInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

String asBooruString(Object? value) => value?.toString() ?? '';

String fileExtensionFromUrl(String? url) {
  if (url == null || url.isEmpty) return 'jpg';
  final path = Uri.tryParse(url)?.path ?? url;
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return 'jpg';
  return path.substring(dot + 1).toLowerCase();
}

String _gelbooruHtmlFileExtension(String previewUrl, List<String> tags) {
  final normalizedTags = tags.map((tag) => tag.toLowerCase()).toSet();
  if (normalizedTags.contains('video')) {
    return 'mp4';
  }
  if (normalizedTags.contains('animated')) {
    return 'gif';
  }
  return fileExtensionFromUrl(previewUrl);
}

({int width, int height})? decodeJpegDimensions(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) {
    return null;
  }

  var offset = 2;
  while (offset < bytes.length) {
    while (offset < bytes.length && bytes[offset] != 0xff) {
      offset++;
    }
    while (offset < bytes.length && bytes[offset] == 0xff) {
      offset++;
    }
    if (offset >= bytes.length) break;

    final marker = bytes[offset++];
    if (marker == 0xd9 || marker == 0xda) break;
    if (_isStandaloneJpegMarker(marker)) continue;
    if (offset + 1 >= bytes.length) break;

    final segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
    if (segmentLength < 2 || offset + segmentLength > bytes.length) {
      break;
    }

    if (_isJpegStartOfFrameMarker(marker)) {
      if (segmentLength < 7) return null;
      final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      if (width <= 0 || height <= 0) return null;
      return (width: width, height: height);
    }

    offset += segmentLength;
  }

  return null;
}

List<dynamic> extractPostListFromResponse(dynamic data, String source) {
  if (data is List) return data;
  if (source == 'gelbooru' && data is Map) {
    final posts = data['post'] ?? data['posts'];
    if (posts is List) return posts;
    if (posts is Map) return [posts];
  }
  return const [];
}

bool _isStandaloneJpegMarker(int marker) {
  return marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7);
}

bool _isJpegStartOfFrameMarker(int marker) {
  return (marker >= 0xc0 && marker <= 0xc3) ||
      (marker >= 0xc5 && marker <= 0xc7) ||
      (marker >= 0xc9 && marker <= 0xcb) ||
      (marker >= 0xcd && marker <= 0xcf);
}

String? _htmlAttribute(String tag, String name) {
  final doubleQuoted = RegExp(
    '$name\\s*=\\s*"([^"]*)"',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(tag);
  if (doubleQuoted != null) {
    return _decodeHtmlEntities(doubleQuoted.group(1)!);
  }

  final singleQuoted = RegExp(
    "$name\\s*=\\s*'([^']*)'",
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(tag);
  if (singleQuoted != null) {
    return _decodeHtmlEntities(singleQuoted.group(1)!);
  }

  return null;
}

String _decodeHtmlEntities(String input) {
  var value = input;
  for (var i = 0; i < 3; i++) {
    final previous = value;
    value = value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    value = value.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);|&#(\d+);'), (
      match,
    ) {
      final hex = match.group(1);
      final decimal = match.group(2);
      final codePoint = hex != null
          ? int.tryParse(hex, radix: 16)
          : int.tryParse(decimal ?? '');
      if (codePoint == null || codePoint < 0 || codePoint > 0x10FFFF) {
        return match.group(0)!;
      }
      return String.fromCharCode(codePoint);
    });
    if (value == previous) break;
  }
  return value;
}

List<String> _extractGelbooruTitleTags(String title) {
  return _decodeHtmlEntities(title)
      .trim()
      .split(RegExp(r'\s+'))
      .map((tag) => tag.trim())
      .where(
        (tag) =>
            tag.isNotEmpty &&
            !tag.startsWith('score:') &&
            !tag.startsWith('rating:'),
      )
      .toList();
}
