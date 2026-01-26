import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations_en.dart';
import 'package:nai_launcher/core/services/auth_error_service.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';

void main() {
  group('AuthErrorService', () {
    late AuthErrorService service;
    late AppLocalizations l10n;

    setUp(() {
      service = AuthErrorService();
      l10n = AppLocalizationsEn();
    });

    group('getErrorText', () {
      group('Network Errors', () {
        test('should return network timeout text', () {
          // Arrange
          const errorCode = AuthErrorCode.networkTimeout;

          // Act
          final errorText = service.getErrorText(l10n, errorCode, null);

          // Assert
          expect(errorText, equals('Connection timeout'),
              reason: 'Should return network timeout error text',);
        });

        test('should return network error text', () {
          // Arrange
          const errorCode = AuthErrorCode.networkError;

          // Act
          final errorText = service.getErrorText(l10n, errorCode, null);

          // Assert
          expect(errorText, equals('Network error'),
              reason: 'Should return network error text',);
        });
      });

      group('Authentication Errors', () {
        test('should return auth failed text for general auth error', () {
          // Arrange
          const errorCode = AuthErrorCode.authFailed;

          // Act
          final errorText = service.getErrorText(l10n, errorCode, null);

          // Assert
          expect(errorText, equals('Authentication failed'),
              reason: 'Should return authentication failed text',);
        });

        test('should return token expired text for auth failed with 401',
            () {
          // Arrange
          const errorCode = AuthErrorCode.authFailed;
          const httpStatusCode = 401;

          // Act
          final errorText = service.getErrorText(l10n, errorCode, httpStatusCode);

          // Assert
          expect(errorText, equals('Token expired, please login again'),
              reason: 'Should return token expired text for 401 status',);
        });

        test('should return token invalid text', () {
          // Arrange
          const errorCode = AuthErrorCode.tokenInvalid;

          // Act
          final errorText = service.getErrorText(l10n, errorCode, null);

          // Assert
          expect(errorText, equals('Invalid token format, should start with pst-'),
              reason: 'Should return invalid token text',);
        });
      });

      group('Server Errors', () {
        test('should return server error text', () {
          // Arrange
          const errorCode = AuthErrorCode.serverError;

          // Act
          final errorText = service.getErrorText(l10n, errorCode, null);

          // Assert
          expect(errorText, equals('Server error'),
              reason: 'Should return server error text',);
        });
      });

      group('Unknown Errors', () {
        test('should return unknown error text', () {
          // Arrange
          const errorCode = AuthErrorCode.unknown;

          // Act
          final errorText = service.getErrorText(l10n, errorCode, null);

          // Assert
          expect(errorText, equals('Unknown error'),
              reason: 'Should return unknown error text',);
        });
      });
    });

    group('getErrorRecoveryHint', () {
      group('Network Errors', () {
        test('should return timeout recovery hint for network timeout', () {
          // Arrange
          const errorCode = AuthErrorCode.networkTimeout;

          // Act
          final hint = service.getErrorRecoveryHint(l10n, errorCode, null);

          // Assert
          expect(hint, equals('Network timeout. Please check your connection and try again'),
              reason: 'Should return timeout recovery hint',);
        });

        test('should return network error recovery hint', () {
          // Arrange
          const errorCode = AuthErrorCode.networkError;

          // Act
          final hint = service.getErrorRecoveryHint(l10n, errorCode, null);

          // Assert
          expect(hint, equals('Cannot connect to server. Please check your network'),
              reason: 'Should return network error recovery hint',);
        });
      });

      group('Authentication Errors', () {
        test('should return 401 recovery hint for auth failed with 401',
            () {
          // Arrange
          const errorCode = AuthErrorCode.authFailed;
          const httpStatusCode = 401;

          // Act
          final hint = service.getErrorRecoveryHint(l10n, errorCode, httpStatusCode);

          // Assert
          expect(hint, equals('Token invalid or expired. Please login again'),
              reason: 'Should return 401 recovery hint',);
        });

        test('should return 401 recovery hint for auth failed without status',
            () {
          // Arrange
          const errorCode = AuthErrorCode.authFailed;

          // Act
          final hint = service.getErrorRecoveryHint(l10n, errorCode, null);

          // Assert
          expect(hint, equals('Token invalid or expired. Please login again'),
              reason: 'Should return 401 recovery hint even without status code',);
        });

        test('should return 401 recovery hint for token invalid', () {
          // Arrange
          const errorCode = AuthErrorCode.tokenInvalid;

          // Act
          final hint = service.getErrorRecoveryHint(l10n, errorCode, null);

          // Assert
          expect(hint, equals('Token invalid or expired. Please login again'),
              reason: 'Should return 401 recovery hint for invalid token',);
        });
      });

      group('Server Errors', () {
        test('should return 503 recovery hint for server error with 503',
            () {
          // Arrange
          const errorCode = AuthErrorCode.serverError;
          const httpStatusCode = 503;

          // Act
          final hint = service.getErrorRecoveryHint(l10n, errorCode, httpStatusCode);

          // Assert
          expect(hint, equals('Server is under maintenance or overloaded. Please try again later'),
              reason: 'Should return 503 recovery hint',);
        });

        test('should return 500 recovery hint for server error without status',
            () {
          // Arrange
          const errorCode = AuthErrorCode.serverError;

          // Act
          final hint = service.getErrorRecoveryHint(l10n, errorCode, null);

          // Assert
          expect(hint, equals('NovelAI server error. Please try again later'),
              reason: 'Should return 500 recovery hint for general server error',);
        });

        test('should return 500 recovery hint for server error with 500',
            () {
          // Arrange
          const errorCode = AuthErrorCode.serverError;
          const httpStatusCode = 500;

          // Act
          final hint = service.getErrorRecoveryHint(l10n, errorCode, httpStatusCode);

          // Assert
          expect(hint, equals('NovelAI server error. Please try again later'),
              reason: 'Should return 500 recovery hint',);
        });
      });

      group('Unknown Errors', () {
        test('should return null for unknown error', () {
          // Arrange
          const errorCode = AuthErrorCode.unknown;

          // Act
          final hint = service.getErrorRecoveryHint(l10n, errorCode, null);

          // Assert
          expect(hint, isNull,
              reason: 'Should return null for unknown error',);
        });
      });
    });

    group('getErrorMessage', () {
      test('should return complete error message with hint', () {
        // Arrange
        const errorCode = AuthErrorCode.networkTimeout;

        // Act
        final errorMessage = service.getErrorMessage(l10n, errorCode, null);

        // Assert
        expect(errorMessage.errorText, equals('Connection timeout'),
            reason: 'Should contain error text',);
        expect(errorMessage.recoveryHint, equals('Network timeout. Please check your connection and try again'),
            reason: 'Should contain recovery hint',);
        expect(errorMessage.hasRecoveryHint, isTrue,
            reason: 'Should have recovery hint',);
      });

      test('should return error message without hint for unknown error', () {
        // Arrange
        const errorCode = AuthErrorCode.unknown;

        // Act
        final errorMessage = service.getErrorMessage(l10n, errorCode, null);

        // Assert
        expect(errorMessage.errorText, equals('Unknown error'),
            reason: 'Should contain error text',);
        expect(errorMessage.recoveryHint, isNull,
            reason: 'Should not have recovery hint',);
        expect(errorMessage.hasRecoveryHint, isFalse,
            reason: 'Should not have recovery hint',);
      });

      test('should handle auth failed with 401 status', () {
        // Arrange
        const errorCode = AuthErrorCode.authFailed;
        const httpStatusCode = 401;

        // Act
        final errorMessage = service.getErrorMessage(l10n, errorCode, httpStatusCode);

        // Assert
        expect(errorMessage.errorText, equals('Token expired, please login again'),
            reason: 'Should return token expired text',);
        expect(errorMessage.recoveryHint, equals('Token invalid or expired. Please login again'),
            reason: 'Should return 401 recovery hint',);
      });

      test('should handle server error with 503 status', () {
        // Arrange
        const errorCode = AuthErrorCode.serverError;
        const httpStatusCode = 503;

        // Act
        final errorMessage = service.getErrorMessage(l10n, errorCode, httpStatusCode);

        // Assert
        expect(errorMessage.errorText, equals('Server error'),
            reason: 'Should return server error text',);
        expect(errorMessage.recoveryHint, equals('Server is under maintenance or overloaded. Please try again later'),
            reason: 'Should return 503 recovery hint',);
      });
    });

    group('AuthErrorMessage', () {
      group('Constructor and Properties', () {
        test('should create instance with error text and hint', () {
          // Arrange
          const errorText = 'Test error';
          const recoveryHint = 'Test hint';

          // Act
          const message = AuthErrorMessage(errorText, recoveryHint);

          // Assert
          expect(message.errorText, equals(errorText),
              reason: 'Error text should match provided value',);
          expect(message.recoveryHint, equals(recoveryHint),
              reason: 'Recovery hint should match provided value',);
          expect(message.hasRecoveryHint, isTrue,
              reason: 'Should have recovery hint',);
        });

        test('should create instance with error text and null hint', () {
          // Arrange
          const errorText = 'Test error';

          // Act
          const message = AuthErrorMessage(errorText, null);

          // Assert
          expect(message.errorText, equals(errorText),
              reason: 'Error text should match provided value',);
          expect(message.recoveryHint, isNull,
              reason: 'Recovery hint should be null',);
          expect(message.hasRecoveryHint, isFalse,
              reason: 'Should not have recovery hint',);
        });
      });

      group('toString', () {
        test('should return string representation with hint', () {
          // Arrange
          const message = AuthErrorMessage('Test error', 'Test hint');

          // Act
          final string = message.toString();

          // Assert
          expect(string, contains('Test error'),
              reason: 'Should contain error text',);
          expect(string, contains('Test hint'),
              reason: 'Should contain recovery hint',);
        });

        test('should return string representation without hint', () {
          // Arrange
          const message = AuthErrorMessage('Test error', null);

          // Act
          final string = message.toString();

          // Assert
          expect(string, contains('Test error'),
              reason: 'Should contain error text',);
          expect(string, contains('null'),
              reason: 'Should show null for recovery hint',);
        });
      });
    });

    group('Edge Cases', () {
      test('should handle all error codes with null status code', () {
        // Arrange
        const errorCodes = AuthErrorCode.values;

        // Act & Assert
        for (final errorCode in errorCodes) {
          final errorText = service.getErrorText(l10n, errorCode, null);
          expect(errorText, isNotEmpty,
              reason: '$errorCode should return non-empty error text',);
        }
      });

      test('should handle network errors with various status codes', () {
        // Arrange
        final errorCodes = [
          AuthErrorCode.networkTimeout,
          AuthErrorCode.networkError,
        ];
        final statusCodes = [null, 200, 500, 503];

        // Act & Assert
        for (final errorCode in errorCodes) {
          for (final statusCode in statusCodes) {
            final errorText = service.getErrorText(l10n, errorCode, statusCode);
            expect(errorText, isNotEmpty,
                reason: '$errorCode with status $statusCode should return non-empty error text',);
          }
        }
      });

      test('should handle auth errors with various status codes', () {
        // Arrange
        final authErrorTests = {
          AuthErrorCode.authFailed: [null, 401, 403],
          AuthErrorCode.tokenInvalid: [null, 401, 403],
        };

        // Act & Assert
        authErrorTests.forEach((errorCode, statusCodes) {
          for (final statusCode in statusCodes) {
            final errorMessage = service.getErrorMessage(l10n, errorCode, statusCode);
            expect(errorMessage.errorText, isNotEmpty,
                reason: '$errorCode with status $statusCode should return non-empty error text',);
          }
        });
      });

      test('should handle server errors with various status codes', () {
        // Arrange
        final serverErrorTests = [null, 500, 502, 503, 504];

        // Act & Assert
        for (final statusCode in serverErrorTests) {
          final errorMessage = service.getErrorMessage(l10n, AuthErrorCode.serverError, statusCode);
          expect(errorMessage.errorText, isNotEmpty,
              reason: 'Server error with status $statusCode should return non-empty error text',);
        }
      });

      test('should consistently return hint for same error conditions', () {
        // Arrange
        const errorCode = AuthErrorCode.networkTimeout;
        const statusCode = null;

        // Act
        final hint1 = service.getErrorRecoveryHint(l10n, errorCode, statusCode);
        final hint2 = service.getErrorRecoveryHint(l10n, errorCode, statusCode);

        // Assert
        expect(hint1, equals(hint2),
            reason: 'Should return consistent hint for same error conditions',);
      });
    });
  });
}
