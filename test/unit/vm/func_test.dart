import 'package:test/test.dart';
import 'package:w_common/src/func.dart';

void main() {
  group('Func<T>', () {
    test('works as a type', () {
      final f = () => new TestModel();
      final testFunction = (Func<TestModel> modelGetter) {
        expect(modelGetter(), new isInstanceOf<TestModel>());
      };

      testFunction(f);
    });
  });
}

class TestModel {}
