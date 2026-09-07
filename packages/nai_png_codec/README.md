# Native PNG codec

Launcher uses this local Dart code asset on Windows, Android and macOS. The build
hook compiles the checked-in C sources with the target toolchain; it does not
download native binaries or sources during a build.

- `libspng` 0.7.4 handles still PNG decoding, filtering and encoding.
- `miniz` 3.0.2 supplies its supported zlib-compatible backend.
- Source URLs and SHA-256 hashes are recorded in `source_lock.json`. Upstream
  source files are unchanged. `src/miniz_export.h` configures private linkage.
- The library is built with native compiler optimization, including in Flutter
  debug mode. The shared library is bundled through Dart code assets.

`sanitizePngPixels` expects the caller to have removed non-rendering ancillary
chunks and trailing bytes. It decodes without gamma conversion, preserves RGB
samples, clears only the least significant Alpha bit, and retains 16-bit sample
precision. PNGs whose pixels already need no change keep their compressed data.
Changed pixels are encoded with compression level 1 and the Sub filter.

APNG is deliberately handled by Launcher's frame-aware Dart decoder/encoder;
libspng must never silently flatten an animation to its first frame. Native
failures propagate to the caller, with no unprotected-data fallback. A decoded
RGBA image over 512 MiB fails explicitly before pixel allocation.

The `LICENSE` file includes the complete upstream license texts for distribution.
