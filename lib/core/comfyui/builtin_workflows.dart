import 'workflow_template.dart';

/// 内置工作流模板定义
class BuiltinWorkflows {
  BuiltinWorkflows._();

  static List<WorkflowTemplate> get all => [
    seedvr2NativeUpscale,
    seedvr2Upscale,
    seedvr2TiledUpscale,
    modelUpscale,
    rtxUpscale,
  ];

  /// ComfyUI 原生 SeedVR2 图片超分工作流。
  ///
  /// 输入先保留 alpha 并按倍率缩放，再经过原生 SeedVR2 预处理、VAE、
  /// 一步采样和后处理。该工作流只依赖 ComfyUI Core 节点。
  static const WorkflowTemplate seedvr2NativeUpscale = WorkflowTemplate(
    id: 'builtin_seedvr2_native_upscale',
    name: 'SeedVR2 Native Upscale',
    description:
        'Upscale with the native SeedVR2 implementation included in ComfyUI.',
    version: '1.0.0',
    author: 'NAI Launcher',
    category: WorkflowCategory.enhance,
    requiresInputImage: true,
    requiresMask: false,
    isBuiltin: true,
    slots: [
      WorkflowSlot(
        id: 'input_image',
        direction: SlotDirection.input,
        dataType: SlotDataType.image,
        nodeId: '1',
        field: 'image',
        label: 'Input Image',
        required: true,
      ),
      WorkflowSlot(
        id: 'scale',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.number,
        nodeId: '3',
        field: 'scale_by',
        label: 'Scale',
        defaultValue: 1.5,
        min: 1.0,
        max: 2.0,
        step: 0.1,
      ),
      WorkflowSlot(
        id: 'dit_model',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.choice,
        nodeId: '7',
        field: 'unet_name',
        label: 'Upscale Model',
        defaultValue: 'seedvr2_3b_int8_convrot.safetensors',
        choices: ['seedvr2_3b_int8_convrot.safetensors'],
      ),
      WorkflowSlot(
        id: 'vae_model',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.choice,
        nodeId: '5',
        field: 'vae_name',
        label: 'VAE Model',
        defaultValue: 'seedvr2_ema_vae_fp16.safetensors',
        choices: [
          'seedvr2_ema_vae_fp16.safetensors',
          'ema_vae_fp16.safetensors',
        ],
      ),
      WorkflowSlot(
        id: 'vae_encode_tile_size',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '6',
        field: 'tile_size',
        label: 'VAE Encode Tile Size',
        defaultValue: 1024,
        min: 128,
        max: 4096,
        step: 64,
      ),
      WorkflowSlot(
        id: 'vae_decode_tile_size',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '10',
        field: 'tile_size',
        label: 'VAE Decode Tile Size',
        defaultValue: 1024,
        min: 128,
        max: 4096,
        step: 64,
      ),
      WorkflowSlot(
        id: 'seed',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '9',
        field: 'seed',
        label: 'Random Seed',
        defaultValue: -1,
        min: -1,
        max: 4294967295,
      ),
      WorkflowSlot(
        id: 'output_image',
        direction: SlotDirection.output,
        dataType: SlotDataType.image,
        nodeId: '12',
        field: null,
        label: 'Output Image',
        outputMethod: OutputMethod.httpHistory,
        nodeClass: 'SaveImage',
      ),
    ],
    workflowJson: _seedvr2NativeWorkflowJson,
  );

