// Chromium 由大版本号派生 sec-ch-ua 品牌列表的算法。

const List<String> _greaseSeparators = [
  ' ',
  '(',
  ':',
  '-',
  '.',
  '/',
  ')',
  ';',
  '=',
  '?',
  '_',
];

const List<String> _greaseVersions = ['8', '99', '24'];

const List<List<int>> _brandOrders = [
  [0, 1, 2],
  [0, 2, 1],
  [1, 0, 2],
  [1, 2, 0],
  [2, 0, 1],
  [2, 1, 0],
];

const String _chromiumBrand = 'Chromium';
const String _chromeBrand = 'Google Chrome';

/// 生成 `sec-ch-ua` 头的取值。
///
/// 灰色品牌名、灰色版本与三个品牌的排列都以大版本号为种子，手写字符串会在
/// 版本号变化后与真实 Chrome 不符。
String buildChromeSecChUa(int majorVersion) {
  final version = '$majorVersion';
  final greaseBrand =
      'Not'
      '${_greaseSeparators[majorVersion % _greaseSeparators.length]}'
      'A'
      '${_greaseSeparators[(majorVersion + 1) % _greaseSeparators.length]}'
      'Brand';
  final greaseVersion = _greaseVersions[majorVersion % _greaseVersions.length];

  final order = _brandOrders[majorVersion % _brandOrders.length];
  final brands = List<String>.filled(3, '');
  brands[order[0]] = _formatBrand(greaseBrand, greaseVersion);
  brands[order[1]] = _formatBrand(_chromiumBrand, version);
  brands[order[2]] = _formatBrand(_chromeBrand, version);

  return brands.join(', ');
}

String _formatBrand(String brand, String version) => '"$brand";v="$version"';
