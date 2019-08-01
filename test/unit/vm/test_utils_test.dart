@TestOn('vm')
import 'package:test/test.dart';
import 'package:w_common/disposable.dart';
import 'package:w_common/test_utils.dart';

void main() {
  group('test_utils', () {
    group('verifyDisposableTypeName', () {
      test(
          'should throw AssertionError on name mismatch when makeAssertion == true',
          () {
        final c = new MismatchClass<dynamic>();
        expect(() => verifyDisposableTypeName(c, makeAssertion: true),
            throwsA(const isInstanceOf<AssertionError>()));
      });

      test(
          'should not throw AssertionError on name mismatch when makeAssertion != true',
          () {
        final c = new MismatchClass<dynamic>();
        expect(() => verifyDisposableTypeName(c, makeAssertion: false),
            returnsNormally);
      });

      test('should always return name when names match', () {
        final c = new MatchClass<dynamic>();
        final name = verifyDisposableTypeName(c);
        expect(name, new Symbol('MatchClass'));
      });

      test('should always return name when makeAssertion = false', () {
        final c = new MismatchClass<dynamic>();
        final name = verifyDisposableTypeName(c, makeAssertion: false);
        expect(name, new Symbol('MismatchClass'));
      });
    });
  });
}

class MatchClass<T> extends Disposable {
  @override
  String get disposableTypeName => 'MatchClass';
}

class MismatchClass<T> extends Disposable {}
