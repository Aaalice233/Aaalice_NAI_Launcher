// GENERATED from @earendil-works/pi-ai 1.6.0.
// Source: dist/providers/data/*.json. Do not edit by hand.

typedef PiModelProfile = ({String? name, bool imageInput});

const piModelProfiles = <String, Map<String, PiModelProfile>>{
  'openai': {
    'chat-latest': (name: 'Chat Latest', imageInput: true),
    'gpt-4': (name: 'GPT-4', imageInput: false),
    'gpt-4-turbo': (name: 'GPT-4 Turbo', imageInput: true),
    'gpt-4.1': (name: 'GPT-4.1', imageInput: true),
    'gpt-4.1-mini': (name: 'GPT-4.1 mini', imageInput: true),
    'gpt-4.1-nano': (name: 'GPT-4.1 nano', imageInput: true),
    'gpt-4o': (name: 'GPT-4o', imageInput: true),
    'gpt-4o-2024-05-13': (name: 'GPT-4o (2024-05-13)', imageInput: true),
    'gpt-4o-2024-08-06': (name: 'GPT-4o (2024-08-06)', imageInput: true),
    'gpt-4o-2024-11-20': (name: 'GPT-4o (2024-11-20)', imageInput: true),
    'gpt-4o-mini': (name: 'GPT-4o mini', imageInput: true),
    'gpt-5': (name: 'GPT-5', imageInput: true),
    'gpt-5-chat-latest': (name: 'GPT-5 Chat Latest', imageInput: true),
    'gpt-5-mini': (name: 'GPT-5 Mini', imageInput: true),
    'gpt-5-nano': (name: 'GPT-5 Nano', imageInput: true),
    'gpt-5-pro': (name: 'GPT-5 Pro', imageInput: true),
    'gpt-5.1': (name: 'GPT-5.1', imageInput: true),
    'gpt-5.2': (name: 'GPT-5.2', imageInput: true),
    'gpt-5.2-pro': (name: 'GPT-5.2 Pro', imageInput: true),
    'gpt-5.3-codex': (name: 'GPT-5.3 Codex', imageInput: true),
    'gpt-5.3-codex-spark': (name: 'GPT-5.3 Codex Spark', imageInput: true),
    'gpt-5.4': (name: 'GPT-5.4', imageInput: true),
    'gpt-5.4-mini': (name: 'GPT-5.4 mini', imageInput: true),
    'gpt-5.4-nano': (name: 'GPT-5.4 nano', imageInput: true),
    'gpt-5.4-pro': (name: 'GPT-5.4 Pro', imageInput: true),
    'gpt-5.5': (name: 'GPT-5.5', imageInput: true),
    'gpt-5.5-pro': (name: 'GPT-5.5 Pro', imageInput: true),
    'gpt-5.6-cyber': (name: 'GPT-5.6 Cyber', imageInput: true),
    'gpt-5.6-luna': (name: 'GPT-5.6 Luna', imageInput: true),
    'gpt-5.6-sol': (name: 'GPT-5.6 Sol', imageInput: true),
    'gpt-5.6-terra': (name: 'GPT-5.6 Terra', imageInput: true),
    'gpt-6-astra': (name: 'GPT-6 Astra', imageInput: true),
    'gpt-6-cyber': (name: 'GPT-6 Cyber', imageInput: true),
    'gpt-6-luna': (name: 'GPT-6 Luna', imageInput: true),
    'gpt-6-sol': (name: 'GPT-6 Sol', imageInput: true),
    'gpt-6.1-sol': (name: 'GPT-6.1 Sol', imageInput: true),
    'gpt-6.1-terra': (name: 'GPT-6.1 Terra', imageInput: true),
    'gpt-6.2-astra': (name: 'GPT-6.2 Astra', imageInput: true),
    'gpt-6.2-sol': (name: 'GPT-6.2 Sol', imageInput: true),
    'gpt-daybreak-blue-latest': (name: 'Daybreak Blue', imageInput: true),
    'gpt-daybreak-red-latest': (name: 'Daybreak Red', imageInput: true),
    'o1': (name: 'o1', imageInput: true),
    'o1-pro': (name: 'o1-pro', imageInput: true),
    'o3': (name: 'o3', imageInput: true),
    'o3-mini': (name: 'o3-mini', imageInput: false),
    'o3-pro': (name: 'o3-pro', imageInput: true),
    'o4-mini': (name: 'o4-mini', imageInput: true),
  },
  'anthropic': {
    'claude-fable-5': (name: 'Claude Fable 5', imageInput: true),
    'claude-fable-5-1': (name: 'Claude Fable 5.1', imageInput: true),
    'claude-fable-5-2': (name: 'Claude Fable 5.2', imageInput: true),
    'claude-haiku-4-5': (name: 'Claude Haiku 4.5 (latest)', imageInput: true),
    'claude-haiku-4-5-20251001': (name: 'Claude Haiku 4.5', imageInput: true),
    'claude-haiku-5-5': (name: 'Claude Haiku 5.5', imageInput: true),
    'claude-opus-4-5': (name: 'Claude Opus 4.5 (latest)', imageInput: true),
    'claude-opus-4-5-20251101': (name: 'Claude Opus 4.5', imageInput: true),
    'claude-opus-4-6': (name: 'Claude Opus 4.6', imageInput: true),
    'claude-opus-4-7': (name: 'Claude Opus 4.7', imageInput: true),
    'claude-opus-4-8': (name: 'Claude Opus 4.8', imageInput: true),
    'claude-opus-5': (name: 'Claude Opus 5', imageInput: true),
    'claude-opus-5-5': (name: 'Claude Opus 5.5', imageInput: true),
    'claude-sonnet-4-5': (name: 'Claude Sonnet 4.5 (latest)', imageInput: true),
    'claude-sonnet-4-5-20250929': (name: 'Claude Sonnet 4.5', imageInput: true),
    'claude-sonnet-4-6': (name: 'Claude Sonnet 4.6', imageInput: true),
    'claude-sonnet-5': (name: 'Claude Sonnet 5', imageInput: true),
    'claude-sonnet-5-5': (name: 'Claude Sonnet 5.5', imageInput: true),
  },
  'google': {
    'deep-research-max-preview-04-2026': (
      name: 'Deep Research Max Preview (Apr-21-2026)',
      imageInput: true,
    ),
    'deep-research-preview-04-2026': (
      name: 'Deep Research Preview (Apr-21-2026)',
      imageInput: true,
    ),
    'gemini-2.5-computer-use-preview-10-2025': (
      name: 'Gemini 2.5 Computer Use Preview 10-2025',
      imageInput: true,
    ),
    'gemini-2.5-flash': (name: 'Gemini 2.5 Flash', imageInput: true),
    'gemini-2.5-flash-lite': (name: 'Gemini 2.5 Flash-Lite', imageInput: true),
    'gemini-2.5-pro': (name: 'Gemini 2.5 Pro', imageInput: true),
    'gemini-3-flash-preview': (
      name: 'Gemini 3 Flash Preview',
      imageInput: true,
    ),
    'gemini-3.1-flash-lite': (name: 'Gemini 3.1 Flash Lite', imageInput: true),
    'gemini-3.1-flash-lite-preview': (
      name: 'Gemini 3.1 Flash Lite Preview',
      imageInput: true,
    ),
    'gemini-3.1-pro-preview': (
      name: 'Gemini 3.1 Pro Preview',
      imageInput: true,
    ),
    'gemini-3.1-pro-preview-customtools': (
      name: 'Gemini 3.1 Pro Preview Custom Tools',
      imageInput: true,
    ),
    'gemini-3.5-flash': (name: 'Gemini 3.5 Flash', imageInput: true),
    'gemini-3.5-flash-lite': (name: 'Gemini 3.5 Flash Lite', imageInput: true),
    'gemini-3.6-flash': (name: 'Gemini 3.6 Flash', imageInput: true),
    'gemini-3.7-flash': (name: 'Gemini 3.7 Flash', imageInput: true),
    'gemini-3.8-flash': (name: 'Gemini 3.8 Flash', imageInput: true),
    'gemini-4-argon': (name: 'Gemini 4 Argon', imageInput: true),
    'gemini-4-carbon': (name: 'Gemini 4 Carbon', imageInput: true),
    'gemini-4-hydrogen': (name: 'Gemini 4 Hydrogen', imageInput: true),
    'gemini-4-neon': (name: 'Gemini 4 Neon', imageInput: true),
    'gemini-flash-latest': (name: 'Gemini Flash Latest', imageInput: true),
    'gemini-flash-lite-latest': (
      name: 'Gemini Flash-Lite Latest',
      imageInput: true,
    ),
    'gemini-pro-latest': (name: 'Gemini Pro Latest', imageInput: true),
    'gemini-robotics-er-2-preview': (
      name: 'Gemini Robotics-ER 2 Preview',
      imageInput: true,
    ),
    'gemma-4-26b-a4b-it': (name: 'Gemma 4 26B A4B IT', imageInput: true),
    'gemma-4-31b-it': (name: 'Gemma 4 31B IT', imageInput: true),
  },
  'deepseek': {
    'deepseek-flash': (name: 'DeepSeek V4.1 Flash', imageInput: true),
    'deepseek-v4-pro': (name: 'DeepSeek V4 Pro', imageInput: false),
  },
  'openrouter': {
    'aion-labs/aion-2.0': (name: 'AionLabs: Aion-2.0', imageInput: false),
    'aion-labs/aion-3.0': (name: 'AionLabs: Aion-3.0', imageInput: false),
    'aion-labs/aion-3.0-mini': (
      name: 'AionLabs: Aion-3.0-Mini',
      imageInput: false,
    ),
    'aion-labs/aion-3.5': (name: 'AionLabs: Aion 3.5', imageInput: false),
    'aion-labs/aion-3.5-mini': (
      name: 'AionLabs: Aion 3.5 Mini',
      imageInput: false,
    ),
    'amazon/nova-2-lite-v1': (name: 'Amazon: Nova 2 Lite', imageInput: true),
    'amazon/nova-lite-v1': (name: 'Amazon: Nova Lite 1.0', imageInput: true),
    'amazon/nova-micro-v1': (name: 'Amazon: Nova Micro 1.0', imageInput: false),
    'amazon/nova-premier-v1': (
      name: 'Amazon: Nova Premier 1.0',
      imageInput: true,
    ),
    'amazon/nova-pro-v1': (name: 'Amazon: Nova Pro 1.0', imageInput: true),
    'anthropic/claude-fable-5': (
      name: 'Anthropic: Claude Fable 5',
      imageInput: true,
    ),
    'anthropic/claude-fable-5.1': (
      name: 'Anthropic: Claude Fable 5.1',
      imageInput: true,
    ),
    'anthropic/claude-fable-5.1:batch': (
      name: 'Anthropic: Claude Fable 5.1 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-fable-5.2': (
      name: 'Anthropic: Claude Fable 5.2',
      imageInput: true,
    ),
    'anthropic/claude-fable-5.2:batch': (
      name: 'Anthropic: Claude Fable 5.2 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-fable-5:batch': (
      name: 'Anthropic: Claude Fable 5 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-haiku-4.5': (
      name: 'Anthropic: Claude Haiku 4.5',
      imageInput: true,
    ),
    'anthropic/claude-haiku-4.5:batch': (
      name: 'Anthropic: Claude Haiku 4.5 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-haiku-5.5': (
      name: 'Anthropic: Claude Haiku 5.5',
      imageInput: true,
    ),
    'anthropic/claude-haiku-5.5:batch': (
      name: 'Anthropic: Claude Haiku 5.5 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-opus-4.1': (
      name: 'Anthropic: Claude Opus 4.1',
      imageInput: true,
    ),
    'anthropic/claude-opus-4.1:batch': (
      name: 'Anthropic: Claude Opus 4.1 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-opus-4.5': (
      name: 'Anthropic: Claude Opus 4.5',
      imageInput: true,
    ),
    'anthropic/claude-opus-4.5:batch': (
      name: 'Anthropic: Claude Opus 4.5 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-opus-4.6': (
      name: 'Anthropic: Claude Opus 4.6',
      imageInput: true,
    ),
    'anthropic/claude-opus-4.6:batch': (
      name: 'Anthropic: Claude Opus 4.6 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-opus-4.7': (
      name: 'Anthropic: Claude Opus 4.7',
      imageInput: true,
    ),
    'anthropic/claude-opus-4.7:batch': (
      name: 'Anthropic: Claude Opus 4.7 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-opus-4.8': (
      name: 'Anthropic: Claude Opus 4.8',
      imageInput: true,
    ),
    'anthropic/claude-opus-4.8:batch': (
      name: 'Anthropic: Claude Opus 4.8 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-opus-5': (
      name: 'Anthropic: Claude Opus 5',
      imageInput: true,
    ),
    'anthropic/claude-opus-5.5': (
      name: 'Anthropic: Claude Opus 5.5',
      imageInput: true,
    ),
    'anthropic/claude-opus-5.5:batch': (
      name: 'Anthropic: Claude Opus 5.5 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-opus-5:batch': (
      name: 'Anthropic: Claude Opus 5 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-sonnet-4.5': (
      name: 'Anthropic: Claude Sonnet 4.5',
      imageInput: true,
    ),
    'anthropic/claude-sonnet-4.5:batch': (
      name: 'Anthropic: Claude Sonnet 4.5 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-sonnet-4.6': (
      name: 'Anthropic: Claude Sonnet 4.6',
      imageInput: true,
    ),
    'anthropic/claude-sonnet-4.6:batch': (
      name: 'Anthropic: Claude Sonnet 4.6 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-sonnet-5': (
      name: 'Anthropic: Claude Sonnet 5',
      imageInput: true,
    ),
    'anthropic/claude-sonnet-5.5': (
      name: 'Anthropic: Claude Sonnet 5.5',
      imageInput: true,
    ),
    'anthropic/claude-sonnet-5.5:batch': (
      name: 'Anthropic: Claude Sonnet 5.5 (batch)',
      imageInput: true,
    ),
    'anthropic/claude-sonnet-5:batch': (
      name: 'Anthropic: Claude Sonnet 5 (batch)',
      imageInput: true,
    ),
    'auto': (name: 'Auto', imageInput: true),
    'baidu/ernie-5.5-flash-preview:free': (
      name: 'Baidu: ERNIE-5.5-Flash-Preview (free)',
      imageInput: false,
    ),
    'baidu/ernie-light-dt-1.0-intl': (
      name: 'Baidu: ERNIE-Light-DT-1.0',
      imageInput: false,
    ),
    'bytedance-seed/seed-2-1-turbo': (
      name: 'ByteDance Seed: Seed 2.1 Turbo',
      imageInput: true,
    ),
    'bytedance-seed/seed-2.0-lite': (
      name: 'ByteDance Seed: Seed-2.0-Lite',
      imageInput: true,
    ),
    'bytedance-seed/seed-2.0-mini': (
      name: 'ByteDance Seed: Seed-2.0-Mini',
      imageInput: true,
    ),
    'cohere/command-a': (name: 'Cohere: Command A', imageInput: false),
    'cohere/command-a-plus': (name: 'Cohere: Command A+', imageInput: true),
    'cohere/command-r-08-2024': (
      name: 'Cohere: Command R (08-2024)',
      imageInput: false,
    ),
    'cohere/command-r-plus-08-2024': (
      name: 'Cohere: Command R+ (08-2024)',
      imageInput: false,
    ),
    'cohere/command-r7b-12-2024': (
      name: 'Cohere: Command R7B (12-2024)',
      imageInput: false,
    ),
    'deepseek/deepseek-chat': (
      name: 'DeepSeek: DeepSeek V3',
      imageInput: false,
    ),
    'deepseek/deepseek-chat-v3-0324': (
      name: 'DeepSeek: DeepSeek V3 0324',
      imageInput: false,
    ),
    'deepseek/deepseek-chat-v3.1': (
      name: 'DeepSeek: DeepSeek V3.1',
      imageInput: false,
    ),
    'deepseek/deepseek-r1-0528': (name: 'DeepSeek: R1 0528', imageInput: false),
    'deepseek/deepseek-v3.1-terminus': (
      name: 'DeepSeek: DeepSeek V3.1 Terminus',
      imageInput: false,
    ),
    'deepseek/deepseek-v3.2': (
      name: 'DeepSeek: DeepSeek V3.2',
      imageInput: false,
    ),
    'deepseek/deepseek-v3.2-exp': (
      name: 'DeepSeek: DeepSeek V3.2 Exp',
      imageInput: false,
    ),
    'deepseek/deepseek-v4-flash': (
      name: 'DeepSeek: DeepSeek V4 Flash 0423',
      imageInput: false,
    ),
    'deepseek/deepseek-v4-flash-0731': (
      name: 'DeepSeek: DeepSeek V4 Flash 0731',
      imageInput: false,
    ),
    'deepseek/deepseek-v4-flash-0731:batch': (
      name: 'DeepSeek: DeepSeek V4 Flash 0731 (batch)',
      imageInput: false,
    ),
    'deepseek/deepseek-v4-flash-vision-exp': (
      name: 'DeepSeek: DeepSeek V4 Flash Vision Exp',
      imageInput: true,
    ),
    'deepseek/deepseek-v4-pro': (
      name: 'DeepSeek: DeepSeek V4 Pro 0423',
      imageInput: false,
    ),
    'deepseek/deepseek-v4-pro-0813': (
      name: 'DeepSeek: DeepSeek V4 Pro 0813',
      imageInput: false,
    ),
    'deepseek/deepseek-v4.1-flash': (
      name: 'DeepSeek: DeepSeek V4.1 Flash',
      imageInput: true,
    ),
    'deepseek/deepseek-v4.1-flash-1017': (
      name: 'DeepSeek: DeepSeek V4.1 Flash 1017',
      imageInput: true,
    ),
    'deepseek/deepseek-v4.1-flash-1017:batch': (
      name: 'DeepSeek: DeepSeek V4.1 Flash 1017 (batch)',
      imageInput: true,
    ),
    'deepseek/deepseek-v4.1-flash:batch': (
      name: 'DeepSeek: DeepSeek V4.1 Flash (batch)',
      imageInput: true,
    ),
    'dots-studio/dots-3-note-preview:free': (
      name: 'Dots Studio: Dots3-Note Preview (free)',
      imageInput: true,
    ),
    'elorian/glimpse': (name: 'Elorian: Glimpse', imageInput: true),
    'fireworks/ember-1': (name: 'Fireworks: Ember-1', imageInput: true),
    'google/gemini-2.5-flash': (
      name: 'Google: Gemini 2.5 Flash',
      imageInput: true,
    ),
    'google/gemini-2.5-flash-lite': (
      name: 'Google: Gemini 2.5 Flash Lite',
      imageInput: true,
    ),
    'google/gemini-2.5-pro': (name: 'Google: Gemini 2.5 Pro', imageInput: true),
    'google/gemini-2.5-pro-preview': (
      name: 'Google: Gemini 2.5 Pro Preview 06-05',
      imageInput: true,
    ),
    'google/gemini-3-flash-preview': (
      name: 'Google: Gemini 3 Flash Preview',
      imageInput: true,
    ),
    'google/gemini-3-flash-preview:batch': (
      name: 'Google: Gemini 3 Flash Preview (batch)',
      imageInput: true,
    ),
    'google/gemini-3-pro-image': (
      name: 'Google: Nano Banana Pro (Gemini 3 Pro Image)',
      imageInput: true,
    ),
    'google/gemini-3.1-flash-lite': (
      name: 'Google: Gemini 3.1 Flash Lite',
      imageInput: true,
    ),
    'google/gemini-3.1-flash-lite-preview': (
      name: 'Google: Gemini 3.1 Flash Lite Preview',
      imageInput: true,
    ),
    'google/gemini-3.1-flash-lite:batch': (
      name: 'Google: Gemini 3.1 Flash Lite (batch)',
      imageInput: true,
    ),
    'google/gemini-3.1-pro-preview': (
      name: 'Google: Gemini 3.1 Pro Preview',
      imageInput: true,
    ),
    'google/gemini-3.1-pro-preview-customtools': (
      name: 'Google: Gemini 3.1 Pro Preview Custom Tools',
      imageInput: true,
    ),
    'google/gemini-3.1-pro-preview:batch': (
      name: 'Google: Gemini 3.1 Pro Preview (batch)',
      imageInput: true,
    ),
    'google/gemini-3.5-flash': (
      name: 'Google: Gemini 3.5 Flash',
      imageInput: true,
    ),
    'google/gemini-3.5-flash-lite': (
      name: 'Google: Gemini 3.5 Flash Lite',
      imageInput: true,
    ),
    'google/gemini-3.5-flash-lite:batch': (
      name: 'Google: Gemini 3.5 Flash Lite (batch)',
      imageInput: true,
    ),
    'google/gemini-3.5-flash:batch': (
      name: 'Google: Gemini 3.5 Flash (batch)',
      imageInput: true,
    ),
    'google/gemini-3.6-flash': (
      name: 'Google: Gemini 3.6 Flash',
      imageInput: true,
    ),
    'google/gemini-3.6-flash:batch': (
      name: 'Google: Gemini 3.6 Flash (batch)',
      imageInput: true,
    ),
    'google/gemini-3.7-flash': (
      name: 'Google: Gemini 3.7 Flash',
      imageInput: true,
    ),
    'google/gemini-3.7-flash:batch': (
      name: 'Google: Gemini 3.7 Flash (batch)',
      imageInput: true,
    ),
    'google/gemini-3.8-flash': (
      name: 'Google: Gemini 3.8 Flash',
      imageInput: true,
    ),
    'google/gemini-3.8-flash:batch': (
      name: 'Google: Gemini 3.8 Flash (batch)',
      imageInput: true,
    ),
    'google/gemini-4-argon': (name: 'Google: Gemini 4 Argon', imageInput: true),
    'google/gemini-4-argon:batch': (
      name: 'Google: Gemini 4 Argon (batch)',
      imageInput: true,
    ),
    'google/gemini-4-carbon': (
      name: 'Google: Gemini 4 Carbon',
      imageInput: true,
    ),
    'google/gemini-4-carbon:batch': (
      name: 'Google: Gemini 4 Carbon (batch)',
      imageInput: true,
    ),
    'google/gemini-4-hydrogen': (
      name: 'Google: Gemini 4 Hydrogen',
      imageInput: true,
    ),
    'google/gemini-4-hydrogen:batch': (
      name: 'Google: Gemini 4 Hydrogen (batch)',
      imageInput: true,
    ),
    'google/gemini-4-neon': (name: 'Google: Gemini 4 Neon', imageInput: true),
    'google/gemini-4-neon:batch': (
      name: 'Google: Gemini 4 Neon (batch)',
      imageInput: true,
    ),
    'google/gemini-nano-banana-2.1': (
      name: 'Google: Nano Banana 2.1',
      imageInput: true,
    ),
    'google/gemma-3-12b-it': (name: 'Google: Gemma 3 12B', imageInput: true),
    'google/gemma-3-27b-it': (name: 'Google: Gemma 3 27B', imageInput: true),
    'google/gemma-4-26b-a4b-it': (
      name: 'Google: Gemma 4 26B A4B',
      imageInput: true,
    ),
    'google/gemma-4-26b-a4b-it:free': (
      name: 'Google: Gemma 4 26B A4B  (free)',
      imageInput: true,
    ),
    'google/gemma-4-31b-it': (name: 'Google: Gemma 4 31B', imageInput: true),
    'google/gemma-4-31b-it:free': (
      name: 'Google: Gemma 4 31B (free)',
      imageInput: true,
    ),
    'ibm-granite/granite-4.2-8b': (
      name: 'IBM: Granite 4.2 8B',
      imageInput: false,
    ),
    'inclusionai/ling-3.0-flash': (
      name: 'inclusionAI: Ling 3.0 Flash',
      imageInput: false,
    ),
    'inclusionai/ling-3.0-flash-vl': (
      name: 'inclusionAI: Ling 3.0 Flash VL',
      imageInput: true,
    ),
    'inclusionai/ling-3.0-tiny': (
      name: 'inclusionAI: Ling 3.0 Tiny',
      imageInput: false,
    ),
    'inclusionai/ling-3.1-flash': (
      name: 'inclusionAI: Ling 3.1 Flash',
      imageInput: false,
    ),
    'inclusionai/ling-3.2-flash:free': (
      name: 'inclusionAI: Ling 3.2 Flash (free)',
      imageInput: true,
    ),
    'kt/midm-k-3.0-pro': (name: 'KT: Mi:dm K 3.0 Pro', imageInput: false),
    'liquid/lfm-2.5-24b-a2b': (
      name: 'LiquidAI: LFM2.5-24B-A2B',
      imageInput: false,
    ),
    'liquid/lfm-3-1.7b': (name: 'LiquidAI: LFM3-1.7B', imageInput: false),
    'liquid/lfm-3-1.7b:free': (
      name: 'LiquidAI: LFM3-1.7B (free)',
      imageInput: false,
    ),
    'meituan/longcat-2.0': (name: 'Meituan: LongCat 2.0', imageInput: false),
    'meta-llama/llama-3.1-70b-instruct': (
      name: 'Meta: Llama 3.1 70B Instruct',
      imageInput: false,
    ),
    'meta-llama/llama-3.1-8b-instruct': (
      name: 'Meta: Llama 3.1 8B Instruct',
      imageInput: false,
    ),
    'meta-llama/llama-3.3-70b-instruct': (
      name: 'Meta: Llama 3.3 70B Instruct',
      imageInput: false,
    ),
    'meta-llama/llama-4-maverick': (
      name: 'Meta: Llama 4 Maverick',
      imageInput: true,
    ),
    'meta-llama/llama-4-scout': (name: 'Meta: Llama 4 Scout', imageInput: true),
    'meta/muse-ember': (name: 'Meta: Muse Ember', imageInput: true),
    'meta/muse-glimmer-30b': (name: 'Meta: Muse Glimmer 30B', imageInput: true),
    'meta/muse-glimmer-30b:batch': (
      name: 'Meta: Muse Glimmer 30B (batch)',
      imageInput: true,
    ),
    'meta/muse-spark-1.1': (name: 'Meta: Muse Spark 1.1', imageInput: true),
    'meta/muse-spark-1.2': (name: 'Meta: Muse Spark 1.2', imageInput: true),
    'meta/muse-spark-1.2-contributor': (
      name: 'Meta: Muse Spark 1.2 Contributor',
      imageInput: true,
    ),
    'meta/muse-spark-1.3': (name: 'Meta: Muse Spark 1.3', imageInput: true),
    'meta/muse-spark-1.3-contributor': (
      name: 'Meta: Muse Spark 1.3 Contributor',
      imageInput: true,
    ),
    'meta/muse-spark-open': (name: 'Meta: Muse Spark Open', imageInput: true),
    'meta/muse-wonder': (name: 'Meta: Muse Wonder', imageInput: true),
    'minimax/minimax-m2.5': (name: 'MiniMax: MiniMax M2.5', imageInput: false),
    'minimax/minimax-m2.7': (name: 'MiniMax: MiniMax M2.7', imageInput: false),
    'minimax/minimax-m3': (name: 'MiniMax: MiniMax M3', imageInput: true),
    'minimax/minimax-m3.1-flash': (
      name: 'MiniMax: MiniMax M3.1 Flash',
      imageInput: true,
    ),
    'minimax/minimax-m3:batch': (
      name: 'MiniMax: MiniMax M3 (batch)',
      imageInput: true,
    ),
    'mistralai/codestral-2508': (
      name: 'Mistral: Codestral 2508',
      imageInput: false,
    ),
    'mistralai/devstral-2512': (
      name: 'Mistral: Devstral 2 2512',
      imageInput: false,
    ),
    'mistralai/ministral-14b-2512': (
      name: 'Mistral: Ministral 3 14B 2512',
      imageInput: true,
    ),
    'mistralai/ministral-3b-2512': (
      name: 'Mistral: Ministral 3 3B 2512',
      imageInput: true,
    ),
    'mistralai/ministral-8b-2512': (
      name: 'Mistral: Ministral 3 8B 2512',
      imageInput: true,
    ),
    'mistralai/mistral-large': (name: 'Mistral Large', imageInput: false),
    'mistralai/mistral-large-2407': (
      name: 'Mistral Large 2407',
      imageInput: false,
    ),
    'mistralai/mistral-large-2512': (
      name: 'Mistral: Mistral Large 3 2512',
      imageInput: true,
    ),
    'mistralai/mistral-large-4-0': (
      name: 'Mistral: Mistral Large 4',
      imageInput: true,
    ),
    'mistralai/mistral-medium-3': (
      name: 'Mistral: Mistral Medium 3',
      imageInput: true,
    ),
    'mistralai/mistral-medium-3-5': (
      name: 'Mistral: Mistral Medium 3.5',
      imageInput: true,
    ),
    'mistralai/mistral-medium-3-5:batch': (
      name: 'Mistral: Mistral Medium 3.5 (batch)',
      imageInput: true,
    ),
    'mistralai/mistral-medium-3.1': (
      name: 'Mistral: Mistral Medium 3.1',
      imageInput: true,
    ),
    'mistralai/mistral-nemo': (
      name: 'Mistral: Mistral Nemo',
      imageInput: false,
    ),
    'mistralai/mistral-saba': (name: 'Mistral: Saba', imageInput: false),
    'mistralai/mistral-small-2603': (
      name: 'Mistral: Mistral Small 4',
      imageInput: true,
    ),
    'mistralai/mistral-small-3.1-24b-instruct': (
      name: 'Mistral: Mistral Small 3.1 24B',
      imageInput: true,
    ),
    'mistralai/mistral-small-3.2-24b-instruct': (
      name: 'Mistral: Mistral Small 3.2 24B',
      imageInput: true,
    ),
    'mistralai/mixtral-8x22b-instruct': (
      name: 'Mistral: Mixtral 8x22B Instruct',
      imageInput: false,
    ),
    'mistralai/voxtral-small-24b-2507': (
      name: 'Mistral: Voxtral Small 24B 2507',
      imageInput: false,
    ),
    'moonshotai/kimi-k2': (name: 'MoonshotAI: Kimi K2 0711', imageInput: false),
    'moonshotai/kimi-k2-0905': (
      name: 'MoonshotAI: Kimi K2 0905',
      imageInput: false,
    ),
    'moonshotai/kimi-k2-thinking': (
      name: 'MoonshotAI: Kimi K2 Thinking',
      imageInput: false,
    ),
    'moonshotai/kimi-k2.5': (name: 'MoonshotAI: Kimi K2.5', imageInput: true),
    'moonshotai/kimi-k2.6': (name: 'MoonshotAI: Kimi K2.6', imageInput: true),
    'moonshotai/kimi-k2.7-code': (
      name: 'MoonshotAI: Kimi K2.7 Code',
      imageInput: true,
    ),
    'moonshotai/kimi-k3': (name: 'MoonshotAI: Kimi K3', imageInput: true),
    'moonshotai/kimi-k3.1-pro': (
      name: 'MoonshotAI: Kimi K3.1 Pro',
      imageInput: true,
    ),
    'moonshotai/kimi-k3.1-pro:batch': (
      name: 'MoonshotAI: Kimi K3.1 Pro (batch)',
      imageInput: true,
    ),
    'moonshotai/kimi-k3:batch': (
      name: 'MoonshotAI: Kimi K3 (batch)',
      imageInput: true,
    ),
    'motif-technologies/motif-3': (
      name: 'Motif Technologies: Motif 3',
      imageInput: false,
    ),
    'nex-agi/nex-n2.5-pro': (name: 'Nex AGI: Nex-N2.5-Pro', imageInput: true),
    'nex-agi/nex-n2.6': (name: 'Nex AGI: Nex-N2.6', imageInput: true),
    'nvidia/nemotron-3-nano-30b-a3b': (
      name: 'NVIDIA: Nemotron 3 Nano 30B A3B',
      imageInput: false,
    ),
    'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free': (
      name: 'NVIDIA: Nemotron 3 Nano Omni (free)',
      imageInput: true,
    ),
    'nvidia/nemotron-3-super-120b-a12b': (
      name: 'NVIDIA: Nemotron 3 Super',
      imageInput: false,
    ),
    'nvidia/nemotron-3-ultra-550b-a55b': (
      name: 'NVIDIA: Nemotron 3 Ultra',
      imageInput: false,
    ),
    'nvidia/nemotron-3-ultra-550b-a55b:free': (
      name: 'NVIDIA: Nemotron 3 Ultra (free)',
      imageInput: false,
    ),
    'nvidia/nemotron-3.5-lightning': (
      name: 'NVIDIA: Nemotron 3.5 Lightning',
      imageInput: false,
    ),
    'nvidia/nemotron-3.5-lightning:free': (
      name: 'NVIDIA: Nemotron 3.5 Lightning (free)',
      imageInput: false,
    ),
    'nvidia/nemotron-3.5-super-vl': (
      name: 'NVIDIA: Nemotron 3.5 Super VL',
      imageInput: true,
    ),
    'nvidia/nemotron-3.5-super-vl:free': (
      name: 'NVIDIA: Nemotron 3.5 Super VL (free)',
      imageInput: true,
    ),
    'openai/gpt-3.5-turbo-0613': (
      name: 'OpenAI: GPT-3.5 Turbo (older v0613)',
      imageInput: false,
    ),
    'openai/gpt-3.5-turbo-16k': (
      name: 'OpenAI: GPT-3.5 Turbo 16k',
      imageInput: false,
    ),
    'openai/gpt-4': (name: 'OpenAI: GPT-4', imageInput: false),
    'openai/gpt-4-turbo:batch': (
      name: 'OpenAI: GPT-4 Turbo (batch)',
      imageInput: true,
    ),
    'openai/gpt-4.1': (name: 'OpenAI: GPT-4.1', imageInput: true),
    'openai/gpt-4.1-mini': (name: 'OpenAI: GPT-4.1 Mini', imageInput: true),
    'openai/gpt-4.1-mini:batch': (
      name: 'OpenAI: GPT-4.1 Mini (batch)',
      imageInput: true,
    ),
    'openai/gpt-4.1-nano': (name: 'OpenAI: GPT-4.1 Nano', imageInput: true),
    'openai/gpt-4.1-nano:batch': (
      name: 'OpenAI: GPT-4.1 Nano (batch)',
      imageInput: true,
    ),
    'openai/gpt-4.1:batch': (name: 'OpenAI: GPT-4.1 (batch)', imageInput: true),
    'openai/gpt-4o': (name: 'OpenAI: GPT-4o', imageInput: true),
    'openai/gpt-4o-2024-05-13': (
      name: 'OpenAI: GPT-4o (2024-05-13)',
      imageInput: true,
    ),
    'openai/gpt-4o-2024-08-06': (
      name: 'OpenAI: GPT-4o (2024-08-06)',
      imageInput: true,
    ),
    'openai/gpt-4o-2024-11-20': (
      name: 'OpenAI: GPT-4o (2024-11-20)',
      imageInput: true,
    ),
    'openai/gpt-4o-mini': (name: 'OpenAI: GPT-4o-mini', imageInput: true),
    'openai/gpt-4o-mini-2024-07-18': (
      name: 'OpenAI: GPT-4o-mini (2024-07-18)',
      imageInput: true,
    ),
    'openai/gpt-4o-mini:batch': (
      name: 'OpenAI: GPT-4o-mini (batch)',
      imageInput: true,
    ),
    'openai/gpt-4o:batch': (name: 'OpenAI: GPT-4o (batch)', imageInput: true),
    'openai/gpt-5': (name: 'OpenAI: GPT-5', imageInput: true),
    'openai/gpt-5-mini': (name: 'OpenAI: GPT-5 Mini', imageInput: true),
    'openai/gpt-5-mini:batch': (
      name: 'OpenAI: GPT-5 Mini (batch)',
      imageInput: true,
    ),
    'openai/gpt-5-nano': (name: 'OpenAI: GPT-5 Nano', imageInput: true),
    'openai/gpt-5-nano:batch': (
      name: 'OpenAI: GPT-5 Nano (batch)',
      imageInput: true,
    ),
    'openai/gpt-5-pro': (name: 'OpenAI: GPT-5 Pro', imageInput: true),
    'openai/gpt-5-pro:batch': (
      name: 'OpenAI: GPT-5 Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-5.1': (name: 'OpenAI: GPT-5.1', imageInput: true),
    'openai/gpt-5.1-codex': (name: 'OpenAI: GPT-5.1-Codex', imageInput: true),
    'openai/gpt-5.1-codex-max': (
      name: 'OpenAI: GPT-5.1-Codex-Max',
      imageInput: true,
    ),
    'openai/gpt-5.1-codex-mini': (
      name: 'OpenAI: GPT-5.1-Codex-Mini',
      imageInput: true,
    ),
    'openai/gpt-5.1:batch': (name: 'OpenAI: GPT-5.1 (batch)', imageInput: true),
    'openai/gpt-5.2': (name: 'OpenAI: GPT-5.2', imageInput: true),
    'openai/gpt-5.2-chat': (name: 'OpenAI: GPT-5.2 Chat', imageInput: true),
    'openai/gpt-5.2-codex': (name: 'OpenAI: GPT-5.2-Codex', imageInput: true),
    'openai/gpt-5.2-pro': (name: 'OpenAI: GPT-5.2 Pro', imageInput: true),
    'openai/gpt-5.2-pro:batch': (
      name: 'OpenAI: GPT-5.2 Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-5.2:batch': (name: 'OpenAI: GPT-5.2 (batch)', imageInput: true),
    'openai/gpt-5.3-codex': (name: 'OpenAI: GPT-5.3-Codex', imageInput: true),
    'openai/gpt-5.4': (name: 'OpenAI: GPT-5.4', imageInput: true),
    'openai/gpt-5.4-mini': (name: 'OpenAI: GPT-5.4 Mini', imageInput: true),
    'openai/gpt-5.4-mini:batch': (
      name: 'OpenAI: GPT-5.4 Mini (batch)',
      imageInput: true,
    ),
    'openai/gpt-5.4-nano': (name: 'OpenAI: GPT-5.4 Nano', imageInput: true),
    'openai/gpt-5.4-nano:batch': (
      name: 'OpenAI: GPT-5.4 Nano (batch)',
      imageInput: true,
    ),
    'openai/gpt-5.4-pro': (name: 'OpenAI: GPT-5.4 Pro', imageInput: true),
    'openai/gpt-5.4-pro:batch': (
      name: 'OpenAI: GPT-5.4 Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-5.4:batch': (name: 'OpenAI: GPT-5.4 (batch)', imageInput: true),
    'openai/gpt-5.5': (name: 'OpenAI: GPT-5.5', imageInput: true),
    'openai/gpt-5.5-pro': (name: 'OpenAI: GPT-5.5 Pro', imageInput: true),
    'openai/gpt-5.5-pro:batch': (
      name: 'OpenAI: GPT-5.5 Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-5.5:batch': (name: 'OpenAI: GPT-5.5 (batch)', imageInput: true),
    'openai/gpt-5.6-luna': (name: 'OpenAI: GPT-5.6 Luna', imageInput: true),
    'openai/gpt-5.6-luna-pro': (
      name: 'OpenAI: GPT-5.6 Luna Pro',
      imageInput: true,
    ),
    'openai/gpt-5.6-luna-pro:batch': (
      name: 'OpenAI: GPT-5.6 Luna Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-5.6-luna:batch': (
      name: 'OpenAI: GPT-5.6 Luna (batch)',
      imageInput: true,
    ),
    'openai/gpt-5.6-sol': (name: 'OpenAI: GPT-5.6 Sol', imageInput: true),
    'openai/gpt-5.6-sol-pro': (
      name: 'OpenAI: GPT-5.6 Sol Pro',
      imageInput: true,
    ),
    'openai/gpt-5.6-sol-pro:batch': (
      name: 'OpenAI: GPT-5.6 Sol Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-5.6-sol:batch': (
      name: 'OpenAI: GPT-5.6 Sol (batch)',
      imageInput: true,
    ),
    'openai/gpt-5.6-terra': (name: 'OpenAI: GPT-5.6 Terra', imageInput: true),
    'openai/gpt-5.6-terra-pro': (
      name: 'OpenAI: GPT-5.6 Terra Pro',
      imageInput: true,
    ),
    'openai/gpt-5.6-terra-pro:batch': (
      name: 'OpenAI: GPT-5.6 Terra Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-5.6-terra:batch': (
      name: 'OpenAI: GPT-5.6 Terra (batch)',
      imageInput: true,
    ),
    'openai/gpt-5:batch': (name: 'OpenAI: GPT-5 (batch)', imageInput: true),
    'openai/gpt-6-astra': (name: 'OpenAI: GPT-6 Astra', imageInput: true),
    'openai/gpt-6-astra-pro': (
      name: 'OpenAI: GPT-6 Astra Pro',
      imageInput: true,
    ),
    'openai/gpt-6-astra-pro:batch': (
      name: 'OpenAI: GPT-6 Astra Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-6-astra:batch': (
      name: 'OpenAI: GPT-6 Astra (batch)',
      imageInput: true,
    ),
    'openai/gpt-6-luna': (name: 'OpenAI: GPT-6 Luna', imageInput: true),
    'openai/gpt-6-luna-pro': (name: 'OpenAI: GPT-6 Luna Pro', imageInput: true),
    'openai/gpt-6-luna-pro:batch': (
      name: 'OpenAI: GPT-6 Luna Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-6-luna:batch': (
      name: 'OpenAI: GPT-6 Luna (batch)',
      imageInput: true,
    ),
    'openai/gpt-6-sol': (name: 'OpenAI: GPT-6 Sol', imageInput: true),
    'openai/gpt-6-sol-pro': (name: 'OpenAI: GPT-6 Sol Pro', imageInput: true),
    'openai/gpt-6-sol-pro:batch': (
      name: 'OpenAI: GPT-6 Sol Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-6-sol:batch': (
      name: 'OpenAI: GPT-6 Sol (batch)',
      imageInput: true,
    ),
    'openai/gpt-6.1-sol': (name: 'OpenAI: GPT-6.1 Sol', imageInput: true),
    'openai/gpt-6.1-sol-pro': (
      name: 'OpenAI: GPT-6.1 Sol Pro',
      imageInput: true,
    ),
    'openai/gpt-6.1-sol-pro:batch': (
      name: 'OpenAI: GPT-6.1 Sol Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-6.1-sol:batch': (
      name: 'OpenAI: GPT-6.1 Sol (batch)',
      imageInput: true,
    ),
    'openai/gpt-6.1-terra': (name: 'OpenAI: GPT-6.1 Terra', imageInput: true),
    'openai/gpt-6.1-terra-pro': (
      name: 'OpenAI: GPT-6.1 Terra Pro',
      imageInput: true,
    ),
    'openai/gpt-6.1-terra-pro:batch': (
      name: 'OpenAI: GPT-6.1 Terra Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-6.1-terra:batch': (
      name: 'OpenAI: GPT-6.1 Terra (batch)',
      imageInput: true,
    ),
    'openai/gpt-6.2-astra': (name: 'OpenAI: GPT-6.2 Astra', imageInput: true),
    'openai/gpt-6.2-astra-pro': (
      name: 'OpenAI: GPT-6.2 Astra Pro',
      imageInput: true,
    ),
    'openai/gpt-6.2-astra-pro:batch': (
      name: 'OpenAI: GPT-6.2 Astra Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-6.2-astra:batch': (
      name: 'OpenAI: GPT-6.2 Astra (batch)',
      imageInput: true,
    ),
    'openai/gpt-6.2-sol': (name: 'OpenAI: GPT-6.2 Sol', imageInput: true),
    'openai/gpt-6.2-sol-pro': (
      name: 'OpenAI: GPT-6.2 Sol Pro',
      imageInput: true,
    ),
    'openai/gpt-6.2-sol-pro:batch': (
      name: 'OpenAI: GPT-6.2 Sol Pro (batch)',
      imageInput: true,
    ),
    'openai/gpt-6.2-sol:batch': (
      name: 'OpenAI: GPT-6.2 Sol (batch)',
      imageInput: true,
    ),
    'openai/gpt-audio': (name: 'OpenAI: GPT Audio', imageInput: false),
    'openai/gpt-audio-mini': (
      name: 'OpenAI: GPT Audio Mini',
      imageInput: false,
    ),
    'openai/gpt-chat-latest': (
      name: 'OpenAI: GPT Chat Latest',
      imageInput: true,
    ),
    'openai/gpt-oss-120b': (name: 'OpenAI: gpt-oss-120b', imageInput: false),
    'openai/gpt-oss-120b:batch': (
      name: 'OpenAI: gpt-oss-120b (batch)',
      imageInput: false,
    ),
    'openai/gpt-oss-20b': (name: 'OpenAI: gpt-oss-20b', imageInput: false),
    'openai/gpt-oss-20b:batch': (
      name: 'OpenAI: gpt-oss-20b (batch)',
      imageInput: false,
    ),
    'openai/gpt-oss-safeguard-20b': (
      name: 'OpenAI: gpt-oss-safeguard-20b',
      imageInput: false,
    ),
    'openai/o3': (name: 'OpenAI: o3', imageInput: true),
    'openai/o3-mini:batch': (
      name: 'OpenAI: o3 Mini (batch)',
      imageInput: false,
    ),
    'openai/o3-pro': (name: 'OpenAI: o3 Pro', imageInput: true),
    'openai/o3:batch': (name: 'OpenAI: o3 (batch)', imageInput: true),
    'openai/o4-mini:batch': (name: 'OpenAI: o4 Mini (batch)', imageInput: true),
    'openrouter/auto': (name: 'Auto Router', imageInput: true),
    'openrouter/auto-beta': (name: 'Auto Router (Beta)', imageInput: true),
    'openrouter/auto-code': (name: 'Auto Code', imageInput: true),
    'openrouter/free': (name: 'Free Models Router', imageInput: true),
    'openrouter/fusion': (name: 'OpenRouter: Fusion', imageInput: false),
    'openrouter/pareto-code': (name: 'Pareto Code Router', imageInput: false),
    'particle-ai/particle-1': (
      name: 'Particle AI: Particle-1',
      imageInput: true,
    ),
    'particle-ai/particle-1:free': (
      name: 'Particle AI: Particle-1 (free)',
      imageInput: true,
    ),
    'perceptron/perceptron-mk1.5': (
      name: 'Perceptron: Perceptron Mk1.5',
      imageInput: true,
    ),
    'prism-ml/ternary-bonsai-2-27b': (
      name: 'PrismML: Ternary Bonsai 2 27B',
      imageInput: true,
    ),
    'prism-ml/ternary-bonsai-2-9b': (
      name: 'PrismML: Ternary Bonsai 2 9B',
      imageInput: true,
    ),
    'qwen/qwen-2.5-72b-instruct': (
      name: 'Qwen2.5 72B Instruct',
      imageInput: false,
    ),
    'qwen/qwen-plus': (name: 'Qwen: Qwen-Plus', imageInput: false),
    'qwen/qwen3-14b': (name: 'Qwen: Qwen3 14B', imageInput: false),
    'qwen/qwen3-235b-a22b-2507': (
      name: 'Qwen: Qwen3 235B A22B Instruct 2507',
      imageInput: false,
    ),
    'qwen/qwen3-235b-a22b-thinking-2507': (
      name: 'Qwen: Qwen3 235B A22B Thinking 2507',
      imageInput: false,
    ),
    'qwen/qwen3-30b-a3b': (name: 'Qwen: Qwen3 30B A3B', imageInput: false),
    'qwen/qwen3-30b-a3b-instruct-2507': (
      name: 'Qwen: Qwen3 30B A3B Instruct 2507',
      imageInput: false,
    ),
    'qwen/qwen3-32b': (name: 'Qwen: Qwen3 32B', imageInput: false),
    'qwen/qwen3-coder': (
      name: 'Qwen: Qwen3 Coder 480B A35B',
      imageInput: false,
    ),
    'qwen/qwen3-coder-30b-a3b-instruct': (
      name: 'Qwen: Qwen3 Coder 30B A3B Instruct',
      imageInput: false,
    ),
    'qwen/qwen3-coder-flash': (
      name: 'Qwen: Qwen3 Coder Flash',
      imageInput: false,
    ),
    'qwen/qwen3-coder-next': (
      name: 'Qwen: Qwen3 Coder Next',
      imageInput: false,
    ),
    'qwen/qwen3-next-80b-a3b-instruct': (
      name: 'Qwen: Qwen3 Next 80B A3B Instruct',
      imageInput: false,
    ),
    'qwen/qwen3-vl-235b-a22b-instruct': (
      name: 'Qwen: Qwen3 VL 235B A22B Instruct',
      imageInput: true,
    ),
    'qwen/qwen3-vl-30b-a3b-instruct': (
      name: 'Qwen: Qwen3 VL 30B A3B Instruct',
      imageInput: true,
    ),
    'qwen/qwen3-vl-8b-instruct': (
      name: 'Qwen: Qwen3 VL 8B Instruct',
      imageInput: true,
    ),
    'qwen/qwen3.5-122b-a10b': (
      name: 'Qwen: Qwen3.5-122B-A10B',
      imageInput: true,
    ),
    'qwen/qwen3.5-27b': (name: 'Qwen: Qwen3.5-27B', imageInput: true),
    'qwen/qwen3.5-35b-a3b': (name: 'Qwen: Qwen3.5-35B-A3B', imageInput: true),
    'qwen/qwen3.5-397b-a17b': (
      name: 'Qwen: Qwen3.5 397B A17B',
      imageInput: true,
    ),
    'qwen/qwen3.5-9b': (name: 'Qwen: Qwen3.5-9B', imageInput: true),
    'qwen/qwen3.5-flash-02-23': (name: 'Qwen: Qwen3.5-Flash', imageInput: true),
    'qwen/qwen3.5-plus-02-15': (
      name: 'Qwen: Qwen3.5 Plus 2026-02-15',
      imageInput: true,
    ),
    'qwen/qwen3.5-plus-20260420': (
      name: 'Qwen: Qwen3.5 Plus 2026-04-20',
      imageInput: true,
    ),
    'qwen/qwen3.6-27b': (name: 'Qwen: Qwen3.6 27B', imageInput: true),
    'qwen/qwen3.6-35b-a3b': (name: 'Qwen: Qwen3.6 35B A3B', imageInput: true),
    'qwen/qwen3.6-flash': (name: 'Qwen: Qwen3.6 Flash', imageInput: true),
    'qwen/qwen3.6-plus': (name: 'Qwen: Qwen3.6 Plus', imageInput: true),
    'qwen/qwen3.7-flash': (name: 'Qwen: Qwen3.7 Flash', imageInput: true),
    'qwen/qwen3.7-max': (name: 'Qwen: Qwen3.7 Max', imageInput: false),
    'qwen/qwen3.7-plus': (name: 'Qwen: Qwen3.7 Plus', imageInput: true),
    'qwen/qwen3.7-plus:batch': (
      name: 'Qwen: Qwen3.7 Plus (batch)',
      imageInput: true,
    ),
    'qwen/qwen3.8-2.4t-a95b': (
      name: 'Qwen: Qwen3.8 2.4T A95B',
      imageInput: false,
    ),
    'qwen/qwen3.8-27b': (name: 'Qwen: Qwen3.8 27B', imageInput: true),
    'qwen/qwen3.8-27b:batch': (
      name: 'Qwen: Qwen3.8 27B (batch)',
      imageInput: true,
    ),
    'qwen/qwen3.8-flash': (name: 'Qwen: Qwen3.8 Flash', imageInput: true),
    'qwen/qwen3.8-max-0902': (
      name: 'Qwen: Qwen3.8 Max (0902)',
      imageInput: true,
    ),
    'qwen/qwen3.8-max-0902:batch': (
      name: 'Qwen: Qwen3.8 Max (0902) (batch)',
      imageInput: true,
    ),
    'qwen/qwen3.8-max-prime': (
      name: 'Qwen: Qwen3.8 Max Prime',
      imageInput: true,
    ),
    'qwen/qwen3.8-omni-flash': (
      name: 'Qwen: Qwen3.8 Omni Flash',
      imageInput: true,
    ),
    'qwen/qwen4-max': (name: 'Qwen: Qwen4 Max', imageInput: true),
    'recursive/flint-v1.0:free': (
      name: 'Recursive: Flint (free)',
      imageInput: false,
    ),
    'reflection/beam-1.0-501b-a23b': (
      name: 'Reflection: Beam 1.0 501B A23B',
      imageInput: false,
    ),
    'rekaai/reka-edge': (name: 'Reka Edge', imageInput: true),
    'relace/relace-search': (name: 'Relace: Relace Search', imageInput: false),
    'ricursiveai/ripple-65b-preview': (
      name: 'Ricursive: Ripple 65B Preview',
      imageInput: false,
    ),
    'sakana/fugu-max': (name: 'Sakana: Fugu Max', imageInput: true),
    'sakana/fugu-ultra': (name: 'Sakana: Fugu Ultra', imageInput: true),
    'sakana/fugu-ultra-v2': (name: 'Sakana: Fugu Ultra v2', imageInput: true),
    'sakana/sakana-namazu': (name: 'Sakana: Sakana Namazu', imageInput: true),
    'stepfun/step-3.7-flash': (
      name: 'StepFun: Step 3.7 Flash',
      imageInput: true,
    ),
    'stepfun/step-5-preview': (
      name: 'StepFun: Step 5 Preview',
      imageInput: true,
    ),
    'tencent/hy3': (name: 'Tencent: Hy3', imageInput: false),
    'tencent/hy3-preview': (name: 'Tencent: Hy3 preview', imageInput: false),
    'tencent/hy4': (name: 'Tencent: Hy4', imageInput: true),
    'tencent/hy4-flash': (name: 'Tencent: Hy4 flash', imageInput: true),
    'tencent/hy4-preview': (name: 'Tencent: Hy4 preview', imageInput: false),
    'thinkingmachines/inkling': (
      name: 'Thinking Machines: Inkling',
      imageInput: true,
    ),
    'thinkingmachines/inkling-2-small': (
      name: 'Thinking Machines: Inkling 2 Small',
      imageInput: true,
    ),
    'thinkingmachines/inkling-small': (
      name: 'Thinking Machines: Inkling Small',
      imageInput: true,
    ),
    'thinkingmachines/inkling-small:batch': (
      name: 'Thinking Machines: Inkling Small (batch)',
      imageInput: true,
    ),
    'typesafe/jev-router': (name: 'TypeSafe: Jev Router', imageInput: true),
    'unbiased/pareto-26.10': (name: 'Pareto 26.10', imageInput: true),
    'unbiased/pareto-26.10-preview': (
      name: 'Pareto 26.10 Preview',
      imageInput: true,
    ),
    'unbiased/pareto-26.9': (name: 'Pareto 26.9', imageInput: true),
    'upstage/solar-mini4': (name: 'Upstage: Solar Mini 4', imageInput: false),
    'upstage/solar-pro4': (name: 'Upstage: Solar Pro 4', imageInput: false),
    'x-ai/grok-4.20': (name: 'SpaceXSI: Grok 4.20', imageInput: true),
    'x-ai/grok-4.3': (name: 'SpaceXSI: Grok 4.3', imageInput: true),
    'x-ai/grok-4.3:batch': (
      name: 'SpaceXSI: Grok 4.3 (batch)',
      imageInput: true,
    ),
    'x-ai/grok-4.5': (name: 'SpaceXSI: Grok 4.5', imageInput: true),
    'x-ai/grok-4.6': (name: 'SpaceXSI: Grok 4.6', imageInput: true),
    'x-ai/grok-4.6:batch': (
      name: 'SpaceXSI: Grok 4.6 (batch)',
      imageInput: true,
    ),
    'x-ai/grok-4.7': (name: 'SpaceXSI: Grok 4.7', imageInput: true),
    'x-ai/grok-4.7:batch': (
      name: 'SpaceXSI: Grok 4.7 (batch)',
      imageInput: true,
    ),
    'xiaomi/mimo-v2.5': (name: 'Xiaomi: MiMo-V2.5', imageInput: true),
    'xiaomi/mimo-v2.5-pro': (name: 'Xiaomi: MiMo-V2.5-Pro', imageInput: false),
    'xiaomi/mimo-v2.6-flash': (
      name: 'Xiaomi: MiMo-V2.6-Flash',
      imageInput: true,
    ),
    'xiaomi/mimo-v2.6-pro': (name: 'Xiaomi: MiMo-V2.6-Pro', imageInput: true),
    'xiaomi/mimo-v2.6-pro-ultraspeed': (
      name: 'Xiaomi: MiMo-V2.6-Pro-UltraSpeed',
      imageInput: true,
    ),
    'z-ai/glm-4.5': (name: 'Z.ai: GLM 4.5', imageInput: false),
    'z-ai/glm-4.5-air': (name: 'Z.ai: GLM 4.5 Air', imageInput: false),
    'z-ai/glm-4.5v': (name: 'Z.ai: GLM 4.5V', imageInput: true),
    'z-ai/glm-4.6': (name: 'Z.ai: GLM 4.6', imageInput: false),
    'z-ai/glm-4.6v': (name: 'Z.ai: GLM 4.6V', imageInput: true),
    'z-ai/glm-4.7': (name: 'Z.ai: GLM 4.7', imageInput: false),
    'z-ai/glm-4.7-flash': (name: 'Z.ai: GLM 4.7 Flash', imageInput: false),
    'z-ai/glm-5': (name: 'Z.ai: GLM 5', imageInput: false),
    'z-ai/glm-5-turbo': (name: 'Z.ai: GLM 5 Turbo', imageInput: false),
    'z-ai/glm-5.1': (name: 'Z.ai: GLM 5.1', imageInput: false),
    'z-ai/glm-5.2': (name: 'Z.ai: GLM 5.2', imageInput: false),
    'z-ai/glm-5.2:batch': (name: 'Z.ai: GLM 5.2 (batch)', imageInput: false),
    'z-ai/glm-5.3': (name: 'Z.ai: GLM 5.3', imageInput: false),
    'z-ai/glm-5.3-flash': (name: 'Z.ai: GLM 5.3 Flash', imageInput: true),
    'z-ai/glm-5.3-flash:batch': (
      name: 'Z.ai: GLM 5.3 Flash (batch)',
      imageInput: true,
    ),
    'z-ai/glm-5.3-flashx': (name: 'Z.ai: GLM 5.3 FlashX', imageInput: true),
    'z-ai/glm-5.3-flashx-legal': (
      name: 'Z.ai: GLM 5.3 FlashX Legal',
      imageInput: true,
    ),
    'z-ai/glm-5.3-prime': (name: 'Z.ai: GLM 5.3 Prime', imageInput: false),
    'z-ai/glm-5.3:batch': (name: 'Z.ai: GLM 5.3 (batch)', imageInput: false),
    'z-ai/glm-5v-turbo': (name: 'Z.ai: GLM 5V Turbo', imageInput: true),
    '~anthropic/claude-fable-latest': (
      name: 'Anthropic: Claude Fable Latest',
      imageInput: true,
    ),
    '~anthropic/claude-haiku-latest': (
      name: 'Anthropic: Claude Haiku Latest',
      imageInput: true,
    ),
    '~anthropic/claude-opus-latest': (
      name: 'Anthropic: Claude Opus Latest',
      imageInput: true,
    ),
    '~anthropic/claude-sonnet-latest': (
      name: 'Anthropic: Claude Sonnet Latest',
      imageInput: true,
    ),
    '~deepseek/deepseek-flash-latest': (
      name: 'DeepSeek: DeepSeek Flash Latest',
      imageInput: true,
    ),
    '~deepseek/deepseek-pro-latest': (
      name: 'DeepSeek: DeepSeek Pro Latest',
      imageInput: false,
    ),
    '~deepseek/deepseek-v4-flash-latest': (
      name: 'DeepSeek: DeepSeek V4 Flash Latest',
      imageInput: false,
    ),
    '~google/gemini-flash-latest': (
      name: 'Google: Gemini Flash Latest',
      imageInput: true,
    ),
    '~google/gemini-pro-latest': (
      name: 'Google: Gemini Pro Latest',
      imageInput: true,
    ),
    '~moonshotai/kimi-latest': (
      name: 'MoonshotAI: Kimi Latest',
      imageInput: true,
    ),
    '~openai/gpt-astra-latest': (
      name: 'OpenAI: GPT Astra Latest',
      imageInput: true,
    ),
    '~openai/gpt-luna-latest': (
      name: 'OpenAI: GPT Luna Latest',
      imageInput: true,
    ),
    '~openai/gpt-mini-latest': (
      name: 'OpenAI: GPT Mini Latest',
      imageInput: true,
    ),
    '~openai/gpt-sol-latest': (
      name: 'OpenAI: GPT Sol Latest',
      imageInput: true,
    ),
    '~openai/gpt-terra-latest': (
      name: 'OpenAI: GPT Terra Latest',
      imageInput: true,
    ),
    '~unbiased/pareto-latest': (name: 'Pareto Latest', imageInput: true),
    '~x-ai/grok-latest': (name: 'xAI: Grok Latest', imageInput: true),
    '~z-ai/glm-flash-latest': (
      name: 'Z.ai: GLM Flash Latest',
      imageInput: true,
    ),
    '~z-ai/glm-latest': (name: 'Z.ai: GLM Latest', imageInput: false),
  },
  'xai': {
    'grok-4.3': (name: 'Grok 4.3', imageInput: true),
    'grok-4.5': (name: 'Grok 4.5', imageInput: true),
    'grok-4.6': (name: 'Grok 4.6', imageInput: true),
    'grok-4.7': (name: 'Grok 4.7', imageInput: true),
  },
  'mistral': {
    'codestral-2508': (name: 'Codestral 25.08', imageInput: false),
    'codestral-latest': (name: 'Codestral (latest)', imageInput: false),
    'deepseek-v4-1-flash-1017': (
      name: 'DeepSeek V4.1 Flash 1017',
      imageInput: true,
    ),
    'devstral-2512': (name: 'Devstral 2', imageInput: false),
    'devstral-latest': (name: 'Devstral 2', imageInput: false),
    'devstral-medium-latest': (name: 'Devstral 2 (latest)', imageInput: false),
    'glm-5-2': (name: 'GLM-5.2', imageInput: false),
    'labs-devstral-small-2512': (name: 'Devstral Small 2', imageInput: true),
    'labs-leanstral-1-5-1': (name: 'Leanstral 1.5', imageInput: true),
    'magistral-medium-latest': (
      name: 'Magistral Medium (latest)',
      imageInput: true,
    ),
    'ministral-14b-2512': (name: 'Ministral 3 14B', imageInput: true),
    'ministral-3b-2512': (name: 'Ministral 3 3B', imageInput: true),
    'ministral-3b-latest': (name: 'Ministral 3B (latest)', imageInput: true),
    'ministral-8b-2512': (name: 'Ministral 3 8B', imageInput: true),
    'ministral-8b-latest': (name: 'Ministral 8B (latest)', imageInput: true),
    'mistral-large-2512': (name: 'Mistral Large 3', imageInput: true),
    'mistral-large-4': (name: 'Mistral Large 4', imageInput: true),
    'mistral-large-4-0-8': (name: 'Mistral Large 4.0.8', imageInput: true),
    'mistral-large-latest': (name: 'Mistral Large (latest)', imageInput: true),
    'mistral-medium-2505': (name: 'Mistral Medium 3', imageInput: true),
    'mistral-medium-2508': (name: 'Mistral Medium 3.1', imageInput: true),
    'mistral-medium-2604': (name: 'Mistral Medium 3.5', imageInput: true),
    'mistral-medium-3.5': (name: 'Mistral Medium 3.5', imageInput: true),
    'mistral-medium-latest': (
      name: 'Mistral Medium (latest)',
      imageInput: true,
    ),
    'mistral-small-2506': (name: 'Mistral Small 3.2', imageInput: true),
    'mistral-small-2603': (name: 'Mistral Small 4', imageInput: true),
    'mistral-small-latest': (name: 'Mistral Small (latest)', imageInput: true),
    'open-mistral-nemo': (name: 'Open Mistral Nemo', imageInput: false),
    'pixtral-12b': (name: 'Pixtral 12B', imageInput: true),
    'voxtral-small-2507': (name: 'Voxtral Small', imageInput: false),
    'voxtral-small-latest': (name: 'Voxtral Small (latest)', imageInput: false),
    'zai-glm-5-2': (name: 'GLM-5.2', imageInput: false),
    'zai-glm-5-3': (name: 'GLM-5.3', imageInput: false),
    'zai-glm-5-3-flash': (name: 'GLM-5.3-Flash', imageInput: true),
  },
  'groq': {
    'llama-3.1-8b-instant': (name: 'Llama 3.1 8B', imageInput: false),
    'llama-3.3-70b-versatile': (name: 'Llama 3.3 70B', imageInput: false),
    'openai/gpt-oss-120b': (name: 'GPT OSS 120B', imageInput: false),
    'openai/gpt-oss-20b': (name: 'GPT OSS 20B', imageInput: false),
    'openai/gpt-oss-safeguard-20b': (
      name: 'Safety GPT OSS 20B',
      imageInput: false,
    ),
    'qwen/qwen3.6-27b': (name: 'Qwen3.6 27B', imageInput: true),
    'qwen/qwen3.8-27b': (name: 'Qwen3.8 27B', imageInput: true),
  },
  'cerebras': {
    'gpt-oss-120b': (name: 'GPT OSS 120B', imageInput: false),
    'qwen-3.8-27b': (name: 'Qwen3.8 27B', imageInput: true),
  },
  'minimax': {
    'MiniMax-M2.7': (name: 'MiniMax-M2.7', imageInput: false),
    'MiniMax-M2.7-highspeed': (
      name: 'MiniMax-M2.7-highspeed',
      imageInput: false,
    ),
    'MiniMax-M3': (name: 'MiniMax-M3', imageInput: true),
    'MiniMax-M3.1-Flash': (name: 'MiniMax-M3.1-Flash', imageInput: true),
  },
  'minimax-cn': {
    'MiniMax-M2.7': (name: 'MiniMax-M2.7', imageInput: false),
    'MiniMax-M2.7-highspeed': (
      name: 'MiniMax-M2.7-highspeed',
      imageInput: false,
    ),
    'MiniMax-M3': (name: 'MiniMax-M3', imageInput: true),
    'MiniMax-M3.1-Flash': (name: 'MiniMax-M3.1-Flash', imageInput: true),
  },
  'kimi-coding': {
    'k3': (name: 'Kimi K3', imageInput: true),
    'k3-256k': (name: 'Kimi K3-256K', imageInput: true),
    'k3.1-pro': (name: 'Kimi K3.1 Pro', imageInput: true),
    'k3.1-pro-highspeed': (name: 'Kimi K3.1 Pro Highspeed', imageInput: true),
    'kimi-for-coding': (name: 'kimi-for-coding', imageInput: true),
    'kimi-for-coding-highspeed': (
      name: 'Kimi For Coding HighSpeed',
      imageInput: true,
    ),
  },
  'moonshotai': {
    'kimi-k2.6': (name: 'Kimi K2.6', imageInput: true),
    'kimi-k2.7-code': (name: 'Kimi K2.7 Code', imageInput: true),
    'kimi-k2.7-code-highspeed': (
      name: 'Kimi K2.7 Code HighSpeed',
      imageInput: true,
    ),
    'kimi-k3': (name: 'Kimi K3', imageInput: true),
    'kimi-k3.1-pro': (name: 'Kimi K3.1 Pro', imageInput: true),
    'kimi-k3.1-pro-highspeed': (
      name: 'Kimi K3.1 Pro Highspeed',
      imageInput: true,
    ),
  },
  'moonshotai-cn': {
    'kimi-k2.6': (name: 'Kimi K2.6', imageInput: true),
    'kimi-k2.7-code': (name: 'Kimi K2.7 Code', imageInput: true),
    'kimi-k2.7-code-highspeed': (
      name: 'Kimi K2.7 Code HighSpeed',
      imageInput: true,
    ),
    'kimi-k3': (name: 'Kimi K3', imageInput: true),
    'kimi-k3.1-pro': (name: 'Kimi K3.1 Pro', imageInput: true),
    'kimi-k3.1-pro-highspeed': (
      name: 'Kimi K3.1 Pro Highspeed',
      imageInput: true,
    ),
  },
  'qwen-token-plan': {
    'MiniMax-M2.5': (name: 'MiniMax-M2.5', imageInput: false),
    'deepseek-v4-flash-0731': (
      name: 'DeepSeek V4 Flash 0731',
      imageInput: false,
    ),
    'deepseek-v4-pro': (name: 'DeepSeek V4 Pro', imageInput: false),
    'deepseek-v4-pro-0813': (name: 'DeepSeek V4 Pro 0813', imageInput: false),
    'deepseek-v4.1-flash': (name: 'DeepSeek V4.1 Flash', imageInput: true),
    'deepseek-v4.1-flash-1017': (
      name: 'DeepSeek V4.1 Flash 1017',
      imageInput: true,
    ),
    'glm-5': (name: 'GLM-5', imageInput: false),
    'glm-5.1': (name: 'GLM-5.1', imageInput: false),
    'glm-5.2': (name: 'GLM-5.2', imageInput: false),
    'glm-5.3': (name: 'GLM-5.3', imageInput: false),
    'kimi-k2.5': (name: 'Kimi K2.5', imageInput: true),
    'kimi-k2.6': (name: 'Kimi K2.6', imageInput: true),
    'kimi-k2.7-code': (name: 'Kimi K2.7 Code', imageInput: true),
    'qwen3.6-flash': (name: 'Qwen3.6 Flash', imageInput: true),
    'qwen3.6-plus': (name: 'Qwen3.6 Plus', imageInput: true),
    'qwen3.7-max': (name: 'Qwen3.7 Max', imageInput: false),
    'qwen3.7-plus': (name: 'Qwen3.7 Plus', imageInput: true),
    'qwen3.8-flash': (name: 'Qwen3.8 Flash', imageInput: true),
    'qwen3.8-max': (name: 'Qwen3.8 Max', imageInput: true),
    'qwen4-max-preview': (name: 'Qwen4 Max Preview', imageInput: true),
  },
  'qwen-token-plan-cn': {
    'MiniMax-M2.5': (name: 'MiniMax-M2.5', imageInput: false),
    'deepseek-v4-flash-0731': (
      name: 'DeepSeek V4 Flash 0731',
      imageInput: false,
    ),
    'deepseek-v4-pro': (name: 'DeepSeek V4 Pro', imageInput: false),
    'deepseek-v4-pro-0813': (name: 'DeepSeek V4 Pro 0813', imageInput: false),
    'deepseek-v4.1-flash': (name: 'DeepSeek V4.1 Flash', imageInput: true),
    'deepseek-v4.1-flash-1017': (
      name: 'DeepSeek V4.1 Flash 1017',
      imageInput: true,
    ),
    'glm-5': (name: 'GLM-5', imageInput: false),
    'glm-5.1': (name: 'GLM-5.1', imageInput: false),
    'glm-5.2': (name: 'GLM-5.2', imageInput: false),
    'glm-5.3': (name: 'GLM-5.3', imageInput: false),
    'kimi-k2.5': (name: 'Kimi K2.5', imageInput: true),
    'kimi-k2.6': (name: 'Kimi K2.6', imageInput: true),
    'kimi-k2.7-code': (name: 'Kimi K2.7 Code', imageInput: true),
    'qwen3.6-flash': (name: 'Qwen3.6 Flash', imageInput: true),
    'qwen3.6-plus': (name: 'Qwen3.6 Plus', imageInput: true),
    'qwen3.7-max': (name: 'Qwen3.7 Max', imageInput: false),
    'qwen3.7-plus': (name: 'Qwen3.7 Plus', imageInput: true),
    'qwen3.8-flash': (name: 'Qwen3.8 Flash', imageInput: true),
    'qwen3.8-max': (name: 'Qwen3.8 Max', imageInput: true),
    'qwen4-max-preview': (name: 'Qwen4 Max Preview', imageInput: true),
  },
  'qwen-token-plan-individual': {
    'deepseek-v4-flash-0731': (
      name: 'DeepSeek V4 Flash 0731',
      imageInput: false,
    ),
    'deepseek-v4-pro': (name: 'DeepSeek V4 Pro', imageInput: false),
    'deepseek-v4-pro-0813': (name: 'DeepSeek V4 Pro 0813', imageInput: false),
    'deepseek-v4.1-flash': (name: 'DeepSeek V4.1 Flash', imageInput: true),
    'deepseek-v4.1-flash-1017': (
      name: 'DeepSeek V4.1 Flash 1017',
      imageInput: true,
    ),
    'glm-5.2': (name: 'GLM-5.2', imageInput: false),
    'glm-5.3': (name: 'GLM-5.3', imageInput: false),
    'qwen3.6-flash': (name: 'Qwen3.6 Flash', imageInput: true),
    'qwen3.7-max': (name: 'Qwen3.7 Max', imageInput: false),
    'qwen3.7-plus': (name: 'Qwen3.7 Plus', imageInput: true),
    'qwen3.8-flash': (name: 'Qwen3.8 Flash', imageInput: true),
    'qwen3.8-max': (name: 'Qwen3.8 Max', imageInput: true),
    'qwen4-max-preview': (name: 'Qwen4 Max Preview', imageInput: true),
  },
  'qwen-token-plan-individual-cn': {
    'deepseek-v4-flash-0731': (
      name: 'DeepSeek V4 Flash 0731',
      imageInput: false,
    ),
    'deepseek-v4-pro': (name: 'DeepSeek V4 Pro', imageInput: false),
    'deepseek-v4-pro-0813': (name: 'DeepSeek V4 Pro 0813', imageInput: false),
    'deepseek-v4.1-flash': (name: 'DeepSeek V4.1 Flash', imageInput: true),
    'deepseek-v4.1-flash-1017': (
      name: 'DeepSeek V4.1 Flash 1017',
      imageInput: true,
    ),
    'glm-5.2': (name: 'GLM-5.2', imageInput: false),
    'glm-5.3': (name: 'GLM-5.3', imageInput: false),
    'qwen3.6-flash': (name: 'Qwen3.6 Flash', imageInput: true),
    'qwen3.7-max': (name: 'Qwen3.7 Max', imageInput: false),
    'qwen3.7-plus': (name: 'Qwen3.7 Plus', imageInput: true),
    'qwen3.8-flash': (name: 'Qwen3.8 Flash', imageInput: true),
    'qwen3.8-max': (name: 'Qwen3.8 Max', imageInput: true),
    'qwen4-max-preview': (name: 'Qwen4 Max Preview', imageInput: true),
  },
};
