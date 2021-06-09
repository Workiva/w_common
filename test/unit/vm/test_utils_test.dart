// @dart=2.7
// ^ Do not remove until migrated to null safety. More info at https://wiki.atl.workiva.net/pages/viewpage.action?pageId=189370832
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
        final c = MismatchClass<dynamic>();
        expect(() => verifyDisposableTypeName(c, makeAssertion: true),
            throwsA(isA<AssertionError>()));
      });

      test(
          'should not throw AssertionError on name mismatch when makeAssertion != true',
          () {
        final c = MismatchClass<dynamic>();
        expect(() => verifyDisposableTypeName(c, makeAssertion: false),
            returnsNormally);
      });

      test('should always return name when names match', () {
        final c = MatchClass<dynamic>();
        final name = verifyDisposableTypeName(c);
        expect(name, Symbol('MatchClass'));
      });

      test('should always return name when makeAssertion = false', () {
        final c = MismatchClass<dynamic>();
        final name = verifyDisposableTypeName(c, makeAssertion: false);
        expect(name, Symbol('MismatchClass'));
      });
    });
  });
}

class MatchClass<T> extends Disposable {
  @override
  String get disposableTypeName => 'MatchClass';
}

class MismatchClass<T> extends Disposable {}
