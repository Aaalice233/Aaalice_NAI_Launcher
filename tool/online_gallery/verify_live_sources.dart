import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

const _userAgent =
    'Aaalice-NAI-Launcher/online-gallery-contract-check (+https://github.com/Aaalice-Team/Aaalice_NAI_Launcher)';

Future<void> main() async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(seconds: 30),
      headers: const {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
        // Several gallery CDNs negotiate zstd, which dart:io does not decode.
        'Accept-Encoding': 'identity',
      },
    ),
  );
  final checks = <String, Future<void> Function(Dio)>{
    'Safebooru search, media, and rankings': _verifySafebooru,
    'AI TAG config, search, rankings, detail, and CDN': _verifyAiTag,
    'Danbooru public read': _verifyDanbooru,
    'Gelbooru public read': _verifyGelbooru,
  };
  var failures = 0;
  for (final entry in checks.entries) {
    stdout.write('• ${entry.key} ... ');
    try {
      await entry.value(dio);
      stdout.writeln('OK');
    } catch (error, stack) {
      failures++;
      stdout.writeln('FAILED');
      stderr.writeln('  $error');
      if (Platform.environment['GITHUB_ACTIONS'] != 'true') {
        stderr.writeln(stack);
      }
    }
  }
  dio.close(force: true);
  if (failures > 0) {
    stderr.writeln('$failures live source contract check(s) failed.');
    exitCode = 1;
  } else {
    stdout.writeln('All online gallery live source contracts passed.');
  }
}

Future<void> _verifySafebooru(Dio dio) async {
  const base = 'https://safebooru.donmai.us';
  final search = _list(
    await _getJson(
      dio,
      '$base/posts.json',
      query: const {'tags': '1girl', 'limit': 20, 'page': 1},
    ),
    'Safebooru /posts.json',
  );
  _require(search.isNotEmpty, 'Safebooru search returned no posts');
  String? imageUrl;
  for (final value in search) {
    final post = _map(value, 'Safebooru post');
    final candidate = _optionalFirstUrl(post, const [
      'file_url',
      'large_file_url',
      'preview_file_url',
    ]);
    if (_looksLikeImageUrl(candidate)) {
      imageUrl = candidate;
      break;
    }
  }
  _require(imageUrl != null, 'Safebooru search returned no image post');
  await _verifyMedia(dio, imageUrl!, 'Safebooru image');

  final date = _utcDate(DateTime.now().toUtc());
  for (final scale in const ['day', 'week', 'month']) {
    final page1 = _list(
      await _getJson(
        dio,
        '$base/explore/posts/popular.json',
        query: {'scale': scale, 'date': date, 'page': 1},
      ),
      'Safebooru $scale ranking page 1',
    );
    final page2 = _list(
      await _getJson(
        dio,
        '$base/explore/posts/popular.json',
        query: {'scale': scale, 'date': date, 'page': 2},
      ),
      'Safebooru $scale ranking page 2',
    );
    _require(page1.isNotEmpty, 'Safebooru $scale ranking page 1 is empty');
    _require(page2.isNotEmpty, 'Safebooru $scale ranking page 2 is empty');
    _requireNoOverlap(page1, page2, 'Safebooru $scale ranking');
  }
}

