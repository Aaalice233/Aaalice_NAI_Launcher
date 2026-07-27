import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/sd_to_nai_converter.dart';

void main() {
  group('SdToNaiConverter', () {
    test(
      'should not treat tag names with trailing parenthetical qualifiers as SD weights',
      () {
        expect(
          SdToNaiConverter.convert('summer dress (blue_archive)'),
          equals('summer dress (blue_archive)'),
        );
      },
    );

    test('should preserve inline parenthetical qualifiers with spaces', () {
      expect(
        SdToNaiConverter.convert('summer dress (blue archive)'),
        equals('summer dress (blue archive)'),
      );
      expect(
        SdToNaiConverter.convert('artist name (fate grand order)'),
        equals('artist name (fate grand order)'),
      );
      expect(
        SdToNaiConverter.convert('preset tag (1.2)'),
        equals('preset tag (1.2)'),
      );
    });

    test(
      'should preserve bare brackets while converting explicit SD weights',
      () {
        expect(
          SdToNaiConverter.convert(
            'summer dress (blue archive), (cinematic lighting), '
            '[bad anatomy], (dramatic shadows:1.25)',
          ),
          equals(
            'summer dress (blue archive), (cinematic lighting), '
            '[bad anatomy], 1.25::dramatic shadows::',
          ),
        );
      },
    );

    test('should preserve standalone NAI-compatible brackets', () {
      expect(
        SdToNaiConverter.convert('(masterpiece)'),
        equals('(masterpiece)'),
      );
      expect(
        SdToNaiConverter.convert('[bad anatomy]'),
        equals('[bad anatomy]'),
      );
      expect(
        SdToNaiConverter.convert('((masterpiece))'),
        equals('((masterpiece))'),
      );
    });

    test('should preserve spaces when only converting SD syntax', () {
      expect(
        SdToNaiConverter.convert('(cinematic lighting:1.3)'),
        equals('1.3::cinematic lighting::'),
      );
    });

    test('should unescape escaped parentheses without SD weights', () {
      expect(
        SdToNaiConverter.convert(r'\(literal parentheses\)'),
        equals('(literal parentheses)'),
      );
    });

    test('should unescape escaped parentheses when NAI syntax is present', () {
      expect(
        SdToNaiConverter.convert(r'1.2::tag::, \(literal\)'),
        equals('1.2::tag::, (literal)'),
      );
    });

    test('should convert SD weights when NAI numeric syntax is present', () {
      expect(
        SdToNaiConverter.convert(
          '1.2::masterpiece::, (cinematic lighting:1.3), [bad anatomy]',
        ),
        equals('1.2::masterpiece::, 1.3::cinematic lighting::, [bad anatomy]'),
      );
    });

    test('should convert SD weights when NAI brace syntax is present', () {
      expect(
        SdToNaiConverter.convert('{best quality}, (cinematic lighting:1.3)'),
        equals('{best quality}, 1.3::cinematic lighting::'),
      );
    });

    test('should unescape escaped parentheses while converting SD weights', () {
      expect(
        SdToNaiConverter.convert(r'\(literal\), (cinematic lighting:1.3)'),
        equals('(literal), 1.3::cinematic lighting::'),
      );
    });

    test('should only detect explicit bracket weights as SD syntax', () {
      expect(SdToNaiConverter.hasSDWeightSyntax('(masterpiece)'), isFalse);
      expect(SdToNaiConverter.hasSDWeightSyntax('[bad anatomy]'), isFalse);
      expect(SdToNaiConverter.hasSDWeightSyntax('(masterpiece:1.2)'), isTrue);
      expect(SdToNaiConverter.hasSDWeightSyntax('[bad anatomy:0.8]'), isTrue);
      expect(SdToNaiConverter.hasSDWeightSyntax('(red hair:.5)'), isTrue);
      expect(SdToNaiConverter.hasSDWeightSyntax('(tag:-.5)'), isTrue);
      expect(SdToNaiConverter.hasSDWeightSyntax('((red hair):1.2)'), isTrue);
    });

    test('should convert leading-decimal and nested explicit weights', () {
      expect(
        SdToNaiConverter.convert('(red hair:.5)'),
        equals('0.5::red hair::'),
      );
      expect(SdToNaiConverter.convert('(tag:-.5)'), equals('-0.5::tag::'));
      expect(
        SdToNaiConverter.convert('((red hair):1.2)'),
        equals('1.2::(red hair)::'),
      );
    });

    test('should convert explicit square-bracket weights', () {
      expect(
        SdToNaiConverter.convert('[bad anatomy:0.8]'),
        equals('0.8::bad anatomy::'),
      );
    });
  });
}
