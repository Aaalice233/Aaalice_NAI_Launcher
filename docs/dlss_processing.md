# DLSS 静态图像处理

Windows 使用随应用构建的 `aaalice_dlss_worker.exe` 与 `aaalice_nvngx.dll`，模型 DLL 由现有运行库安装器按固定清单安装。环境指纹包含 worker 协议版本；原生处理协议变化后重新检测 GPU，不沿用旧检测成功状态。

## 图像管线

1. Dart 解码原图，将 sRGB 转为线性 RGBA float32，通过 AAF1 临时文件传给独立 worker。
2. 需要放大时调用真实 DLSS SR；较大倍率按模型支持的倍率分段计算。保留放大结果作为最终合成基准。
3. NR 输入转换一次到 sRGB 编码的 RGBA16F GPU 纹理。创建一个 feature，以 `Reset=1` 执行单次 NR。静态输入没有帧间位移，运动向量为零。
4. 读回 NR 结果后转换为线性浮点，Dart 对未修改的基准执行一次细节与颜色混合，再编码最终 PNG。处理中没有 PNG 编码、8 位量化或细节/颜色合成。
5. 恢复原图透明通道、支持的生成元数据，并记录实际处理参数。原图不覆盖。

worker 必须报告 `AAALICE_NR_START`，成功写出结果后返回 `AAALICE_NR_DONE fp16-single`。输出元数据同时记录 `fp16-single` 管线标记。非零退出、缺失结果、非法尺寸、非有限像素与不完整协议均为失败。取消会终止独立 worker 并清理临时任务文件，不接受部分结果。

SR/VSR 只作为 NR 增强的内部尺寸预处理，不提供独立放大入口、Provider 或独立调用能力。自动增强期间保留最后一帧流式预览，按准备、增强、编码阶段显示中央状态；失败保留原图并提示手动增强重试，批次继续处理后续图片。

静态图片没有游戏引擎的真实深度，当前应用传零值；worker 的 `--depth` 是开发诊断入口，接收与 NR 输出尺寸一致的 AAF1 深度数据。不能把绑定深度纹理等同于模型实际利用深度，也不宣称自动深度重建。NVIDIA 的 DLSS 5 资料区分了推理输入的图像、运动向量与时间状态，以及训练阶段的渲染属性；不能因此推断给当前 NR runtime 添加估算的法线或深度就能改善图片。NR 会改变光照和材质，不承诺语义或像素无损。

## 参数语义与范围

参数名称以当前 worker 的实际行为为边界；官方艺术控制的概念不构成私有参数编号或数值范围的保证。当前运行库的静态图像对照测试使用相同输入、单次 NR、零运动向量，并同时比较原始浮点输出与 PNG 画面。

| 控件 | 当前行为 |
| --- | --- |
| NR 总强度 | `0～1`；超过 1 与 1 的浮点输出一致。旧预设大于 1 的值读取为 1，保留原有饱和效果。 |
| 结构强度 | 非负数，滑块常用 `0～2`。超过 1 仍有效；高值可能产生颗粒、色偏与结构失真，不能按总强度截断。 |
| 光照与色调强度 | 非负数，滑块常用 `0～2`。控制较大范围的明暗和颜色；0 不等于关闭全部 NR，也不保证原色完全不变。 |
| 皮肤结构强度 | `-1` 为模型默认，非负数显式传给模型。历史 `-1～0` 间负值同样省略该参数。关闭自动遮罩时，本次扫描的皮肤强度输出一致；编辑器禁用此项但保留其数值。 |
| 输出混合 | Launcher 的线性空间结果合成，0 保留基准，1 完整应用颜色贡献调整后的 NR 结果；大于 1 外推两者差异。不是 NR 材质参数。 |
| NR 颜色贡献 | `0～1`。0 按 NR 与基准的亮度比例缩放基准 RGB，1 使用 NR RGB；之后再执行输出混合。不是整体透明度。 |
| 风格 | `0 / 1 / 2` 有不同输出；界面沿用上游的默认、自然、电影感名称，未验证与官方 Model A/B/C 的对应。 |

结构、光照、皮肤与输出混合的可输入上限来自 float32 传输边界，不是经过画质验证的模型有效范围。改变运行库后应重新验证；有限样本未观察到差异不等于证明参数在所有输入中无效。

当前管线已移除全局色调、NR 编号预设与 UI 修正，包括控件、持久化字段与原生参数设置。完整输入及独立面部、材质裁切的对照测试中，全局色调、编号预设与 UI 修正分别得到完全相同的浮点输出；当前也不提供独立 UI 图层。读取旧配置时忽略这三个多余字段，有效参数、自定义组合预设与选择保持不变。

## 构建与验证

`windows/dlss/ngx_sdk.cmake` 固定 NVIDIA SDK 提交与各文件 SHA-256。首次 Windows 配置需联网下载 SDK，下载或校验失败直接中止。SDK 使用 Release 静态 CRT，worker 单独采用相同 CRT，即使主应用处于 Debug 模式；模型文件不在构建期间下载。

