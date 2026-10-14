import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final targetOS = input.config.code.targetOS;
    // ELF links accept unresolved symbols, and bionic keeps libspng's pow() in
    // libm; without both settings the library only fails at dlopen on device.
    final isElfTarget = targetOS == OS.android || targetOS == OS.linux;
    await CBuilder.library(
      name: 'nai_png_codec',
      assetName: 'nai_png_codec.dart',
      sources: [
        'src/nai_png_codec.c',
        'src/vendor/libspng/spng.c',
        'src/vendor/miniz/miniz.c',
        'src/vendor/miniz/miniz_tdef.c',
        'src/vendor/miniz/miniz_tinfl.c',
      ],
      includes: ['src', 'src/vendor/libspng', 'src/vendor/miniz'],
      defines: {
        'SPNG_STATIC': null,
        'SPNG_USE_MINIZ': null,
        'MINIZ_NO_ARCHIVE_APIS': null,
        'MINIZ_NO_STDIO': null,
        'MINIZ_NO_TIME': null,
      },
      libraries: [if (isElfTarget) 'm'],
      flags: [if (isElfTarget) '-Wl,--no-undefined'],
    ).run(input: input, output: output);
  });
}