  /// 兼容旧版自定义节点的 SeedVR2 超分工作流
  ///
  /// 节点图：
  ///   [15] LoadImage (输入)
  ///     ├─> [5] SeedVR2VideoUpscaler (执行超分)
  ///     │   ├── dit <── [6] SeedVR2LoadDiTModel
  ///     │   └── vae <── [7] SeedVR2LoadVAEModel
  ///     └─> [17] SaveImage (保存并通过 HTTP history 获取)
  ///
  /// 启动器在 Dart 侧根据源图最短边和倍率计算 resolution，避免依赖
  /// Float / easy imageSizeBySide / NumberCalculatorV2 等辅助自定义节点。
  static const WorkflowTemplate seedvr2Upscale = WorkflowTemplate(
    id: 'builtin_seedvr2_upscale',
    name: 'SeedVR2 Upscale',
    description:
        'Upscale with the SeedVR2 AI model. Produces high-quality results.',
    version: '1.0.0',
    author: 'NAI Launcher',
    category: WorkflowCategory.enhance,
    requiresInputImage: true,
    requiresMask: false,
    isBuiltin: true,
    slots: [
      // 输入：源图像
      WorkflowSlot(
        id: 'input_image',
        direction: SlotDirection.input,
        dataType: SlotDataType.image,
        nodeId: '15',
        field: 'image',
        label: 'Input Image',
        required: true,
      ),
      // 参数：目标短边分辨率（由 UI 的放大倍率在 Dart 侧换算）
      WorkflowSlot(
        id: 'target_resolution',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '5',
        field: 'resolution',
        label: 'Target Short Side',
        defaultValue: 1024,
        min: 1,
        max: 16384,
        step: 1,
      ),
      // 参数：超分模型
      WorkflowSlot(
        id: 'dit_model',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.choice,
        nodeId: '6',
        field: 'model',
        label: 'Upscale Model',
        defaultValue: 'seedvr2_ema_7b_fp16.safetensors',
        choices: ['seedvr2_ema_7b_fp16.safetensors'],
      ),
      WorkflowSlot(
        id: 'vae_encode_tile_size',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '7',
        field: 'encode_tile_size',
        label: 'VAE Encode Tile Size',
        defaultValue: 1024,
        min: 128,
        max: 4096,
        step: 64,
      ),
      WorkflowSlot(
        id: 'vae_decode_tile_size',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '7',
        field: 'decode_tile_size',
        label: 'VAE Decode Tile Size',
        defaultValue: 1024,
        min: 128,
        max: 4096,
        step: 64,
      ),
      // 参数：放在 CPU 内存的 DiT 层数（显存与内存的取舍）
      WorkflowSlot(
        id: 'blocks_to_swap',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '6',
        field: 'blocks_to_swap',
        label: 'Blocks To Swap',
        defaultValue: 16,
        min: 0,
        max: 36,
        step: 1,
      ),
      // 参数：是否连输入输出组件一起卸载到 CPU
      WorkflowSlot(
        id: 'swap_io_components',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.boolean,
        nodeId: '6',
        field: 'swap_io_components',
        label: 'Swap IO Components',
        defaultValue: false,
      ),
      // 参数：种子
      WorkflowSlot(
        id: 'seed',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '5',
        field: 'seed',
        label: 'Random Seed',
        defaultValue: -1,
        min: -1,
        max: 4294967295,
      ),
      // 输出：通过 HTTP history 获取（比 WS 二进制帧更可靠）
      WorkflowSlot(
        id: 'output_image',
        direction: SlotDirection.output,
        dataType: SlotDataType.image,
        nodeId: '17',
        field: null,
        label: 'Output Image',
        outputMethod: OutputMethod.httpHistory,
        nodeClass: 'SaveImage',
      ),
    ],
    workflowJson: _seedvr2WorkflowJson,
  );

