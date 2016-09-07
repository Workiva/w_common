import 'dart:async';

import 'package:test/test.dart';

import 'package:w_common/w_common.dart';

typedef void StreamCallback(dynamic _);

class DisposableThing extends Disposable {
  bool wasOnDisposeCalled = false;

  @override
  Future<Null> onDispose() {
    wasOnDisposeCalled = true;
    return new Future(() {});
  }
}

void main() {
  group('Disposable', () {
    DisposableThing thing;

    setUp(() {
      thing = new DisposableThing();
    });

    group('onDispose', () {
      test('should be called when dispose() is called', () async {
        expect(thing.wasOnDisposeCalled, isFalse);
        await thing.dispose();
        expect(thing.wasOnDisposeCalled, isTrue);
      });
    });

    group('manageDisposable', () {
      test('should dispose child when parent is disposed', () async {
        var childThing = new DisposableThing();
        thing.manageDisposable(childThing);
        expect(childThing.isDisposed, isFalse);
        await thing.dispose();
        expect(childThing.isDisposed, isTrue);
      });
    });

    group('manageStreamController', () {
      test('should close stream when parent is disposed', () async {
        var controller = new StreamController.broadcast();
        thing.manageStreamController(controller);
        expect(controller.isClosed, isFalse);
        await thing.dispose();
        expect(controller.isClosed, isTrue);
      });
    });

    group('manageStreamSubscription', () {
      test('should cancel subscription when parent is disposed', () async {
        var controller = new StreamController();
        var subscription = controller.stream
            .listen(expectAsync((_) {}, count: 0) as StreamCallback);
        thing.manageStreamSubscription(subscription);
        await thing.dispose();
        controller.add(null);
      });
    });
  });
}
