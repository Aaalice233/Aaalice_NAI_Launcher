class GelbooruCredentials {
  final int userId;
  final String apiKey;

  const GelbooruCredentials({required this.userId, required this.apiKey});

  factory GelbooruCredentials.fromJson(Map<String, dynamic> json) {
    final rawUserId = json['userId'];
    final userId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');
    final apiKey = json['apiKey']?.toString() ?? '';
    if (userId == null || userId <= 0 || apiKey.trim().isEmpty) {
      throw const FormatException('Invalid Gelbooru credentials');
    }
    return GelbooruCredentials(userId: userId, apiKey: apiKey.trim());
  }

  Map<String, dynamic> toJson() => {'userId': userId, 'apiKey': apiKey};

  bool hasSameValues(GelbooruCredentials other) {
    return userId == other.userId && apiKey == other.apiKey;
  }
}