  /// SeedVR2 分块超分工作流
  ///
  /// 使用 `SeedVR2TilingUpscaler` 对大图进行分块处理，适合显存较紧张时使用。
  /// `tile_size` 在启动器侧作为单个设置暴露，但会同时注入
  /// tile_width / tile_height。
  static const WorkflowTemplate seedvr2TiledUpscale = WorkflowTemplate(
    id: 'builtin_seedvr2_tiled_upscale',
    name: 'SeedVR2 Tiled Upscale',
    description:
        'Use SeedVR2TilingUpscaler for tiled upscale to reduce VRAM pressure on large images.',
    version: '1.0.0',
    author: 'NAI Launcher',
    category: WorkflowCategory.enhance,
    requiresInputImage: true,
    requiresMask: false,
    isBuiltin: true,
    slots: [
      WorkflowSlot(
        id: 'input_image',
        direction: SlotDirection.input,
        dataType: SlotDataType.image,
        nodeId: '15',
        field: 'image',
        label: 'Input Image',
        required: true,
      ),
      WorkflowSlot(
        id: 'target_resolution',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '8',
        field: 'new_resolution',
        label: 'Target Long Side',
        defaultValue: 2048,
        min: 16,
        max: 16384,
        step: 16,
      ),
      WorkflowSlot(
        id: 'dit_model',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.choice,
        nodeId: '6',
        field: 'model',
        label: 'Upscale Model',
        defaultValue: 'seedvr2_ema_7b_fp16.safetensors',
        choices: ['seedvr2_ema_7b_fp16.safetensors'],
      ),
      WorkflowSlot(
        id: 'vae_encode_tile_size',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '7',
        field: 'encode_tile_size',
        label: 'VAE Encode Tile Size',
        defaultValue: 1024,
        min: 128,
        max: 4096,
        step: 64,
      ),
      WorkflowSlot(
        id: 'vae_decode_tile_size',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '7',
        field: 'decode_tile_size',
        label: 'VAE Decode Tile Size',
        defaultValue: 1024,
        min: 128,
        max: 4096,
        step: 64,
      ),
      // 参数：放在 CPU 内存的 DiT 层数（显存与内存的取舍）
      WorkflowSlot(
        id: 'blocks_to_swap',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '6',
        field: 'blocks_to_swap',
        label: 'Blocks To Swap',
        defaultValue: 16,
        min: 0,
        max: 36,
        step: 1,
      ),
      // 参数：是否连输入输出组件一起卸载到 CPU
      WorkflowSlot(
        id: 'swap_io_components',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.boolean,
        nodeId: '6',
        field: 'swap_io_components',
        label: 'Swap IO Components',
        defaultValue: false,
      ),
      WorkflowSlot(
        id: 'tile_size',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '8',
        field: 'tile_width',
        label: 'Tile Width',
        defaultValue: 1024,
        min: 256,
        max: 4096,
        step: 64,
      ),
      WorkflowSlot(
        id: 'tile_size',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '8',
        field: 'tile_height',
        label: 'Tile Height',
        defaultValue: 1024,
        min: 256,
        max: 4096,
        step: 64,
      ),
      WorkflowSlot(
        id: 'tile_upscale_resolution',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '8',
        field: 'tile_upscale_resolution',
        label: 'Tile Upscale Resolution',
        defaultValue: 1536,
        min: 64,
        max: 8192,
        step: 64,
      ),
      WorkflowSlot(
        id: 'seed',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '8',
        field: 'seed',
        label: 'Random Seed',
        defaultValue: -1,
        min: -1,
        max: 4294967295,
      ),
      WorkflowSlot(
        id: 'output_image',
        direction: SlotDirection.output,
        dataType: SlotDataType.image,
        nodeId: '17',
        field: null,
        label: 'Output Image',
        outputMethod: OutputMethod.httpHistory,
        nodeClass: 'SaveImage',
      ),
    ],
    workflowJson: _seedvr2TiledWorkflowJson,
  );

  /// ComfyUI 普通超分模型工作流
  ///
  /// 节点图：
  ///   [1] LoadImage (输入)
  ///     ├─> [3] ImageUpscaleWithModel
  ///     │    └── upscale_model <── [2] UpscaleModelLoader
  ///     ├─> [4] ImageScale (Lanczos 缩放到用户指定最终尺寸)
  ///     └─> [5] SaveImage
  ///
  /// 这种流程用于 `models/upscale_models` 里的 `.pth/.pt/.safetensors`
  /// 等轻量超分模型；模型本身先输出原生倍率，再由 Lanczos 统一修正到
  /// 启动器中设置的目标倍率。
  static const WorkflowTemplate modelUpscale = WorkflowTemplate(
    id: 'builtin_comfy_model_upscale',
    name: 'ComfyUI Standard Upscale Model',
    description:
        'Load a standard upscale model with ComfyUI UpscaleModelLoader, then correct the final scale with Lanczos.',
    version: '1.0.0',
    author: 'NAI Launcher',
    category: WorkflowCategory.enhance,
    requiresInputImage: true,
    requiresMask: false,
    isBuiltin: true,
    slots: [
      WorkflowSlot(
        id: 'input_image',
        direction: SlotDirection.input,
        dataType: SlotDataType.image,
        nodeId: '1',
        field: 'image',
        label: 'Input Image',
        required: true,
      ),
      WorkflowSlot(
        id: 'upscale_model',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.choice,
        nodeId: '2',
        field: 'model_name',
        label: 'Upscale Model',
        defaultValue: 'realesrganX4plusAnime_v1.pt',
        choices: ['realesrganX4plusAnime_v1.pt'],
      ),
      WorkflowSlot(
        id: 'target_width',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '4',
        field: 'width',
        label: 'Target Width',
        defaultValue: 1024,
        min: 1,
        max: 16384,
      ),
      WorkflowSlot(
        id: 'target_height',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.integer,
        nodeId: '4',
        field: 'height',
        label: 'Target Height',
        defaultValue: 1024,
        min: 1,
        max: 16384,
      ),
      WorkflowSlot(
        id: 'output_image',
        direction: SlotDirection.output,
        dataType: SlotDataType.image,
        nodeId: '5',
        field: null,
        label: 'Output Image',
        outputMethod: OutputMethod.httpHistory,
        nodeClass: 'SaveImage',
      ),
    ],
    workflowJson: _modelUpscaleWorkflowJson,
  );

