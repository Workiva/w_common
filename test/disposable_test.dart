import 'dart:async';

import 'package:w_common/w_common.dart';
import 'package:test/test.dart';

class DisposableThing extends Object with Disposable {
  bool wasOnDisposeCalled = false;

  Future<Null> onDispose() {
    wasOnDisposeCalled = true;
    return didDispose;
  }
}

void main() {
  group('Disposable', () {
    DisposableThing thing;

    setUp(() {
      thing = new DisposableThing();
    });

    group('onDispose', () {
      test('should be called when dispose() is called', () {
        expect(thing.wasOnDisposeCalled, isFalse);
        thing.dispose();
        expect(thing.wasOnDisposeCalled, isTrue);
      });
    });
  });
}
