# Pica 缩放基准

[脚本](pica_resize_benchmark.dart) 比较 Pica 移植与旧 Lanczos3 算法，适合缩放实现变化后的本地测量。每个样本在独立 isolate 中执行；耗时只统计缩放，不包括样本生成。

在仓库根目录编译为 AOT 后运行：

~~~powershell
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path tool/.tmp/pica-benchmark | Out-Null
dart compile exe tool/diagnostics/pica_resize_benchmark.dart -o tool/.tmp/pica-benchmark/pica_resize_benchmark.exe
if ($LASTEXITCODE -ne 0) { throw 'Pica benchmark compilation failed' }
& tool/.tmp/pica-benchmark/pica_resize_benchmark.exe --iterations=3
if ($LASTEXITCODE -ne 0) { throw 'Pica benchmark failed' }
~~~

报告时记录代码版本、平台、运行次数、样本尺寸、耗时与实际内存口径。RSS 采样值不等于完整持续峰值，机器耗时不作为通用 CI 阈值。

两种算法的滤波、定点计算、分块和 alpha 处理不同，checksum 不同不能单独证明错误或等价。性能结论须与图像质量检查和相关单测一起判断。历史开发机数据不作为当前性能承诺；临时可执行文件和测量记录不提交。
