// tool/config/test_constants.dart
// Bug 测试文件的共享配置

/// BUG 测试文件列表（文件名集合）
const bugTestFiles = <String>{
  'vibe_encoding_test.dart',
  'sampler_test.dart',
  'seed_provider_test.dart',
  'auth_api_test.dart',
  'sidebar_state_test.dart',
  'query_parser_test.dart',
  'prompt_autofill_test.dart',
  'character_bar_test.dart',
};

/// BUG ID 映射表（文件名 -> BUG ID）
const bugIdMap = <String, String>{
  'vibe_encoding_test.dart': 'BUG-001',
  'sampler_test.dart': 'BUG-002',
  'seed_provider_test.dart': 'BUG-003',
  'auth_api_test.dart': 'BUG-004/005',
  'sidebar_state_test.dart': 'BUG-006',
  'query_parser_test.dart': 'BUG-007',
  'prompt_autofill_test.dart': 'BUG-008',
  'character_bar_test.dart': 'BUG-009',
};

/// 测试通过率阈值（百分比）
const passRateThreshold = 90.0;

/// 测试超时配置
const testTimeoutSeconds = 120;
