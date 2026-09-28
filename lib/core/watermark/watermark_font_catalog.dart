class WatermarkFontOption {
  const WatermarkFontOption({
    required this.family,
    required this.sample,
    required this.supportsCjk,
  });

  final String family;
  final String sample;
  final bool supportsCjk;
}

class WatermarkFontCatalog {
  const WatermarkFontCatalog._();

  static const options = <WatermarkFontOption>[
    WatermarkFontOption(
      family: 'LXGW ZhenKai GB',
      sample: 'Aaalice 水印',
      supportsCjk: true,
    ),
    WatermarkFontOption(
      family: 'Ma Shan Zheng',
      sample: 'Aaalice 山水',
      supportsCjk: true,
    ),
    WatermarkFontOption(
      family: 'Zhi Mang Xing',
      sample: 'Aaalice 行书',
      supportsCjk: true,
    ),
    WatermarkFontOption(
      family: 'Long Cang',
      sample: 'Aaalice 墨迹',
      supportsCjk: true,
    ),
    WatermarkFontOption(
      family: 'Great Vibes',
      sample: 'Aaalice Signature',
      supportsCjk: false,
    ),
    WatermarkFontOption(
      family: 'Caveat',
      sample: 'Aaalice Studio',
      supportsCjk: false,
    ),
    WatermarkFontOption(
      family: 'Allura',
      sample: 'Aaalice Art',
      supportsCjk: false,
    ),
  ];

  static const fallbackFamilies = <String>[
    'LXGW ZhenKai GB',
    'Ma Shan Zheng',
    'Zhi Mang Xing',
    'Long Cang',
  ];

  static bool contains(String family) =>
      options.any((option) => option.family == family);
}
