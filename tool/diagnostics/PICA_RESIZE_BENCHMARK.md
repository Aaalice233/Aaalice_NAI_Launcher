# Pica Resize Benchmark

Recorded on 2026-07-16 from the release AOT executable produced by:

```powershell
dart compile exe tool/diagnostics/pica_resize_benchmark.dart -o C:\tmp\pica_resize_benchmark.exe
C:\tmp\pica_resize_benchmark.exe --iterations=3
```

The figures are medians of three runs on the development Windows machine. RSS
is the maximum process RSS observed immediately after a resize sample. Absolute
times are machine-dependent and are not CI acceptance thresholds.

| Case | Pica Lanczos3 | Previous local Lanczos3 | Max observed RSS |
| --- | ---: | ---: | ---: |
| `4096x4096 -> 896x896` | 217.2 ms | 1.01 s | 109.0 MiB |
| `8000x6000 -> 1216x896` | 893.7 ms | 1.92 s | 237.2 MiB |
| `2559x1439 -> 2560x1472` | 158.6 ms | 6.59 s | 96.5 MiB |
| `2048x1536 -> 1024x768 -> 2048x1536` with alpha | 211.1 ms | 6.85 s | 104.1 MiB |

The `8000x6000` case completed without an out-of-memory failure. Checksums are
intentionally different because Pica uses scale-aware filters, fixed-point
coefficients, tiling, and premultiplied alpha while the previous local path did
not.
