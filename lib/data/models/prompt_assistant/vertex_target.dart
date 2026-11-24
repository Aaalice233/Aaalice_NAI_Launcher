/// Vertex AI 的项目与区域；项目留空时取凭据自带的项目。
class VertexTarget {
  static const defaultLocation = 'global';

  final String projectId;
  final String location;

  const VertexTarget({this.projectId = '', this.location = defaultLocation});

  /// 区域会拼进主机名，只接受 GCP 区域名的字符集。
  static final _locationPattern = RegExp(r'^[a-z][a-z0-9-]{0,62}$');

  static bool isValidLocation(String value) =>
      _locationPattern.hasMatch(value.trim());

  String get effectiveLocation {
    final trimmed = location.trim();
    return trimmed.isEmpty ? defaultLocation : trimmed;
  }

  VertexTarget copyWith({String? projectId, String? location}) {
    return VertexTarget(
      projectId: projectId ?? this.projectId,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() => {
    'projectId': projectId,
    'location': location,
  };

  factory VertexTarget.fromJson(Map<String, dynamic> json) {
    return VertexTarget(
      projectId: (json['projectId'] as String? ?? '').trim(),
      location: (json['location'] as String? ?? defaultLocation).trim(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VertexTarget &&
      other.projectId == projectId &&
      other.location == location;

  @override
  int get hashCode => Object.hash(projectId, location);
}