Future<void> _verifyAiTag(Dio dio) async {
  const base = 'https://aitag.win';
  final config = _map(await _getJson(dio, '$base/api/config'), 'AI TAG config');
  final assetBase = config['asset_base_url']?.toString() ?? '';
  _require(
    Uri.tryParse(assetBase)?.isAbsolute == true,
    'Invalid asset_base_url',
  );
  final pageSize = _int(config['page_size']) ?? 60;
  _require(pageSize >= 60, 'AI TAG page_size must be at least 60');
  final months = _stringList(config['available_months']);
  _require(months.isNotEmpty, 'AI TAG available_months is empty');

  await _verifyAiSearch(dio, base, pageSize, q: 'NAI');
  await _verifyAiSearch(dio, base, pageSize, prompt: '::artist:');
  await _verifyAiSearch(dio, base, pageSize, q: 'NAI', prompt: '::artist:');

  final firstPage = _map(
    await _getJson(
      dio,
      '$base/api/ai_works_search',
      query: {
        'page': 1,
        'page_size': pageSize,
        'sort': 'new',
        'time_range': 'all',
      },
    ),
    'AI TAG search page 1',
  );
  final secondPage = _map(
    await _getJson(
      dio,
      '$base/api/ai_works_search',
      query: {
        'page': 2,
        'page_size': pageSize,
        'sort': 'new',
        'time_range': 'all',
      },
    ),
    'AI TAG search page 2',
  );
  final page1Items = _list(firstPage['items'], 'AI TAG search items page 1');
  final page2Items = _list(secondPage['items'], 'AI TAG search items page 2');
  _require(page1Items.isNotEmpty, 'AI TAG search page 1 is empty');
  _require(page2Items.isNotEmpty, 'AI TAG search page 2 is empty');
  _requireNoOverlap(page1Items, page2Items, 'AI TAG search');
  final total = _int(firstPage['total']);
  _require(
    total != null && total > page1Items.length,
    'AI TAG total is missing',
  );

  await _verifyAiRank(
    dio,
    '$base/api/rank/monthly/real',
    {'page': 1, 'page_size': pageSize},
    'AI TAG live monthly ranking',
    allowProcessing: true,
  );
  await _verifyAiRank(
    dio,
    '$base/api/rank/monthly/fixed',
    {'page': 1, 'page_size': pageSize, 'month': months.first},
    'AI TAG fixed monthly ranking ${months.first}',
  );
  await _verifyAiRank(dio, '$base/api/rank/monthly/fixed', {
    'page': 1,
    'page_size': pageSize,
    'month': 'older',
  }, 'AI TAG older monthly archive');

  final work = _map(page1Items.first, 'AI TAG work');
  final workId = _int(work['id']);
  _require(workId != null && workId > 0, 'AI TAG work id is invalid');
  final detail = _map(
    await _getJson(dio, '$base/api/work/$workId'),
    'AI TAG work detail',
  );
  final images = _list(detail['images'], 'AI TAG detail images');
  _require(images.isNotEmpty, 'AI TAG detail has no images');
  final sorted = [...images]
    ..sort(
      (a, b) => _pageIndex(
        _map(a, 'AI TAG image')['file_name'],
      ).compareTo(_pageIndex(_map(b, 'AI TAG image')['file_name'])),
    );
  final firstImage = _aiCdnUrl(assetBase, _map(sorted.first, 'first AI image'));
  final lastImage = _aiCdnUrl(assetBase, _map(sorted.last, 'last AI image'));
  _require(
    !firstImage.contains('pximg.net'),
    'Pixiv must not be used as CDN fallback',
  );
  await _verifyMedia(dio, firstImage, 'AI TAG first CDN image');
  if (lastImage != firstImage) {
    await _verifyMedia(dio, lastImage, 'AI TAG last CDN image');
  }
}

Future<void> _verifyAiSearch(
  Dio dio,
  String base,
  int pageSize, {
  String? q,
  String? prompt,
}) async {
  final response = _map(
    await _getJson(
      dio,
      '$base/api/ai_works_search',
      query: {
        'page': 1,
        'page_size': pageSize,
        'sort': 'new',
        'time_range': 'all',
        if (q != null) 'q': q,
        if (prompt != null) 'prompt': prompt,
      },
    ),
    'AI TAG q/prompt search',
  );
  _list(response['items'], 'AI TAG q/prompt items');
  _require(_int(response['total']) != null, 'AI TAG search total is missing');
}

Future<void> _verifyAiRank(
  Dio dio,
  String url,
  Map<String, Object?> query,
  String label, {
  bool allowProcessing = false,
}) async {
  final response = _map(
    await _getJson(dio, url, query: query, acceptErrorJson: allowProcessing),
    label,
  );
  if (response['error'] == 'rank_processing' ||
      response['status'] == 'rank_processing') {
    _require(allowProcessing, '$label unexpectedly reports rank_processing');
    stdout.write('(rank_processing contract recognized) ');
    return;
  }
  final items = _list(response['items'], '$label items');
  _require(items.isNotEmpty, '$label returned no items');
  _require(_int(response['total']) != null, '$label total is missing');
}

Future<void> _verifyDanbooru(Dio dio) async {
  final posts = _list(
    await _getJson(
      dio,
      'https://danbooru.donmai.us/posts.json',
      query: const {'tags': 'rating:g', 'limit': 1, 'page': 1},
    ),
    'Danbooru posts',
  );
  _require(posts.isNotEmpty, 'Danbooru public search returned no posts');
  _require(
    _int(_map(posts.first, 'Danbooru post')['id']) != null,
    'Invalid post id',
  );
}