  /// Nvidia RTX Video Super Resolution 超分工作流
  static const WorkflowTemplate rtxUpscale = WorkflowTemplate(
    id: 'builtin_rtx_upscale',
    name: 'RTX Upscale',
    description:
        'Use the Nvidia RTX Video Super Resolution node for local upscaling.',
    version: '1.0.0',
    author: 'NAI Launcher',
    category: WorkflowCategory.enhance,
    requiresInputImage: true,
    requiresMask: false,
    isBuiltin: true,
    slots: [
      WorkflowSlot(
        id: 'input_image',
        direction: SlotDirection.input,
        dataType: SlotDataType.image,
        nodeId: '1',
        field: 'image',
        label: 'Input Image',
        required: true,
      ),
      WorkflowSlot(
        id: 'rtx_scale',
        direction: SlotDirection.parameter,
        dataType: SlotDataType.number,
        nodeId: '2',
        field: 'resize_type.scale',
        label: 'Scale',
        defaultValue: 2.0,
        min: 1.0,
        max: 4.0,
        step: 0.1,
      ),
      WorkflowSlot(
        id: 'output_image',
        direction: SlotDirection.output,
        dataType: SlotDataType.image,
        nodeId: '3',
        field: null,
        label: 'Output Image',
        outputMethod: OutputMethod.httpHistory,
        nodeClass: 'SaveImage',
      ),
    ],
    workflowJson: _rtxUpscaleWorkflowJson,
  );

  // ==================== ComfyUI 原生 SeedVR2 超分 ====================

  static const Map<String, dynamic> _seedvr2NativeWorkflowJson = {
    '1': {
      'inputs': {'image': 'placeholder.png'},
      'class_type': 'LoadImage',
      '_meta': {'title': 'Load Image'},
    },
    '2': {
      'inputs': {
        'image': ['1', 0],
        'alpha': ['1', 1],
      },
      'class_type': 'JoinImageWithAlpha',
      '_meta': {'title': 'Join Image With Alpha'},
    },
    '3': {
      'inputs': {
        'image': ['2', 0],
        'upscale_method': 'lanczos',
        'scale_by': 1.5,
      },
      'class_type': 'ImageScaleBy',
      '_meta': {'title': 'Scale SeedVR2 Input'},
    },
    '4': {
      'inputs': {
        'resized_images': ['3', 0],
      },
      'class_type': 'SeedVR2Preprocess',
      '_meta': {'title': 'Pre-Process SeedVR2 Input'},
    },
    '5': {
      'inputs': {'vae_name': 'seedvr2_ema_vae_fp16.safetensors'},
      'class_type': 'VAELoader',
      '_meta': {'title': 'Load SeedVR2 VAE'},
    },
    '6': {
      'inputs': {
        'pixels': ['4', 0],
        'vae': ['5', 0],
        'tile_size': 1024,
        'overlap': 64,
        'temporal_size': 4096,
        'temporal_overlap': 8,
      },
      'class_type': 'VAEEncodeTiled',
      '_meta': {'title': 'VAE Encode Tiled'},
    },
    '7': {
      'inputs': {
        'unet_name': 'seedvr2_3b_int8_convrot.safetensors',
        'weight_dtype': 'default',
      },
      'class_type': 'UNETLoader',
      '_meta': {'title': 'Load Native SeedVR2 Model'},
    },
    '8': {
      'inputs': {
        'model': ['7', 0],
        'vae_conditioning': ['6', 0],
      },
      'class_type': 'SeedVR2Conditioning',
      '_meta': {'title': 'Apply SeedVR2 Conditioning'},
    },
    '9': {
      'inputs': {
        'model': ['7', 0],
        'seed': 454201668,
        'steps': 1,
        'cfg': 1.0,
        'sampler_name': 'euler',
        'scheduler': 'simple',
        'positive': ['8', 0],
        'negative': ['8', 1],
        'latent_image': ['6', 0],
        'denoise': 1.0,
      },
      'class_type': 'KSampler',
      '_meta': {'title': 'SeedVR2 One-Step Sampler'},
    },
    '10': {
      'inputs': {
        'samples': ['9', 0],
        'vae': ['5', 0],
        'tile_size': 1024,
        'overlap': 64,
        'temporal_size': 4096,
        'temporal_overlap': 8,
      },
      'class_type': 'VAEDecodeTiled',
      '_meta': {'title': 'VAE Decode Tiled'},
    },
    '11': {
      'inputs': {
        'images': ['10', 0],
        'original_resized_images': ['3', 0],
        'color_correction_method': 'lab',
      },
      'class_type': 'SeedVR2PostProcessing',
      '_meta': {'title': 'Post-Process SeedVR2 Output'},
    },
    '12': {
      'inputs': {
        'filename_prefix': 'NAI_seedvr2_native_upscale',
        'images': ['11', 0],
      },
      'class_type': 'SaveImage',
      '_meta': {'title': 'Save Image'},
    },
  };

