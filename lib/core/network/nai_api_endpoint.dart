import '../constants/api_constants.dart';

/// NAI-compatible API endpoint configuration.
///
/// Official NovelAI uses separate main and image API hosts. Third-party
/// compatible sites often expose both sets of endpoints under one base URL, so
/// [fromInput] falls back to [mainBaseUrl] when [imageBaseUrl] is omitted.
class NaiApiEndpointConfig {
  final String mainBaseUrl;
  final String imageBaseUrl;

  const NaiApiEndpointConfig({
    required this.mainBaseUrl,
    required this.imageBaseUrl,
  });

  static const official = NaiApiEndpointConfig(
    mainBaseUrl: ApiConstants.baseUrl,
    imageBaseUrl: ApiConstants.imageBaseUrl,
  );

  factory NaiApiEndpointConfig.fromInput({
    required String mainBaseUrl,
    String? imageBaseUrl,
  }) {
    final normalizedMain = _normalizeBaseUrl(mainBaseUrl);
    final normalizedImage = imageBaseUrl == null || imageBaseUrl.trim().isEmpty
        ? normalizedMain
        : _normalizeBaseUrl(imageBaseUrl);

    return NaiApiEndpointConfig(
      mainBaseUrl: normalizedMain,
      imageBaseUrl: normalizedImage,
    );
  }

  factory NaiApiEndpointConfig.fromJson(Map<String, dynamic> json) {
    return NaiApiEndpointConfig.fromInput(
      mainBaseUrl: json['mainBaseUrl'] as String? ?? ApiConstants.baseUrl,
      imageBaseUrl:
          json['imageBaseUrl'] as String? ?? ApiConstants.imageBaseUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'mainBaseUrl': mainBaseUrl,
    'imageBaseUrl': imageBaseUrl,
  };

  bool get isOfficial =>
      mainBaseUrl == ApiConstants.baseUrl &&
      imageBaseUrl == ApiConstants.imageBaseUrl;

  bool get isThirdParty => !isOfficial;

  String mainUrl(String endpoint) => _appendEndpoint(mainBaseUrl, endpoint);

  String imageUrl(String endpoint) => _appendEndpoint(imageBaseUrl, endpoint);

  /// Official user endpoints are served by the image API host.
  ///
  /// This includes `/user/login`, `/user/information`, `/user/data`, and
  /// `/user/subscription`. NAI-compatible third-party sites keep using
  /// [mainBaseUrl] because their endpoint layout is provider-specific.
  String userUrl(String endpoint) {
    return isOfficial ? imageUrl(endpoint) : mainUrl(endpoint);
  }

  static String _appendEndpoint(String baseUrl, String endpoint) {
    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '/$endpoint';
    return '$baseUrl$normalizedEndpoint';
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('API 地址不能为空');
    }

    final withScheme = _withDefaultScheme(trimmed);
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAuthority) {
      throw ArgumentError('API 地址无效');
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError('仅支持 http 或 https API 地址');
    }

    if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) {
      throw ArgumentError('API 地址不能包含查询参数、片段或用户信息');
    }

    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    return uri.replace(path: path.isEmpty ? '' : path).toString();
  }

  static String _withDefaultScheme(String value) {
    if (value.contains('://')) {
      return value;
    }

    final hostPart = value.split('/').first.toLowerCase();
    final isLocalHost =
        hostPart == 'localhost' ||
        hostPart.startsWith('localhost:') ||
        hostPart == '127.0.0.1' ||
        hostPart.startsWith('127.0.0.1:') ||
        hostPart == '[::1]' ||
        hostPart.startsWith('[::1]:');

    return '${isLocalHost ? 'http' : 'https'}://$value';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NaiApiEndpointConfig &&
          runtimeType == other.runtimeType &&
          mainBaseUrl == other.mainBaseUrl &&
          imageBaseUrl == other.imageBaseUrl;

  @override
  int get hashCode => Object.hash(mainBaseUrl, imageBaseUrl);

  @override
  String toString() {
    return 'NaiApiEndpointConfig(mainBaseUrl: $mainBaseUrl, imageBaseUrl: $imageBaseUrl)';
  }
}
