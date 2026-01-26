import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_api_service.dart';
import 'package:nai_launcher/core/crypto/nai_crypto_service.dart';
import 'package:nai_launcher/data/models/danbooru/danbooru_user.dart';

// Mock classes
class MockDio extends Mock implements Dio {}

class MockNAICryptoService extends Mock implements NAICryptoService {}

void main() {
  group('Danbooru Authentication API', () {
    late MockDio mockDio;
    late DanbooruApiService apiService;

    setUp(() {
      mockDio = MockDio();
      apiService = DanbooruApiService(mockDio);
    });

    group('verifyCredentials', () {
      test('should return user data when credentials are valid', () async {
        // Arrange
        final credentials = DanbooruCredentials(
          username: 'test_user',
          apiKey: 'test_api_key',
        );

        final mockResponse = Response(
          data: {
            'id': 12345,
            'name': 'test_user',
            'level': 20,
            'level_string': 'Member',
            'post_upload_count': 100,
            'post_update_count': 50,
            'note_update_count': 10,
            'is_banned': false,
            'can_approve_posts': false,
            'can_upload_free': false,
            'is_super_voter': false,
            'favorite_count': 200,
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(() => mockDio.get(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.verifyCredentials(credentials);

        // Assert
        expect(result, isNotNull,
            reason: 'Should return user data for valid credentials');
        expect(result!.name, equals('test_user'),
            reason: 'Username should match the authenticated user');
        expect(result.id, equals(12345),
            reason: 'User ID should be returned from API');
        expect(result.level, equals(20),
            reason: 'User level should match API response');
        expect(result.isBanned, isFalse,
            reason: 'User should not be banned');
      });

      test('should return null when credentials are invalid (401)', () async {
        // Arrange
        final credentials = DanbooruCredentials(
          username: 'invalid_user',
          apiKey: 'invalid_key',
        );

        final error = DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(path: ''),
          ),
          type: DioExceptionType.badResponse,
        );

        when(() => mockDio.get(
          any(),
          options: any(named: 'options'),
        )).thenThrow(error);

        // Act
        final result = await apiService.verifyCredentials(credentials);

        // Assert
        expect(result, isNull,
            reason: 'Should return null for invalid credentials');
      });

      test('should return null when API request times out', () async {
        // Arrange
        final credentials = DanbooruCredentials(
          username: 'test_user',
          apiKey: 'test_api_key',
        );

        final error = DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        );

        when(() => mockDio.get(
          any(),
          options: any(named: 'options'),
        )).thenThrow(error);

        // Act
        final result = await apiService.verifyCredentials(credentials);

        // Assert
        expect(result, isNull,
            reason: 'Should return null on timeout');
      });

      test('should include correct authorization header', () async {
        // Arrange
        final credentials = DanbooruCredentials(
          username: 'test_user',
          apiKey: 'test_api_key',
        );

        final mockResponse = Response(
          data: {
            'id': 12345,
            'name': 'test_user',
            'level': 20,
            'level_string': 'Member',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(() => mockDio.get(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        await apiService.verifyCredentials(credentials);

        // Assert
        final captured = verify(() => mockDio.get(
          any(),
          options: captureAny(named: 'options'),
        )).captured;

        final options = captured.first as Options;
        final authHeader = options.headers?['Authorization'];
        expect(authHeader, isNotNull,
            reason: 'Authorization header should be included');
        expect(
            (authHeader as String).startsWith('Basic '),
            isTrue,
            reason: 'Should use Basic authentication');
      });
    });

    group('Danbooru Edge Cases', () {
      test('should handle network connection errors gracefully', () async {
        // Arrange
        final credentials = DanbooruCredentials(
          username: 'test_user',
          apiKey: 'test_api_key',
        );

        final error = DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        );

        when(() => mockDio.get(
          any(),
          options: any(named: 'options'),
        )).thenThrow(error);

        // Act
        final result = await apiService.verifyCredentials(credentials);

        // Assert
        expect(result, isNull,
            reason: 'Should return null on connection error');
      });

      test('should handle malformed API response', () async {
        // Arrange
        final credentials = DanbooruCredentials(
          username: 'test_user',
          apiKey: 'test_api_key',
        );

        final mockResponse = Response(
          data: 'invalid_json_response',
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(() => mockDio.get(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.verifyCredentials(credentials);

        // Assert
        expect(result, isNull,
            reason: 'Should return null when API returns invalid data');
      });

      test('should handle empty API response', () async {
        // Arrange
        final credentials = DanbooruCredentials(
          username: 'test_user',
          apiKey: 'test_api_key',
        );

        final mockResponse = Response(
          data: null,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(() => mockDio.get(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.verifyCredentials(credentials);

        // Assert
        expect(result, isNull,
            reason: 'Should return null when API returns empty data');
      });
    });
  });

  group('NovelAI Authentication API', () {
    late MockDio mockDio;
    late MockNAICryptoService mockCryptoService;
    late NAIApiService apiService;

    setUp(() {
      mockDio = MockDio();
      mockCryptoService = MockNAICryptoService();
      apiService = NAIApiService(mockDio, mockCryptoService);
    });

    group('validateToken', () {
      test('should return subscription info for valid token', () async {
        // Arrange
        final token = 'pst-valid_token_123';

        final mockResponse = Response(
          data: {
            'userInfo': {
              'username': 'test_user',
              'id': 'user_123',
            },
            'subscription': {
              'tier': 'unlimited',
              'calculated_training_steps': 0,
            },
            'trainingInfo': {
              'remainingSteps': 0,
              'canTrain': false,
            },
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(() => mockDio.get(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.validateToken(token);

        // Assert
        expect(result, isNotNull,
            reason: 'Should return subscription info for valid token');
        expect(result, containsPair('userInfo', isNotNull),
            reason: 'Should include user information');
        expect(result, containsPair('subscription', isNotNull),
            reason: 'Should include subscription details');
      });

      test('should throw exception for invalid token (401)', () async {
        // Arrange
        final token = 'pst-invalid_token';

        final error = DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(path: ''),
          ),
          type: DioExceptionType.badResponse,
        );

        when(() => mockDio.get(
          any(),
          options: any(named: 'options'),
        )).thenThrow(error);

        // Act & Assert
        expect(
          () => apiService.validateToken(token),
          throwsA(isA<DioException>()),
          reason: 'Should throw DioException for invalid token',
        );
      });

      test('should include correct Bearer token in header', () async {
        // Arrange
        final token = 'pst-test_token';

        final mockResponse = Response(
          data: {
            'userInfo': {'username': 'test'},
            'subscription': {'tier': 'unlimited'},
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(() => mockDio.get(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        await apiService.validateToken(token);

        // Assert
        final captured = verify(() => mockDio.get(
          any(),
          options: captureAny(named: 'options'),
        )).captured;

        final options = captured.first as Options;
        final authHeader = options.headers?['Authorization'];
        expect(
          authHeader,
          equals('Bearer $token'),
          reason: 'Should include Bearer token in authorization header',
        );
      });
    });

    group('loginWithKey', () {
      test('should return access token for valid access key', () async {
        // Arrange
        final accessKey = 'valid_access_key_hash';

        final mockResponse = Response(
          data: {
            'accessToken': 'test_access_token_123',
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(() => mockDio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.loginWithKey(accessKey);

        // Assert
        expect(result, isNotNull,
            reason: 'Should return response for valid access key');
        expect(result, containsPair('accessToken', isNotNull),
            reason: 'Should include access token in response');
        expect(result['accessToken'], isNotEmpty,
            reason: 'Access token should not be empty');
      });

      test('should throw exception for invalid access key (401)', () async {
        // Arrange
        final accessKey = 'invalid_access_key';

        final error = DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            statusCode: 401,
            requestOptions: RequestOptions(path: ''),
          ),
          type: DioExceptionType.badResponse,
        );

        when(() => mockDio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenThrow(error);

        // Act & Assert
        expect(
          () => apiService.loginWithKey(accessKey),
          throwsA(isA<DioException>()),
          reason: 'Should throw DioException for invalid access key',
        );
      });

      test('should include access key in request body', () async {
        // Arrange
        final accessKey = 'test_access_key';

        final mockResponse = Response(
          data: {'accessToken': 'test_token'},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

        when(() => mockDio.post(
          any(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        await apiService.loginWithKey(accessKey);

        // Assert
        final captured = verify(() => mockDio.post(
          any(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        )).captured;

        final requestData = captured.first as Map<String, dynamic>;
        expect(requestData, containsPair('key', accessKey),
            reason: 'Should include access key in request data');
      });
    });

    group('NovelAI Edge Cases', () {
      test('should handle token validation timeout', () async {
        // Arrange
        final token = 'pst-test_token';

        final error = DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        );

        when(() => mockDio.get(
          any(),
          options: any(named: 'options'),
        )).thenThrow(error);

        // Act & Assert
        expect(
          () => apiService.validateToken(token),
          throwsA(isA<DioException>()),
          reason: 'Should throw exception on timeout',
        );
      });

      test('should handle login timeout gracefully', () async {
        // Arrange
        final accessKey = 'test_access_key';

        final error = DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.receiveTimeout,
        );

        when(() => mockDio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenThrow(error);

        // Act & Assert
        expect(
          () => apiService.loginWithKey(accessKey),
          throwsA(isA<DioException>()),
          reason: 'Should throw exception on timeout',
        );
      });

      test('should handle network errors during token validation', () async {
        // Arrange
        final token = 'pst-test_token';

        final error = DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        );

        when(() => mockDio.get(
          any(),
          options: any(named: 'options'),
        )).thenThrow(error);

        // Act & Assert
        expect(
          () => apiService.validateToken(token),
          throwsA(isA<DioException>()),
          reason: 'Should throw exception on network error',
        );
      });
    });
  });

  group('Token Format Validation', () {
    test('should identify valid token format', () {
      // Arrange & Act & Assert
      expect(NAIApiService.isValidTokenFormat('pst-1234567890'), isTrue,
          reason: 'Token with pst- prefix and sufficient length is valid');
      expect(NAIApiService.isValidTokenFormat('pst-abc123xyz'), isTrue,
          reason: 'Token with pst- prefix is valid');
    });

    test('should reject invalid token formats', () {
      // Arrange & Act & Assert
      expect(NAIApiService.isValidTokenFormat('invalid'), isFalse,
          reason: 'Token without pst- prefix is invalid');
      expect(NAIApiService.isValidTokenFormat('pst-'), isFalse,
          reason: 'Token with only prefix is too short');
      expect(NAIApiService.isValidTokenFormat(''), isFalse,
          reason: 'Empty token is invalid');
      expect(NAIApiService.isValidTokenFormat('abc-pst-12345'), isFalse,
          reason: 'Token with wrong prefix order is invalid');
    });
  });

  group('Authentication Integration Scenarios', () {
    late MockDio mockDio;
    late DanbooruApiService danbooruService;

    setUp(() {
      mockDio = MockDio();
      danbooruService = DanbooruApiService(mockDio);
    });

    test('should handle successful authentication flow end-to-end', () async {
      // Arrange
      final credentials = DanbooruCredentials(
        username: 'test_user',
        apiKey: 'test_api_key',
      );

      final mockResponse = Response(
        data: {
          'id': 12345,
          'name': 'test_user',
          'level': 30,
          'level_string': 'Gold',
          'post_upload_count': 100,
          'post_update_count': 50,
          'note_update_count': 10,
          'is_banned': false,
          'can_approve_posts': false,
          'can_upload_free': true,
          'is_super_voter': false,
          'favorite_count': 200,
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

      when(() => mockDio.get(
        any(),
        options: any(named: 'options'),
      )).thenAnswer((_) async => mockResponse);

      // Act
      final user = await danbooruService.verifyCredentials(credentials);

      // Assert
      expect(user, isNotNull,
          reason: 'Authentication should succeed');
      expect(user!.name, equals('test_user'),
          reason: 'Should return correct username');
      expect(user.isPremium, isTrue,
          reason: 'Gold user should be identified as premium');
      expect(user.canUploadFree, isTrue,
          reason: 'Gold users should have free upload privilege');
    });

    test('should handle re-authentication after session expiry', () async {
      // Arrange
      final credentials = DanbooruCredentials(
        username: 'test_user',
        apiKey: 'test_api_key',
      );

      // First call succeeds (session valid)
      final successResponse = Response(
        data: {
          'id': 12345,
          'name': 'test_user',
          'level': 20,
          'level_string': 'Member',
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

      // Second call fails (session expired)
      final error = DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          statusCode: 401,
          requestOptions: RequestOptions(path: ''),
        ),
        type: DioExceptionType.badResponse,
      );

      when(() => mockDio.get(
        any(),
        options: any(named: 'options'),
      )).thenAnswer((_) async => successResponse);

      // Act - First call
      final firstResult = await danbooruService.verifyCredentials(credentials);

      // Reset mock for second call
      reset(mockDio);
      when(() => mockDio.get(
        any(),
        options: any(named: 'options'),
      )).thenThrow(error);

      // Act - Second call (session expired)
      final secondResult = await danbooruService.verifyCredentials(credentials);

      // Assert
      expect(firstResult, isNotNull,
          reason: 'First authentication should succeed');
      expect(secondResult, isNull,
          reason: 'Second authentication should fail when session expired');
    });
  });
}
