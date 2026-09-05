import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_api_client.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/prompt_assistant_adapter.dart';

class _Dio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  test('旧配置使用五分钟，超时选项在保存和重载后保持一致', () {
    expect(PromptAssistantConfigState.decode('{}').responseTimeoutSeconds, 300);
    for (final seconds in PromptAssistantConfigState.responseTimeoutChoices) {
      final config = PromptAssistantConfigState.defaults().copyWith(
        responseTimeoutSeconds: seconds,
      );
      expect(
        PromptAssistantConfigState.decode(
          config.encode(),
        ).responseTimeoutSeconds,
        seconds,
      );
    }
    for (final invalid in [0, -1, '600', 600.0, null]) {
      expect(
        PromptAssistantConfigState.decode(
          jsonEncode({'responseTimeoutSeconds': invalid}),
        ).responseTimeoutSeconds,
        300,
      );
    }
  });

  for (final protocol in ProviderProtocol.values) {
    test('$protocol 使用请求配置而非适配器固定超时', () async {
      final dio = _Dio();
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((call) async {
        final options = call.namedArguments[#options] as Options;
        expect(options.receiveTimeout, const Duration(minutes: 15));
        expect(options.sendTimeout, const Duration(seconds: 30));
        return _response();
      });
      final chunks = await PromptAssistantApiClient(
        dio: dio,
      ).complete(request: _request(protocol)).toList();
      expect(chunks.first.delta, 'ok');
    });
  }

  for (final deepseek in [false, true]) {
    test('兼容重试保留超时设置，DeepSeek=$deepseek', () async {
      final dio = _Dio();
      var calls = 0;
      when(
        () => dio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((call) async {
        expect(
          (call.namedArguments[#options] as Options).receiveTimeout,
          const Duration(minutes: 15),
        );
        if (calls++ == 0) {
          final options = RequestOptions(path: '/v1/chat/completions');
          throw DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 400,
            ),
            type: DioExceptionType.badResponse,
          );
        }
        return _response();
      });
      await PromptAssistantApiClient(dio: dio)
          .complete(
            request: _request(
              ProviderProtocol.openaiChatCompletions,
              deepseek: deepseek,
            ),
          )
          .toList();
      expect(calls, 2);
    });
  }

  test('延长等待后手动取消仍立即传给进行中的请求', () async {
    final dio = _Dio();
    final started = Completer<void>();
    when(
      () => dio.post<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((call) async {
      final token = call.namedArguments[#cancelToken] as CancelToken;
      started.complete();
      throw await token.whenCancel;
    });
    final client = PromptAssistantApiClient(dio: dio);
    final pending = expectLater(
      client
          .complete(request: _request(ProviderProtocol.openaiChatCompletions))
          .toList(),
      throwsStateError,
    );
    await started.future;
    client.cancelCurrentRequest(sessionId: 'timeout-test');
    await pending;
  });

  test('接收超时错误保留等待时长和调整入口', () async {
    final dio = _Dio();
    when(
      () => dio.post<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/v1/chat/completions'),
        type: DioExceptionType.receiveTimeout,
      ),
    );
    await expectLater(
      PromptAssistantApiClient(dio: dio)
          .complete(request: _request(ProviderProtocol.openaiChatCompletions))
          .toList(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('timeout=900s'),
        ),
      ),
    );
  });
}

PromptAssistantRequest _request(
  ProviderProtocol protocol, {
  bool deepseek = false,
}) => PromptAssistantRequest(
  sessionId: 'timeout-test',
  provider: ProviderConfig(
    id: 'test',
    name: 'Test',
    protocol: protocol,
    baseUrl: 'https://example.test/v1',
    preset: deepseek ? ProviderPreset.deepseek : null,
  ),
  model: 'test',
  systemPrompt: 'test',
  userParts: [PromptAssistantContentPart.text('test')],
  apiKey: null,
  responseTimeout: const Duration(minutes: 15),
);

Response<dynamic> _response() => Response<dynamic>(
  requestOptions: RequestOptions(path: '/'),
  statusCode: 200,
  data: {
    'choices': [
      {
        'message': {'content': 'ok'},
      },
    ],
    'output_text': 'ok',
    'content': [
      {'type': 'text', 'text': 'ok'},
    ],
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': 'ok'},
          ],
        },
      },
    ],
  },
);