Future<void> _verifyGelbooru(Dio dio) async {
  // Gelbooru's public DAPI requires credentials. The app's anonymous read path
  // intentionally uses the same public HTML list verified here.
  final response = await dio.get<String>(
    'https://gelbooru.com/index.php',
    queryParameters: const {
      'page': 'post',
      's': 'list',
      'pid': 0,
      'tags': 'rating:general',
    },
    options: Options(
      responseType: ResponseType.plain,
      headers: const {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'User-Agent': 'Mozilla/5.0 NAI-Launcher/1.0',
        'Referer': 'https://gelbooru.com/',
        'Cookie': 'fringeBenefits=yup',
      },
    ),
  );
  final body = response.data ?? '';
  final ids = RegExp(
    r'''id=["']?p?(\d{4,})''',
  ).allMatches(body).map((match) => match.group(1)).whereType<String>().toSet();
  _require(ids.isNotEmpty, 'Gelbooru public HTML returned no post IDs');
}

Future<Object?> _getJson(
  Dio dio,
  String url, {
  Map<String, Object?>? query,
  bool acceptErrorJson = false,
}) async {
  final response = await dio.get<Object?>(
    url,
    queryParameters: query,
    options: Options(
      responseType: ResponseType.plain,
      validateStatus: (status) =>
          status != null && (status >= 200 && status < 300 || acceptErrorJson),
    ),
  );
  final data = response.data;
  if (data is Map || data is List) return data;
  final body = data?.toString() ?? '';
  try {
    return jsonDecode(body);
  } catch (_) {
    final prefix = body.codeUnits.take(16).join(',');
    throw FormatException(
      '${Uri.parse(url).host} returned non-JSON content '
      '(HTTP ${response.statusCode}, ${body.length} characters, '
      'encoding=${response.headers.value('content-encoding')}, prefix=$prefix)',
    );
  }
}

Future<void> _verifyMedia(Dio dio, String url, String label) async {
  _require(Uri.tryParse(url)?.isAbsolute == true, '$label URL is invalid');
  final response = await dio.get<List<int>>(
    url,
    options: Options(
      responseType: ResponseType.bytes,
      headers: const {'Accept': 'image/avif,image/webp,image/*,*/*;q=0.8'},
    ),
  );
  final bytes = response.data ?? const <int>[];
  _require(
    bytes.length >= 1024,
    '$label response is too small (${bytes.length} bytes)',
  );
  final contentType = response.headers.value(Headers.contentTypeHeader) ?? '';
  _require(
    contentType.startsWith('image/'),
    '$label is not an image ($contentType)',
  );
}

void _requireNoOverlap(
  List<Object?> first,
  List<Object?> second,
  String label,
) {
  final firstIds = first
      .map((item) => _int(_map(item, label)['id']))
      .whereType<int>()
      .toSet();
  final secondIds = second
      .map((item) => _int(_map(item, label)['id']))
      .whereType<int>()
      .toSet();
  _require(
    firstIds.isNotEmpty && secondIds.isNotEmpty,
    '$label has invalid IDs',
  );
  final overlap = firstIds.intersection(secondIds);
  _require(overlap.isEmpty, '$label pages overlap on ${overlap.length} IDs');
}

String _aiCdnUrl(String base, Map<String, Object?> image) {
  final normalizedBase = base.endsWith('/') ? base : '$base/';
  final type = image['image_type']?.toString().trim() ?? '';
  final author = image['author_id']?.toString().trim() ?? '';
  final fileName = image['file_name']?.toString().trim() ?? '';
  _require(
    type.isNotEmpty && author.isNotEmpty && fileName.isNotEmpty,
    'Incomplete AI TAG CDN fields',
  );
  return '$normalizedBase$type/$author/$fileName.webp';
}

String? _optionalFirstUrl(Map<String, Object?> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key]?.toString().trim() ?? '';
    if (Uri.tryParse(value)?.isAbsolute == true) return value;
  }
  return null;
}

bool _looksLikeImageUrl(String? value) {
  if (value == null || value.isEmpty) return false;
  final path = Uri.tryParse(value)?.path.toLowerCase() ?? value.toLowerCase();
  return path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.png') ||
      path.endsWith('.gif') ||
      path.endsWith('.webp');
}

Map<String, Object?> _map(Object? value, String label) {
  if (value is! Map) throw FormatException('$label is not an object');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Object?> _list(Object? value, String label) {
  if (value is! List) throw FormatException('$label is not an array');
  return value.cast<Object?>();
}

List<String> _stringList(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : const [];

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

int _pageIndex(Object? value) {
  final match = RegExp(r'_p(\d+)(?:\D|$)').firstMatch(value?.toString() ?? '');
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

String _utcDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}
