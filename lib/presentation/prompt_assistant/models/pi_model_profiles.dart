// GENERATED from @earendil-works/pi-ai 1.0.0.
// Source: dist/providers/data/*.json. Do not edit by hand.

typedef PiModelProfile = ({String? name, bool imageInput});

const piModelProfiles = <String, Map<String, PiModelProfile>>{
  'openai': {
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
    'gpt-5.2-chat-latest': (name: 'GPT-5.2 Chat', imageInput: true),
    'gpt-5.2-pro': (name: 'GPT-5.2 Pro', imageInput: true),
    'gpt-5.3-chat-latest': (name: 'GPT-5.3 Chat (latest)', imageInput: true),
    'gpt-5.3-codex': (name: 'GPT-5.3 Codex', imageInput: true),
    'gpt-5.3-codex-spark': (name: 'GPT-5.3 Codex Spark', imageInput: true),
    'gpt-5.4': (name: 'GPT-5.4', imageInput: true),
    'gpt-5.4-mini': (name: 'GPT-5.4 mini', imageInput: true),
    'gpt-5.4-nano': (name: 'GPT-5.4 nano', imageInput: true),
    'gpt-5.4-pro': (name: 'GPT-5.4 Pro', imageInput: true),
    'gpt-5.5': (name: 'GPT-5.5', imageInput: true),
    'gpt-5.5-pro': (name: 'GPT-5.5 Pro', imageInput: true),
    'gpt-5.6-luna': (name: 'GPT-5.6 Luna', imageInput: true),
    'gpt-5.6-sol': (name: 'GPT-5.6 Sol', imageInput: true),
    'gpt-5.6-terra': (name: 'GPT-5.6 Terra', imageInput: true),
    'gpt-6-astra': (name: 'GPT-6 Astra', imageInput: true),
    'gpt-6-luna': (name: 'GPT-6 Luna', imageInput: true),
    'gpt-6-sol': (name: 'GPT-6 Sol', imageInput: true),
    'gpt-6.1-sol': (name: 'GPT-6.1 Sol', imageInput: true),
    'gpt-daybreak-blue-latest': (name: 'Daybreak Blue', imageInput: true),
    'gpt-daybreak-red-latest': (name: 'Daybreak Red', imageInput: true),
    'gpt-realtime-2.1': (name: 'GPT-Realtime-2.1', imageInput: true),
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
    'claude-haiku-4-5': (name: 'Claude Haiku 4.5 (latest)', imageInput: true),
    'claude-haiku-4-5-20251001': (name: 'Claude Haiku 4.5', imageInput: true),
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
    'gemini-3.1-flash-lite-image': (
      name: 'Nano Banana 2 Lite',
      imageInput: true,
    ),
    'gemini-3.1-flash-lite-preview': (
      name: 'Gemini 3.1 Flash Lite Preview',
      imageInput: true,
    ),
    'gemini-3.1-flash-live-preview': (
      name: 'Gemini 3.1 Flash Live Preview',
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
    'gemini-flash-latest': (name: 'Gemini Flash Latest', imageInput: true),
    'gemini-flash-lite-latest': (
      name: 'Gemini Flash-Lite Latest',
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
    'anthropic/claude-sonnet-4': (
      name: 'Anthropic: Claude Sonnet 4',
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
    'apodex/apodex-1.1-mini:free': (
      name: 'Apodex: Apodex 1.1 Mini (free)',
      imageInput: false,
    ),
    'arcee-ai/trinity-large-thinking': (
      name: 'Arcee AI: Trinity Large Thinking',
      imageInput: false,
    ),
    'auto': (name: 'Auto', imageInput: true),
    'bytedance-seed/seed-1.6': (
      name: 'ByteDance Seed: Seed 1.6',
      imageInput: true,
    ),
    'bytedance-seed/seed-1.6-flash': (
      name: 'ByteDance Seed: Seed 1.6 Flash',
      imageInput: true,
    ),
    'bytedance-seed/seed-2-1-turbo': (
      name: 'ByteDance Seed: Seed 2.1 Turbo',
      imageInput: true,
    ),
    'bytedance-seed/seed-2.0-code': (
      name: 'ByteDance Seed: Seed-2.0-Code',
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
    'cohere/command-a-plus': (name: 'Cohere: Command A+', imageInput: true),
    'cohere/command-r-08-2024': (
      name: 'Cohere: Command R (08-2024)',
      imageInput: false,
    ),
    'cohere/command-r-plus-08-2024': (
      name: 'Cohere: Command R+ (08-2024)',
      imageInput: false,
    ),
    'cohere/north-mini-code:free': (
      name: 'Cohere: North Mini Code (free)',
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
    'deepseek/deepseek-r1': (name: 'DeepSeek: R1', imageInput: false),
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
    'deepseek/deepseek-v4.1-flash:batch': (
      name: 'DeepSeek: DeepSeek V4.1 Flash (batch)',
      imageInput: true,
    ),
    'dots-studio/dots-3-note-preview:free': (
      name: 'Dots Studio: Dots3-Note Preview (free)',
      imageInput: true,
    ),
    'fireworks/ember-1': (name: 'Fireworks: Ember-1', imageInput: true),
    'google/gemini-2.5-flash': (
      name: 'Google: Gemini 2.5 Flash',
      imageInput: true,
    ),
    'google/gemini-2.5-flash-lite': (
      name: 'Google: Gemini 2.5 Flash Lite',
      imageInput: true,
    ),
    'google/gemini-2.5-flash-lite:batch': (
      name: 'Google: Gemini 2.5 Flash Lite (batch)',
      imageInput: true,
    ),
    'google/gemini-2.5-flash:batch': (
      name: 'Google: Gemini 2.5 Flash (batch)',
      imageInput: true,
    ),
    'google/gemini-2.5-pro': (name: 'Google: Gemini 2.5 Pro', imageInput: true),
    'google/gemini-2.5-pro-preview': (
      name: 'Google: Gemini 2.5 Pro Preview 06-05',
      imageInput: true,
    ),
    'google/gemini-2.5-pro:batch': (
      name: 'Google: Gemini 2.5 Pro (batch)',
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
    'inception/mercury-2': (name: 'Inception: Mercury 2', imageInput: false),
    'inception/mercury-2.5': (
      name: 'Inception: Mercury 2.5',
      imageInput: false,
    ),
    'inclusionai/ling-3.0-flash': (
      name: 'inclusionAI: Ling 3.0 Flash',
      imageInput: false,
    ),
    'inclusionai/ling-3.0-flash-fin': (
      name: 'inclusionAI: Ling 3.0 Flash Fin',
      imageInput: false,
    ),
    'inclusionai/ling-3.0-flash-sante:free': (
      name: 'inclusionAI: Ling 3.0 Flash Sante (free)',
      imageInput: false,
    ),
    'inclusionai/ling-3.0-flash-vl': (
      name: 'inclusionAI: Ling 3.0 Flash VL',
      imageInput: true,
    ),
    'kwaipilot/kat-coder-pro-v2.5': (
      name: 'Kwaipilot: KAT-Coder-Pro V2.5',
      imageInput: false,
    ),
    'liquid/lfm-2.5-2.6b:free': (
      name: 'LiquidAI: LFM2.5-2.6B (free)',
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
    'meta/muse-glimmer-30b': (name: 'Meta: Muse Glimmer 30B', imageInput: true),
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
    'minimax/minimax-m1': (name: 'MiniMax: MiniMax M1', imageInput: false),
    'minimax/minimax-m2': (name: 'MiniMax: MiniMax M2', imageInput: false),
    'minimax/minimax-m2.1': (name: 'MiniMax: MiniMax M2.1', imageInput: false),
    'minimax/minimax-m2.5': (name: 'MiniMax: MiniMax M2.5', imageInput: false),
    'minimax/minimax-m2.7': (name: 'MiniMax: MiniMax M2.7', imageInput: false),
    'minimax/minimax-m3': (name: 'MiniMax: MiniMax M3', imageInput: true),
    'mistralai/codestral-2508': (
      name: 'Mistral: Codestral 2508',
      imageInput: false,
    ),
    'mistralai/codestral-2508:batch': (
      name: 'Mistral: Codestral 2508 (batch)',
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
    'mistralai/ministral-8b-2512:batch': (
      name: 'Mistral: Ministral 3 8B 2512 (batch)',
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
    'mistralai/mistral-large-2512:batch': (
      name: 'Mistral: Mistral Large 3 2512 (batch)',
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
    'mistralai/mistral-medium-3.1:batch': (
      name: 'Mistral: Mistral Medium 3.1 (batch)',
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
    'mistralai/mistral-small-2603:batch': (
      name: 'Mistral: Mistral Small 4 (batch)',
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
    'moonshotai/kimi-k3:batch': (
      name: 'MoonshotAI: Kimi K3 (batch)',
      imageInput: true,
    ),
    'nex-agi/nex-n2.5-pro': (name: 'Nex AGI: Nex-N2.5-Pro', imageInput: true),
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
    'nvidia/nemotron-3-super-120b-a12b:free': (
      name: 'NVIDIA: Nemotron 3 Super (free)',
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
    'openai/gpt-3.5-turbo': (name: 'OpenAI: GPT-3.5 Turbo', imageInput: false),
    'openai/gpt-3.5-turbo-0613': (
      name: 'OpenAI: GPT-3.5 Turbo (older v0613)',
      imageInput: false,
    ),
    'openai/gpt-3.5-turbo-16k': (
      name: 'OpenAI: GPT-3.5 Turbo 16k',
      imageInput: false,
    ),
    'openai/gpt-3.5-turbo:batch': (
      name: 'OpenAI: GPT-3.5 Turbo (batch)',
      imageInput: false,
    ),
    'openai/gpt-4': (name: 'OpenAI: GPT-4', imageInput: false),
    'openai/gpt-4-turbo': (name: 'OpenAI: GPT-4 Turbo', imageInput: true),
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
    'openai/o1': (name: 'OpenAI: o1', imageInput: true),
    'openai/o3': (name: 'OpenAI: o3', imageInput: true),
    'openai/o3-mini': (name: 'OpenAI: o3 Mini', imageInput: false),
    'openai/o3-mini-high': (name: 'OpenAI: o3 Mini High', imageInput: false),
    'openai/o3-mini:batch': (
      name: 'OpenAI: o3 Mini (batch)',
      imageInput: false,
    ),
    'openai/o3-pro': (name: 'OpenAI: o3 Pro', imageInput: true),
    'openai/o3:batch': (name: 'OpenAI: o3 (batch)', imageInput: true),
    'openai/o4-mini': (name: 'OpenAI: o4 Mini', imageInput: true),
    'openai/o4-mini-high': (name: 'OpenAI: o4 Mini High', imageInput: true),
    'openai/o4-mini:batch': (name: 'OpenAI: o4 Mini (batch)', imageInput: true),
    'openrouter/auto': (name: 'Auto Router', imageInput: true),
    'openrouter/auto-beta': (name: 'Auto Router (Beta)', imageInput: true),
    'openrouter/free': (name: 'Free Models Router', imageInput: true),
    'openrouter/fusion': (name: 'OpenRouter: Fusion', imageInput: false),
    'perceptron/perceptron-mk1.5': (
      name: 'Perceptron: Perceptron Mk1.5',
      imageInput: true,
    ),
    'poolside/laguna-s-2.1': (
      name: 'Poolside: Laguna S 2.1',
      imageInput: false,
    ),
    'poolside/laguna-s-2.1:free': (
      name: 'Poolside: Laguna S 2.1 (free)',
      imageInput: false,
    ),
    'poolside/laguna-xs-2.1': (
      name: 'Poolside: Laguna XS 2.1',
      imageInput: false,
    ),
    'poolside/laguna-xs-2.1:free': (
      name: 'Poolside: Laguna XS 2.1 (free)',
      imageInput: false,
    ),
    'prism-ml/ternary-bonsai-2-27b': (
      name: 'PrismML: Ternary Bonsai 2 27B',
      imageInput: true,
    ),
    'qwen/qwen-2.5-72b-instruct': (
      name: 'Qwen2.5 72B Instruct',
      imageInput: false,
    ),
    'qwen/qwen-2.5-7b-instruct': (
      name: 'Qwen: Qwen2.5 7B Instruct',
      imageInput: false,
    ),
    'qwen/qwen-plus': (name: 'Qwen: Qwen-Plus', imageInput: false),
    'qwen/qwen-plus-2025-07-28': (
      name: 'Qwen: Qwen Plus 0728',
      imageInput: false,
    ),
    'qwen/qwen3-14b': (name: 'Qwen: Qwen3 14B', imageInput: false),
    'qwen/qwen3-235b-a22b': (name: 'Qwen: Qwen3 235B A22B', imageInput: false),
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
    'qwen/qwen3-30b-a3b-thinking-2507': (
      name: 'Qwen: Qwen3 30B A3B Thinking 2507',
      imageInput: false,
    ),
    'qwen/qwen3-32b': (name: 'Qwen: Qwen3 32B', imageInput: false),
    'qwen/qwen3-8b': (name: 'Qwen: Qwen3 8B', imageInput: false),
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
    'qwen/qwen3-coder-plus': (
      name: 'Qwen: Qwen3 Coder Plus',
      imageInput: false,
    ),
    'qwen/qwen3-max': (name: 'Qwen: Qwen3 Max', imageInput: false),
    'qwen/qwen3-max-thinking': (
      name: 'Qwen: Qwen3 Max Thinking',
      imageInput: false,
    ),
    'qwen/qwen3-next-80b-a3b-instruct': (
      name: 'Qwen: Qwen3 Next 80B A3B Instruct',
      imageInput: false,
    ),
    'qwen/qwen3-next-80b-a3b-thinking': (
      name: 'Qwen: Qwen3 Next 80B A3B Thinking',
      imageInput: false,
    ),
    'qwen/qwen3-vl-235b-a22b-instruct': (
      name: 'Qwen: Qwen3 VL 235B A22B Instruct',
      imageInput: true,
    ),
    'qwen/qwen3-vl-235b-a22b-thinking': (
      name: 'Qwen: Qwen3 VL 235B A22B Thinking',
      imageInput: true,
    ),
    'qwen/qwen3-vl-30b-a3b-instruct': (
      name: 'Qwen: Qwen3 VL 30B A3B Instruct',
      imageInput: true,
    ),
    'qwen/qwen3-vl-30b-a3b-thinking': (
      name: 'Qwen: Qwen3 VL 30B A3B Thinking',
      imageInput: true,
    ),
    'qwen/qwen3-vl-32b-instruct': (
      name: 'Qwen: Qwen3 VL 32B Instruct',
      imageInput: true,
    ),
    'qwen/qwen3-vl-8b-instruct': (
      name: 'Qwen: Qwen3 VL 8B Instruct',
      imageInput: true,
    ),
    'qwen/qwen3-vl-8b-thinking': (
      name: 'Qwen: Qwen3 VL 8B Thinking',
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
    'qwen/qwen3.6-max-preview': (
      name: 'Qwen: Qwen3.6 Max Preview',
      imageInput: false,
    ),
    'qwen/qwen3.6-plus': (name: 'Qwen: Qwen3.6 Plus', imageInput: true),
    'qwen/qwen3.7-flash': (name: 'Qwen: Qwen3.7 Flash', imageInput: true),
    'qwen/qwen3.7-max': (name: 'Qwen: Qwen3.7 Max', imageInput: false),
    'qwen/qwen3.7-plus': (name: 'Qwen: Qwen3.7 Plus', imageInput: true),
    'qwen/qwen3.8-2.4t-a95b': (
      name: 'Qwen: Qwen3.8 2.4T A95B',
      imageInput: false,
    ),
    'qwen/qwen3.8-27b': (name: 'Qwen: Qwen3.8 27B', imageInput: true),
    'qwen/qwen3.8-27b:free': (
      name: 'Qwen: Qwen3.8 27B (free)',
      imageInput: true,
    ),
    'qwen/qwen3.8-flash': (name: 'Qwen: Qwen3.8 Flash', imageInput: true),
    'qwen/qwen3.8-max-0902': (
      name: 'Qwen: Qwen3.8 Max (0902)',
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
    'rekaai/reka-edge': (name: 'Reka Edge', imageInput: true),
    'relace/relace-search': (name: 'Relace: Relace Search', imageInput: false),
    'sakana/fugu-max': (name: 'Sakana: Fugu Max', imageInput: true),
    'sakana/fugu-ultra': (name: 'Sakana: Fugu Ultra', imageInput: true),
    'sakana/fugu-ultra-v2': (name: 'Sakana: Fugu Ultra v2', imageInput: true),
    'sakana/sakana-namazu': (name: 'Sakana: Sakana Namazu', imageInput: true),
    'sao10k/l3.1-euryale-70b': (
      name: 'Sao10K: Llama 3.1 Euryale 70B v2.2',
      imageInput: false,
    ),
    'stealth/space-bunny-alpha': (name: 'Space Bunny Alpha', imageInput: true),
    'stepfun/step-3.5-flash': (
      name: 'StepFun: Step 3.5 Flash',
      imageInput: false,
    ),
    'stepfun/step-3.7-flash': (
      name: 'StepFun: Step 3.7 Flash',
      imageInput: true,
    ),
    'tencent/hy3': (name: 'Tencent: Hy3', imageInput: false),
    'tencent/hy3-preview': (name: 'Tencent: Hy3 preview', imageInput: false),
    'tencent/hy4-preview': (name: 'Tencent: Hy4 preview', imageInput: false),
    'thinkingmachines/inkling': (
      name: 'Thinking Machines: Inkling',
      imageInput: true,
    ),
    'thinkingmachines/inkling-small': (
      name: 'Thinking Machines: Inkling Small',
      imageInput: true,
    ),
    'thinkingmachines/inkling-small:free': (
      name: 'Thinking Machines: Inkling Small (free)',
      imageInput: true,
    ),
    'thinkingmachines/inkling:free': (
      name: 'Thinking Machines: Inkling (free)',
      imageInput: true,
    ),
    'typesafe/jev-router': (name: 'TypeSafe: Jev Router', imageInput: true),
    'unbiased/pareto': (name: 'Pareto', imageInput: true),
    'unbiased/pareto-26.10-preview': (
      name: 'Pareto 26.10 Preview',
      imageInput: true,
    ),
    'upstage/solar-mini4': (name: 'Upstage: Solar Mini 4', imageInput: false),
    'upstage/solar-pro-3': (name: 'Upstage: Solar Pro 3', imageInput: false),
    'upstage/solar-pro4': (name: 'Upstage: Solar Pro 4', imageInput: false),
    'x-ai/grok-4.20': (name: 'SpaceXAI: Grok 4.20', imageInput: true),
    'x-ai/grok-4.3': (name: 'SpaceXAI: Grok 4.3', imageInput: true),
    'x-ai/grok-4.3:batch': (
      name: 'SpaceXAI: Grok 4.3 (batch)',
      imageInput: true,
    ),
    'x-ai/grok-4.5': (name: 'SpaceXAI: Grok 4.5', imageInput: true),
    'x-ai/grok-4.6': (name: 'SpaceXAI: Grok 4.6', imageInput: true),
    'x-ai/grok-4.7': (name: 'SpaceXAI: Grok 4.7', imageInput: true),
    'x-ai/grok-build-0.1': (name: 'SpaceXAI: Grok Build 0.1', imageInput: true),
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
    'z-ai/glm-5.3': (name: 'Z.ai: GLM 5.3', imageInput: false),
    'z-ai/glm-5.3-flash': (name: 'Z.ai: GLM 5.3 Flash', imageInput: true),
    'z-ai/glm-5.3-flash:batch': (
      name: 'Z.ai: GLM 5.3 Flash (batch)',
      imageInput: true,
    ),
    'z-ai/glm-5.3-flashx': (name: 'Z.ai: GLM 5.3 FlashX', imageInput: true),
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
    'codestral-latest': (name: 'Codestral (latest)', imageInput: false),
    'devstral-2512': (name: 'Devstral 2', imageInput: false),
    'devstral-latest': (name: 'Devstral 2', imageInput: false),
    'devstral-medium-2507': (name: 'Devstral Medium', imageInput: false),
    'devstral-medium-latest': (name: 'Devstral 2 (latest)', imageInput: false),
    'devstral-small-2505': (name: 'Devstral Small 2505', imageInput: false),
    'devstral-small-2507': (name: 'Devstral Small', imageInput: false),
    'labs-devstral-small-2512': (name: 'Devstral Small 2', imageInput: true),
    'magistral-medium-latest': (
      name: 'Magistral Medium (latest)',
      imageInput: false,
    ),
    'ministral-3b-latest': (name: 'Ministral 3B (latest)', imageInput: false),
    'ministral-8b-latest': (name: 'Ministral 8B (latest)', imageInput: false),
    'mistral-large-2411': (name: 'Mistral Large 2.1', imageInput: false),
    'mistral-large-2512': (name: 'Mistral Large 3', imageInput: true),
    'mistral-large-latest': (name: 'Mistral Large (latest)', imageInput: true),
    'mistral-medium-2505': (name: 'Mistral Medium 3', imageInput: true),
    'mistral-medium-2508': (name: 'Mistral Medium 3.1', imageInput: true),
    'mistral-medium-2604': (name: 'Mistral Medium 3.5', imageInput: true),
    'mistral-medium-3.5': (name: 'Mistral Medium 3.5', imageInput: true),
    'mistral-medium-latest': (
      name: 'Mistral Medium (latest)',
      imageInput: true,
    ),
    'mistral-nemo': (name: 'Mistral Nemo', imageInput: false),
    'mistral-small-2506': (name: 'Mistral Small 3.2', imageInput: true),
    'mistral-small-2603': (name: 'Mistral Small 4', imageInput: true),
    'mistral-small-latest': (name: 'Mistral Small (latest)', imageInput: true),
    'open-mistral-7b': (name: 'Mistral 7B', imageInput: false),
    'open-mistral-nemo': (name: 'Open Mistral Nemo', imageInput: false),
    'open-mixtral-8x22b': (name: 'Mixtral 8x22B', imageInput: false),
    'open-mixtral-8x7b': (name: 'Mixtral 8x7B', imageInput: false),
    'pixtral-12b': (name: 'Pixtral 12B', imageInput: true),
    'pixtral-large-latest': (name: 'Pixtral Large (latest)', imageInput: true),
    'voxtral-small-latest': (name: 'Voxtral Small (latest)', imageInput: false),
    'zai-glm-5-2': (name: 'GLM-5.2', imageInput: false),
    'zai-glm-5-3': (name: 'GLM-5.3', imageInput: false),
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
  },
  'minimax-cn': {
    'MiniMax-M2.7': (name: 'MiniMax-M2.7', imageInput: false),
    'MiniMax-M2.7-highspeed': (
      name: 'MiniMax-M2.7-highspeed',
      imageInput: false,
    ),
    'MiniMax-M3': (name: 'MiniMax-M3', imageInput: true),
  },
  'kimi-coding': {
    'k3': (name: 'Kimi K3', imageInput: true),
    'k3-256k': (name: 'Kimi K3-256K', imageInput: true),
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
  },
  'moonshotai-cn': {
    'kimi-k2.6': (name: 'Kimi K2.6', imageInput: true),
    'kimi-k2.7-code': (name: 'Kimi K2.7 Code', imageInput: true),
    'kimi-k2.7-code-highspeed': (
      name: 'Kimi K2.7 Code HighSpeed',
      imageInput: true,
    ),
    'kimi-k3': (name: 'Kimi K3', imageInput: true),
  },
  'qwen-token-plan': {
    'MiniMax-M2.5': (name: 'MiniMax-M2.5', imageInput: false),
    'deepseek-v3.2': (name: 'DeepSeek V3.2', imageInput: false),
    'deepseek-v4-flash': (name: 'DeepSeek V4 Flash', imageInput: false),
    'deepseek-v4-flash-0731': (
      name: 'DeepSeek V4 Flash 0731',
      imageInput: false,
    ),
    'deepseek-v4-pro': (name: 'DeepSeek V4 Pro', imageInput: false),
    'deepseek-v4-pro-0813': (name: 'DeepSeek V4 Pro 0813', imageInput: false),
    'deepseek-v4.1-flash': (name: 'DeepSeek V4.1 Flash', imageInput: true),
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
  },
  'qwen-token-plan-cn': {
    'MiniMax-M2.5': (name: 'MiniMax-M2.5', imageInput: false),
    'deepseek-v3.2': (name: 'DeepSeek V3.2', imageInput: false),
    'deepseek-v4-flash': (name: 'DeepSeek V4 Flash', imageInput: false),
    'deepseek-v4-flash-0731': (
      name: 'DeepSeek V4 Flash 0731',
      imageInput: false,
    ),
    'deepseek-v4-pro': (name: 'DeepSeek V4 Pro', imageInput: false),
    'deepseek-v4-pro-0813': (name: 'DeepSeek V4 Pro 0813', imageInput: false),
    'deepseek-v4.1-flash': (name: 'DeepSeek V4.1 Flash', imageInput: true),
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
  },
  'qwen-token-plan-individual': {
    'deepseek-v4-flash-0731': (
      name: 'DeepSeek V4 Flash 0731',
      imageInput: false,
    ),
    'deepseek-v4-pro': (name: 'DeepSeek V4 Pro', imageInput: false),
    'deepseek-v4-pro-0813': (name: 'DeepSeek V4 Pro 0813', imageInput: false),
    'glm-5.2': (name: 'GLM-5.2', imageInput: false),
    'qwen3.6-flash': (name: 'Qwen3.6 Flash', imageInput: true),
    'qwen3.7-max': (name: 'Qwen3.7 Max', imageInput: false),
    'qwen3.7-plus': (name: 'Qwen3.7 Plus', imageInput: true),
    'qwen3.8-flash': (name: 'Qwen3.8 Flash', imageInput: true),
    'qwen3.8-max': (name: 'Qwen3.8 Max', imageInput: true),
  },
};
