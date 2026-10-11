import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

typedef _OpenClipboardNative = Int32 Function(Pointer<Void> hWndNewOwner);
typedef _OpenClipboardDart = int Function(Pointer<Void> hWndNewOwner);

typedef _CloseClipboardNative = Int32 Function();
typedef _CloseClipboardDart = int Function();

typedef _IsClipboardFormatAvailableNative = Int32 Function(Uint32 format);
typedef _IsClipboardFormatAvailableDart = int Function(int format);

typedef _GetClipboardDataNative = Pointer<Void> Function(Uint32 format);
typedef _GetClipboardDataDart = Pointer<Void> Function(int format);

typedef _GlobalLockNative = Pointer<Uint8> Function(Pointer<Void> hMem);
typedef _GlobalLockDart = Pointer<Uint8> Function(Pointer<Void> hMem);

typedef _GlobalUnlockNative = Int32 Function(Pointer<Void> hMem);
typedef _GlobalUnlockDart = int Function(Pointer<Void> hMem);

typedef _GlobalSizeNative = IntPtr Function(Pointer<Void> hMem);
typedef _GlobalSizeDart = int Function(Pointer<Void> hMem);

/// 其它进程持续占用剪贴板，重试后仍无法打开。
final class WindowsClipboardBusyException implements Exception {
  const WindowsClipboardBusyException();

  @override
  String toString() => 'WindowsClipboardBusyException: clipboard is locked';
}

/// 通过 Win32 剪贴板读取系统合成的 CF_DIB。
///
/// 剪贴板历史恢复的图片只以 GDI 位图挂在 OLE 数据对象上，super_clipboard
/// 只识别 HGLOBAL/IStream 介质而读不到；Win32 层会由 CF_BITMAP 合成 CF_DIB。
abstract final class WindowsClipboardBitmapReader {
  static const int _cfDib = 8;
  static const int _openAttempts = 10;
  static const Duration _openRetryDelay = Duration(milliseconds: 20);

  static bool get isSupported => Platform.isWindows;

  /// 剪贴板没有位图时返回 null；重试打开剪贴板时会阻塞线程，只能在后台 isolate 调用。
  static Uint8List? readDib() {
    final user32 = DynamicLibrary.open('user32.dll');
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final openClipboard = user32
        .lookupFunction<_OpenClipboardNative, _OpenClipboardDart>(
          'OpenClipboard',
        );
    final closeClipboard = user32
        .lookupFunction<_CloseClipboardNative, _CloseClipboardDart>(
          'CloseClipboard',
        );
    final isClipboardFormatAvailable = user32
        .lookupFunction<
          _IsClipboardFormatAvailableNative,
          _IsClipboardFormatAvailableDart
        >('IsClipboardFormatAvailable');
    final getClipboardData = user32
        .lookupFunction<_GetClipboardDataNative, _GetClipboardDataDart>(
          'GetClipboardData',
        );
    final globalLock = kernel32
        .lookupFunction<_GlobalLockNative, _GlobalLockDart>('GlobalLock');
    final globalUnlock = kernel32
        .lookupFunction<_GlobalUnlockNative, _GlobalUnlockDart>('GlobalUnlock');
    final globalSize = kernel32
        .lookupFunction<_GlobalSizeNative, _GlobalSizeDart>('GlobalSize');

    if (isClipboardFormatAvailable(_cfDib) == 0) return null;
    if (!_open(openClipboard)) {
      throw const WindowsClipboardBusyException();
    }
    try {
      final handle = getClipboardData(_cfDib);
      if (handle == nullptr) return null;
      final size = globalSize(handle);
      final data = globalLock(handle);
      if (data == nullptr) return null;
      try {
        return Uint8List.fromList(data.asTypedList(size));
      } finally {
        globalUnlock(handle);
      }
    } finally {
      closeClipboard();
    }
  }

  static bool _open(_OpenClipboardDart openClipboard) {
    // 其它进程正在写剪贴板时 OpenClipboard 会短暂失败。
    for (var attempt = 0; attempt < _openAttempts; attempt++) {
      if (openClipboard(nullptr) != 0) return true;
      sleep(_openRetryDelay);
    }
    return false;
  }
}