  // ==================== 兼容自定义节点的 SeedVR2 超分 ====================

  static const Map<String, dynamic> _seedvr2WorkflowJson = {
    '5': {
      'inputs': {
        'seed': 454201668,
        'resolution': 1024,
        'max_resolution': 0,
        'batch_size': 1,
        'uniform_batch_size': true,
        'color_correction': 'lab',
        'temporal_overlap': 0,
        'prepend_frames': 0,
        'input_noise_scale': 0,
        'latent_noise_scale': 0,
        'offload_device': 'cpu',
        'enable_debug': false,
        'image': ['15', 0],
        'dit': ['6', 0],
        'vae': ['7', 0],
      },
      'class_type': 'SeedVR2VideoUpscaler',
      '_meta': {'title': 'SeedVR2 Video Upscaler'},
    },
    '6': {
      'inputs': {
        'model': 'seedvr2_ema_7b_fp16.safetensors',
        'device': 'cuda:0',
        // 实际值由启动器按用户设置注入，这里只是模板默认。
        'blocks_to_swap': 16,
        'swap_io_components': false,
        'offload_device': 'cpu',
        'cache_model': false,
        // sdpa 是 PyTorch 内置后端，任何环境都可用；sageattn / flash_attn
        // 需要用户自行安装扩展包，不适合作为发行默认值。
        'attention_mode': 'sdpa',
      },
      'class_type': 'SeedVR2LoadDiTModel',
      '_meta': {'title': 'SeedVR2 Load DiT Model'},
    },
    '7': {
      'inputs': {
        'model': 'ema_vae_fp16.safetensors',
        'device': 'cuda:0',
        'encode_tiled': true,
        'encode_tile_size': 1024,
        'encode_tile_overlap': 128,
        'decode_tiled': true,
        'decode_tile_size': 1024,
        'decode_tile_overlap': 128,
        'tile_debug': 'false',
        'offload_device': 'cpu',
        'cache_model': false,
      },
      'class_type': 'SeedVR2LoadVAEModel',
      '_meta': {'title': 'SeedVR2 Load VAE Model'},
    },
    '15': {
      'inputs': {'image': 'placeholder.png'},
      'class_type': 'LoadImage',
      '_meta': {'title': 'Load Image'},
    },
    '17': {
      'inputs': {
        'filename_prefix': 'NAI_upscale',
        'images': ['5', 0],
      },
      'class_type': 'SaveImage',
      '_meta': {'title': 'Save Image'},
    },
  };

  // ==================== SeedVR2 分块超分 ====================

