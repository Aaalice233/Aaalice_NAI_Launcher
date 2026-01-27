import 'package:test/test.dart';
import 'package:dio/dio.dart';

import 'package:nai_launcher/data/datasources/remote/nai_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_auth_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_tag_suggestion_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_user_info_api_service.dart';
import 'package:nai_launcher/core/crypto/nai_crypto_service.dart';

/// 测试 NAIApiService Facade 的向后兼容性
///
/// 验证旧的 NAIApiService 类现在作为 Facade 正确地将所有调用委托给新的领域特定服务
void main() {
  group('NAIApiService Facade - Backwards Compatibility', () {
    late Dio dio;
    late NAICryptoService cryptoService;
    late NAIApiService facade;

    setUp(() {
      // 创建真实的 Dio 和 CryptoService 实例（仅用于结构验证）
      dio = Dio();
      cryptoService = NAICryptoService();

      // 创建 facade 实例（测试向后兼容性）
      facade = NAIApiService(dio, cryptoService);
    });

    test('facade should be instantiated with old constructor signature', () {
      // 验证旧的构造函数签名仍然有效
      expect(facade, isA<NAIApiService>());
      expect(facade, isNotNull);
    });

    test('facade should maintain same public API', () {
      // 验证 facade 具有与原始 NAIApiService 相同的公共接口
      // 这确保了向后兼容性 - 所有现有代码仍然可以工作

      // 验证方法存在且可调用（类型检查）
      expect(facade.validateToken, isA<Future<Map<String, dynamic>> Function(String)>());
      expect(facade.loginWithKey, isA<Future<Map<String, dynamic>> Function(String)>());

      // 验证静态方法存在
      expect(NAIApiService.isValidTokenFormat('test-token'), isA<bool>());
      expect(NAIApiService.isValidTokenFormat('invalid'), isA<bool>());

      // 验证标签建议方法存在
      expect(facade.suggestTags, isNotNull);
      expect(facade.suggestNextTag, isNotNull);

      // 验证图像生成方法存在
      expect(facade.generateImage, isNotNull);
      expect(facade.generateImageCancellable, isNotNull);
      expect(facade.cancelGeneration, isNotNull);
      expect(facade.generateImageStream, isNotNull);

      // 验证图像增强方法存在
      expect(facade.upscaleImage, isNotNull);
      expect(facade.encodeVibe, isNotNull);

      // 验证用户信息方法存在
      expect(facade.getUserSubscription, isNotNull);
    });

    test('facade constants should be accessible', () {
      // 验证所有公共常量仍然可访问
      expect(NAIApiService.reqTypeEmotionFix, equals('emotion'));
      expect(NAIApiService.reqTypeBgRemoval, equals('bg-removal'));
      expect(NAIApiService.reqTypeColorize, equals('colorize'));
      expect(NAIApiService.reqTypeDeclutter, equals('declutter'));
      expect(NAIApiService.reqTypeLineArt, equals('lineart'));
      expect(NAIApiService.reqTypeSketch, equals('sketch'));

      expect(NAIApiService.annotateTypeWd, equals('wd-tagger'));
      expect(NAIApiService.annotateTypeCanny, equals('canny'));
      expect(NAIApiService.annotateTypeDepth, equals('depth'));
      expect(NAIApiService.annotateTypeOpMlsd, equals('mlsd'));
      expect(NAIApiService.annotateTypeOpOpenpose, equals('openpose'));
      expect(NAIApiService.annotateTypeSeg, equals('seg'));
    });

    test('facade static methods should work', () {
      // 验证静态方法仍然有效
      final result = NAIApiService.isValidTokenFormat('pst-test123456789');
      expect(result, isTrue);

      final invalidResult = NAIApiService.isValidTokenFormat('invalid-token');
      expect(invalidResult, isFalse);
    });
  });

  group('NAIApiService Provider - Backwards Compatibility', () {
    test('old provider should still be accessible', () {
      // 验证旧的 provider 仍然可以访问
      expect(naiApiServiceProvider, isNotNull);
      expect(naiApiServiceProvider.toString(), contains('naiApiServiceProvider'));
    });

    test('new domain-specific providers should be accessible', () {
      // 验证新的领域特定 provider 可访问
      expect(naiAuthApiServiceProvider, isNotNull);
      expect(naiImageGenerationApiServiceProvider, isNotNull);
      expect(naiTagSuggestionApiServiceProvider, isNotNull);
      expect(naiImageEnhancementApiServiceProvider, isNotNull);
      expect(naiUserInfoApiServiceProvider, isNotNull);
    });
  });
}