- Dart 回归：`scripts/test_affected.ps1 -Path "lib/data/services/dlss/dlss_worker.dart,lib/data/services/dlss/dlss_float_frame.dart,lib/data/services/dlss/dlss_options.dart"`。
- 原生验证需 Windows NVIDIA GPU、已安装且校验通过的运行库，以及完整 Windows 构建；应用设置中的检测会使用同一个 worker 实际执行 NR 并检查输出变化。
- `tool/dlss/verify_runtime.ps1` 仅诊断第三方原始 CLI 的参数与模型，不验证应用的 FP16 单次 NR 管线。
- 图像效果验证检查实际尺寸、完整处理协议、脸/手/小物体的原尺寸裁切，以及取消后的原图和任务文件状态。修改原生处理时，对照相同输入与参数的单次 NR 输出，检查颗粒、边缘位移或色块破坏。截图和实验图片放在 `tool/.tmp/`，不提交。

## 实现参考与许可

- [NVIDIA DLSS 5 技术说明](https://research.nvidia.com/labs/adlr/DLSS5/)：推理输入、时间状态与训练属性的区别。
- [video2dlssnr](https://github.com/DaniilSokolyuk/video2dlssnr)：SR 在前、NR 在后的顺序与参数参考。
- [DLSS-COM](https://github.com/MYT-YEP/DLSS-COM)：浮点纹理传递与直接 NGX 桥接，采用部分 MIT 代码；完整声明见 `THIRD_PARTY_NOTICES.md`。
- [DLSS5Tool](https://github.com/banbanzhige/DLSS5Tool)：对照浮点传输及最终颜色混合；未采用其 UI 或生成式图像组件。

## 编解码测量与 Magpie 评估

当前 worker 记录 `decode`、`marshal`、`write`、`worker`、`read`、`compose`、`alpha`、`encode`、`metadata` 分段微秒耗时，可通过 `onTiming` 收集；`worker` 包含进程启动、NGX 初始化、GPU 处理和原生文件输出，不等于纯 GPU 推理时间。解码结果复用于最终 Alpha 和元数据恢复，浮点传输按字节批量复制，临时文件关闭后直接交给 worker，不做持久化 fsync。大端主机保留显式小端转换；读取仍校验尺寸、完整长度和非有限像素。

2026-09-07 本机 RTX 4060 Laptop、驱动 `32.0.16.1047`、video2dlssnr `v1.3` 的对照：固定生成 512×512 RGBA 渐变/纹理输入，包含透明度和 Comment 元数据，默认参数输出 1024×1024。修改前完整流程三次为 3442/3089/3132 ms，优化后为 3006/3021/3020 ms；中位数约降低 3.6%。六份最终 PNG 的 SHA-256 均为 `c339726048fa4cd45729af43f71246ec7f3c585d99553d72e5bba2fb2ffcf592`。这是有限样本，不能外推为所有图片的加速比例或画质评价。

优化后代表性一轮的解码/搬运/写入/worker/读取/合成/Alpha/编码/元数据分别约为 11/14/3/1965/20/129/142/711/7 ms；主要成本仍在原生处理和 PNG 编码。单独的 1024×1024 float32 往返测试逐值一致，热身后编码从约 6–8 ms 降至约 3 ms，解码从约 9 ms 降至约 6–7 ms。没有通过降低画质、改变压缩参数或删减元数据获得速度。

对照 [Magpie Experimental 的 DLSSNRFilter.cpp](https://github.com/SAOG0721/Magpie/blob/9824d758b162ad3c5b5acc81e2e14c83f138e13d/src/Magpie.Core/DLSSNRFilter.cpp)，建议保留当前静态图管线，局部参考计时与资源复用设计，不直接替换：

| 方面 | 评估 |
| --- | --- |
| 图像语义 | Magpie 的 NR 接口接收同尺寸 SDR 窗口纹理，在内部使用 RGBA16F；它拥有帧间历史、重置和运动引导机制。Launcher 需要一次静态增强、原图透明度与文件元数据，不能把连续窗口画面的观感直接当作静态图质量优势。未进行两者同图盲测，不宣称效果更好。 |
| 性能 | Magpie 复用常驻 GPU 资源和 feature，适合连续帧；其每帧计时不包含本项目的图像解码、文件编码及每任务启动成本。迁移整个窗口捕获栈不能直接解决 PNG 编码开销。常驻 worker 或共享纹理可能有价值，但需独立验证取消、异常隔离和显存生命周期后再决定。 |
| DLL 来源 | Magpie 从应用目录加载 `nvngx_dlssnr.dll`；[发布说明](https://github.com/SAOG0721/Magpie/releases)提供 NVIDIA 原版与社区 RTX40/50 兼容版选项，部分历史包使用社区修改版，不能仅按同为 `310.8.0.0` 判断二进制相同。本机当前模型 SHA-256 为 `8270b350cd82de5ce89806872cdd6b6a9249b80836b91bbeb3573470744cc206`；本次未替换模型。 |
| 维护与分发 | Magpie 派生代码采用 GPLv3，第三方 SDK/模型另有条款；其[组件与再分发清单](https://github.com/SAOG0721/Magpie/blob/experimental/docs/THIRD_PARTY_AND_REDISTRIBUTION.md)明确将 DLSSNR 分发权限列为待审查边界。其近期还处理了 NGX 关闭异常后的锁与窗口等待问题。直接移植会扩大维护和许可范围；当前独立进程隔离仍适合静态任务。 |

本次仅阅读和评估 Magpie 源码，未引入其 GPL 代码、SDK、DLL、系统级 NGX 设置或窗口捕获依赖。
