import '../../data/models/cache/data_source_cache_meta.dart';
import 'lazy_data_source_service.dart';

const danbooruTagsBaseUrl = 'https://danbooru.donmai.us';
const danbooruTagsEndpoint = '/tags.json';
const danbooruTagsPageSize = 1000;
const danbooruTagsMaxPages = 200;
const danbooruTagsConcurrentRequests = 2;
const danbooruTagsRequestInterval = Duration(milliseconds: 500);

const danbooruHotKeys = <String>{
  '1girl',
  'solo',
  '1boy',
  '2girls',
  'multiple_girls',
  '2boys',
  'multiple_boys',
  '3girls',
  '1other',
  '3boys',
  'long_hair',
  'short_hair',
  'blonde_hair',
  'brown_hair',
  'black_hair',
  'blue_eyes',
  'red_eyes',
  'green_eyes',
  'brown_eyes',
  'purple_eyes',
  'looking_at_viewer',
  'smile',
  'open_mouth',
  'blush',
  'breasts',
  'thighhighs',
  'gloves',
  'bow',
  'ribbon',
};

class DanbooruCategoryThresholds {
  const DanbooruCategoryThresholds({
    this.general = 1000,
    this.artist = 500,
    this.character = 100,
    this.copyright = 500,
    this.meta = 10000,
  });

  final int general;
  final int artist;
  final int character;
  final int copyright;
  final int meta;

  DanbooruCategoryThresholds copyWith({
    int? general,
    int? artist,
    int? character,
    int? copyright,
    int? meta,
  }) => DanbooruCategoryThresholds(
    general: general ?? this.general,
    artist: artist ?? this.artist,
    character: character ?? this.character,
    copyright: copyright ?? this.copyright,
    meta: meta ?? this.meta,
  );
}

class DanbooruTagsState {
  bool isInitialized = false;
  bool isRefreshing = false;
  DateTime? lastUpdate;
  DanbooruCategoryThresholds thresholds = const DanbooruCategoryThresholds();
  AutoRefreshInterval refreshInterval = AutoRefreshInterval.days30;
  DataSourceProgressCallback? onProgress;
}

class DanbooruRefreshCancelledException implements Exception {
  const DanbooruRefreshCancelledException();

  @override
  String toString() => '用户取消同步';
}

class DanbooruRefreshGeneration {
  DanbooruRefreshGeneration(this._owner, this.id);

  final DanbooruRefreshGenerationOwner _owner;
  final int id;

  bool get isCancelled => !_owner.isCurrent(id);

  void throwIfCancelled() {
    if (isCancelled) throw const DanbooruRefreshCancelledException();
  }
}

class DanbooruRefreshGenerationOwner {
  int _generation = 0;

  DanbooruRefreshGeneration begin() =>
      DanbooruRefreshGeneration(this, ++_generation);

  void cancel() {
    _generation++;
  }

  bool isCurrent(int generation) => generation == _generation;
}