  static const Map<String, dynamic> _seedvr2TiledWorkflowJson = {
    '6': {
      'inputs': {
        'model': 'seedvr2_ema_7b_fp16.safetensors',
        'device': 'cuda:0',
        // 实际值由启动器按用户设置注入，这里只是模板默认。
        'blocks_to_swap': 16,
        'swap_io_components': false,
        'offload_device': 'cpu',
        'cache_model': false,
        // sdpa 是 PyTorch 内置后端，任何环境都可用；sageattn / flash_attn
        // 需要用户自行安装扩展包，不适合作为发行默认值。
        'attention_mode': 'sdpa',
      },
      'class_type': 'SeedVR2LoadDiTModel',
      '_meta': {'title': 'SeedVR2 Load DiT Model'},
    },
    '7': {
      'inputs': {
        'model': 'ema_vae_fp16.safetensors',
        'device': 'cuda:0',
        'encode_tiled': true,
        'encode_tile_size': 1024,
        'encode_tile_overlap': 128,
        'decode_tiled': true,
        'decode_tile_size': 1024,
        'decode_tile_overlap': 128,
        'tile_debug': 'false',
        'offload_device': 'cpu',
        'cache_model': false,
      },
      'class_type': 'SeedVR2LoadVAEModel',
      '_meta': {'title': 'SeedVR2 Load VAE Model'},
    },
    '8': {
      'inputs': {
        'image': ['15', 0],
        'dit': ['6', 0],
        'vae': ['7', 0],
        'seed': 454201668,
        'new_resolution': 2048,
        'tile_width': 1024,
        'tile_height': 1024,
        'mask_blur': 0,
        'tile_padding': 64,
        'tile_upscale_resolution': 1536,
        'tiling_strategy': 'Chess',
        'anti_aliasing_strength': 0.1,
        'blending_method': 'content_aware',
        'color_correction': 'lab',
        'resolution_target': 'longest',
        // 新版 SeedVR2TilingUpscaler 将该项设为必填；1 是最低显存默认值。
        'tile_batch_size': 1,
      },
      'class_type': 'SeedVR2TilingUpscaler',
      '_meta': {'title': 'SeedVR2 Tiling Upscaler'},
    },
    '15': {
      'inputs': {'image': 'placeholder.png'},
      'class_type': 'LoadImage',
      '_meta': {'title': 'Load Image'},
    },
    '17': {
      'inputs': {
        'filename_prefix': 'NAI_seedvr2_tiled_upscale',
        'images': ['8', 0],
      },
      'class_type': 'SaveImage',
      '_meta': {'title': 'Save Image'},
    },
  };

  // ==================== 普通超分模型 ====================

  static const Map<String, dynamic> _modelUpscaleWorkflowJson = {
    '1': {
      'inputs': {'image': 'placeholder.png'},
      'class_type': 'LoadImage',
      '_meta': {'title': 'Load Image'},
    },
    '2': {
      'inputs': {'model_name': 'realesrganX4plusAnime_v1.pt'},
      'class_type': 'UpscaleModelLoader',
      '_meta': {'title': 'Upscale Model Loader'},
    },
    '3': {
      'inputs': {
        'upscale_model': ['2', 0],
        'image': ['1', 0],
      },
      'class_type': 'ImageUpscaleWithModel',
      '_meta': {'title': 'Image Upscale With Model'},
    },
    '4': {
      'inputs': {
        'upscale_method': 'lanczos',
        'width': 1024,
        'height': 1024,
        'crop': 'disabled',
        'image': ['3', 0],
      },
      'class_type': 'ImageScale',
      '_meta': {'title': 'Image Scale To Target'},
    },
    '5': {
      'inputs': {
        'filename_prefix': 'NAI_upscale',
        'images': ['4', 0],
      },
      'class_type': 'SaveImage',
      '_meta': {'title': 'Save Image'},
    },
  };

  // ==================== RTX 超分 ====================

  static const Map<String, dynamic> _rtxUpscaleWorkflowJson = {
    '1': {
      'inputs': {'image': 'placeholder.png'},
      'class_type': 'LoadImage',
      '_meta': {'title': 'Load Image'},
    },
    '2': {
      'inputs': {
        'images': ['1', 0],
        'resize_type': 'scale by multiplier',
        'resize_type.scale': 2.0,
        'quality': 'ULTRA',
      },
      'class_type': 'RTXVideoSuperResolution',
      '_meta': {'title': 'RTX Video Super Resolution'},
    },
    '3': {
      'inputs': {
        'filename_prefix': 'NAI_rtx_upscale',
        'images': ['2', 0],
      },
      'class_type': 'SaveImage',
      '_meta': {'title': 'Save Image'},
    },
  };
}
