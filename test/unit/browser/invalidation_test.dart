import 'dart:async';

import 'package:test/test.dart';
import 'package:w_common/w_common.dart';

void main() {
  group('InvalidationMixin', () {
    InvalidThing thing;

    setUp(() {
      thing = new InvalidThing();
    });

    tearDown(() {
      thing.dispose();
    });

    group('invalidate', () {
      test('marks the thing as invalid', () {
        Future onValidation = thing.invalidate();

        expect(thing.invalid, isTrue);

        onValidation.catchError(
            expectAsync((InvalidationCancelledException e) {}, count: 1));

        thing.cancelInvalidation();

        expect(thing.invalid, isFalse);
      });

      test('calls validate, eventually', () async {
        Future onValidation = thing.invalidate();

        // ignore: unawaited_futures
        onValidation.then(expectAsync((_) {}, count: 1));

        // ignore: STRONG_MODE_DOWN_CAST_COMPOSITE
        thing.onValidate.listen(expectAsync((_) {}, count: 1));
      });
    });
  });
}

class InvalidThing extends InvalidationMixin {
  StreamController _onValidate = new StreamController.broadcast();
  Stream get onValidate => _onValidate.stream;

  @override
  void validate() {
    _onValidate.add(null);
  }

  void dispose() {
    _onValidate.close();
  }
}
