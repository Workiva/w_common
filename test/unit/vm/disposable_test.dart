import 'dart:async';

import 'package:test/test.dart';

import '../../../lib/src/disposable.dart';
import 'typedefs.dart';

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
      test('should close a broadcast stream when parent is disposed', () async {
        var controller = new StreamController.broadcast();
        thing.manageStreamController(controller);
        expect(controller.isClosed, isFalse);
        await thing.dispose();
        expect(controller.isClosed, isTrue);
      });

      test('should close a single-subscription stream when parent is disposed',
          () async {
        var controller = new StreamController();
        var subscription = controller.stream
            .listen(expectAsync(([_]) {}, count: 0) as StreamListener);
        subscription.onDone(expectAsync(([_]) {}, count: 1) as StreamListener);
        thing.manageStreamController(controller);
        expect(controller.isClosed, isFalse);
        await thing.dispose();
        expect(controller.isClosed, isTrue);
      });

      test(
          'should close a single-subscription stream with no listener'
          'when parent is disposed', () async {
        var controller = new StreamController();
        thing.manageStreamController(controller);
        expect(controller.isClosed, isFalse);
        await thing.dispose();
        expect(controller.isClosed, isTrue);
      });
    });

    group('manageStreamSubscription', () {
      test('should cancel subscription when parent is disposed', () async {
        var controller = new StreamController();
        controller.onCancel = expectAsync(([_]) {}, count: 1);
        var subscription = controller.stream
            .listen(expectAsync((_) {}, count: 0) as StreamListener);
        thing.manageStreamSubscription(subscription);
        await thing.dispose();
        controller.add(null);
      });
    });
  });
}
