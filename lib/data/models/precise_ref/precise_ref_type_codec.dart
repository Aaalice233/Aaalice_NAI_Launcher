import '../../../core/enums/precise_ref_type.dart';

Map<String, Object?> encodePreciseRefType(
  PreciseRefType type, {
  bool? preferSameOutfit,
}) => {
  'type':
      (type == PreciseRefType.costume ? PreciseRefType.character : type).name,
  if (type == PreciseRefType.costume) 'typeV2': type.name,
  if (preferSameOutfit != null) 'preferSameOutfit': preferSameOutfit,
};

PreciseReferenceTypeSettings decodePreciseRefType(Map data) {
  final name = data['typeV2'] ?? data['type'];
  final type = PreciseRefType.values
      .where((type) => type.name == name)
      .firstOrNull;
  final preference = data['preferSameOutfit'];
  if (type == null || (preference != null && preference is! bool)) {
    throw const FormatException('Invalid precise reference type settings');
  }
  return (type: type, preferSameOutfit: preference as bool?);
}
