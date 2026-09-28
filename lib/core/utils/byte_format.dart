/// 字节大小与速率格式化工具。
library;

/// 将字节数格式化为易读字符串，如 `12.3 MB`。
String formatBytes(int bytes) {
  if (bytes < 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  if (unitIndex == 0) return '${value.round()} ${units[unitIndex]}';
  return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
}

/// 将字节/秒格式化为易读速率，如 `3.2 MB/s`。
String formatBytesPerSecond(int bytesPerSecond) =>
    '${formatBytes(bytesPerSecond)}/s';
