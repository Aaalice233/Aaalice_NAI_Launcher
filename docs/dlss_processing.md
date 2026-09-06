# DLSS 静态图像处理

Windows 使用随应用构建的 `aaalice_dlss_worker.exe` 与 `aaalice_nvngx.dll`，模型 DLL 由现有运行库安装器按固定清单安装。环境指纹包含 worker 协议版本；原生处理协议变化后重新检测 GPU，不沿用旧检测成功状态。

## 图像管线

1. Dart 解码原图，将 sRGB 转为线性 RGBA float32，通过 AAF1 临时文件传给独立 worker。
2. 需要放大时调用真实 DLSS SR；较大倍率按模型支持的倍率分段计算。保留放大结果作为最终合成基准，SR 不随 NR 次数重复执行。
3. NR 输入转换一次到 sRGB 编码的 RGBA16F GPU 纹理。整个任务复用一个 feature，每次读取同一张输入；首次 `Reset=1`，后续 `Reset=0`，保留模型历史。静态输入没有帧间位移，运动向量为零。不能把 NR 新增纹理反馈为下一次原始输入，否则会累积颗粒与轮廓变化。
4. 最后一次读回后转换为线性浮点，Dart 对未修改的基准执行一次细节与颜色混合，再编码最终 PNG。处理中没有 PNG 编码、8 位量化或细节/颜色合成。
5. 恢复原图透明通道、支持的生成元数据，并记录实际处理参数。原图不覆盖。

NR 次数范围为 1–3，旧预设的大于 3 的值加载为 3，其余参数保留。进度必须按顺序报告全部次数并返回 `fp16-temporal` 完成标记；旧级联 worker 不被接受。输出元数据同时记录该管线标记，以区分相同参数的旧结果。非零退出、缺失结果、非法尺寸、非有限像素与不完整进度均为失败。取消会终止独立 worker 并清理临时任务文件，不接受部分结果。

静态图片没有游戏引擎的真实深度，当前应用传零值；worker 的 `--depth` 是开发诊断入口，接收与 NR 输出尺寸一致的 AAF1 深度数据。不能把绑定深度纹理等同于模型实际利用深度，也不宣称自动深度重建。NVIDIA 的 DLSS 5 资料区分了推理输入的图像、运动向量与时间状态，以及训练阶段的渲染属性；不能因此推断给当前 NR runtime 添加估算的法线或深度就能改善图片。NR 会改变光照和材质，不承诺语义或像素无损；增加次数不保证更清晰。

## 构建与验证

`windows/dlss/ngx_sdk.cmake` 固定 NVIDIA SDK 提交与各文件 SHA-256。首次 Windows 配置需联网下载 SDK，下载或校验失败直接中止。SDK 使用 Release 静态 CRT，worker 单独采用相同 CRT，即使主应用处于 Debug 模式；模型文件不在构建期间下载。

- Dart 回归：`scripts/test_affected.ps1 -Path "lib/data/services/dlss/dlss_worker.dart,lib/data/services/dlss/dlss_float_frame.dart,lib/data/services/dlss/dlss_options.dart"`。
- 原生验证需 Windows NVIDIA GPU、已安装且校验通过的运行库，以及完整 Windows 构建；应用设置中的检测会使用同一个 worker 实际执行 NR 并检查输出变化。
- `tool/dlss/verify_runtime.ps1` 仅诊断第三方原始 CLI 的参数与模型，不验证应用的 FP16 历史复用管线。
- 图像效果验证使用相同原图与参数分别运行 1、2、3 次，检查实际尺寸、全部进度、脸/手/小物体的原尺寸裁切，以及取消后的原图和任务文件状态。修改历史处理时，同时比较单次输出是否一致，以及多次处理是否引入颗粒、边缘位移或色块破坏。截图和实验图片放在 `tool/.tmp/`，不提交。

## 实现参考与许可

- [NVIDIA DLSS 5 技术说明](https://research.nvidia.com/labs/adlr/DLSS5/)：推理输入、时间状态与训练属性的区别。
- [video2dlssnr](https://github.com/DaniilSokolyuk/video2dlssnr)：SR 在前、NR 在后的顺序与持续 feature 历史处理参考。
- [DLSS-COM](https://github.com/MYT-YEP/DLSS-COM)：浮点纹理传递与直接 NGX 桥接，采用部分 MIT 代码；完整声明见 `THIRD_PARTY_NOTICES.md`。
- [DLSS5Tool](https://github.com/banbanzhige/DLSS5Tool)：对照浮点传输及最终颜色混合；未采用其 UI 或生成式图像组件。
- [OptiScaler_DLSSNR](https://github.com/Dagherbou/OptiScaler_DLSSNR)：对照游戏端多层与最终合成职责。静态图像不具备游戏引擎 G-buffer，不能移植为相同画质承诺。
