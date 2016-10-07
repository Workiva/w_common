import 'dart:async';

import 'package:test/test.dart';
import 'package:w_common/w_common.dart';
//import 'dart:html';

class DisposableThing extends Disposable {
  bool wasOnDisposeCalled = false;

  @override
  Future<Null> onDispose() {
    wasOnDisposeCalled = true;
    return new Future(() {});
  }
}

void main() {
  group('InvalidationMixin', () {
    InvalidThing thing;

    setUp(() {
      thing = new InvalidThing();
    });

    group('invalidate', () {
      test('marks the thing as invalid', () {
        thing.invalidate();

        expect(thing.invalid, isTrue);

        thing.cancelInvalidation();

        expect(thing.invalid, isFalse);
      });

      test('does a thing', () async {
        thing.invalidate();

        thing.onValidate.listen(expectAsync((_) {}, count: 1));
      });
    });
  });
}

class InvalidThing extends InvalidationMixin {
  StreamController _onValidate = new StreamController.broadcast();
  Stream get onValidate => _onValidate.stream;

  void validate() {
    _onValidate.add(null);
  }
}
