import 'dart:async';

import 'package:test/test.dart';
import 'package:w_common/disposable.dart';
import 'package:w_common/func.dart';

import 'stubs.dart';

void testCommonDisposable(Func<StubDisposable> disposableFactory) {
  StubDisposable disposable;

  setUp(() {
    disposable = disposableFactory();
  });

  group('disposalTreeSize', () {
    test('should count all managed objects', () {
      var controller = new StreamController();
      var subscription = controller.stream.listen((_) {});
      disposable.manageStreamController(controller);
      disposable.manageStreamSubscription(subscription);
      disposable.manageDisposable(disposableFactory());
      disposable.manageCompleter(new Completer());
      disposable.getManagedTimer(new Duration(days: 1), () {});
      disposable
          .getManagedDelayedFuture(new Duration(days: 1), () {})
          .catchError((_) {}); // Because we dispose prematurely.
      disposable.getManagedPeriodicTimer(new Duration(days: 1), (_) {});
      expect(disposable.disposalTreeSize, 8);
      disposable.dispose().then(expectAsync1((_) {
        expect(disposable.disposalTreeSize, 1);
      }));
    });

    test('should count nested objects', () {
      var nestedThing = disposableFactory();
      nestedThing.manageDisposable(disposableFactory());
      disposable.manageDisposable(nestedThing);
      expect(disposable.disposalTreeSize, 3);
      disposable.dispose().then(expectAsync1((_) {
        expect(disposable.disposalTreeSize, 1);
      }));
    });
  });

  group('getManagedDelayedFuture', () {
    test('should complete after specified duration', () async {
      var start = new DateTime.now().millisecondsSinceEpoch;
      await disposable.getManagedDelayedFuture(
          new Duration(milliseconds: 10), () => null);
      var end = new DateTime.now().millisecondsSinceEpoch;
      expect(end - start, greaterThanOrEqualTo(10));
    });

    test('should complete with an error on premature dispose', () {
      var future =
          disposable.getManagedDelayedFuture(new Duration(days: 1), () => null);
      future.catchError((e) {
        expect(e, new isInstanceOf<ObjectDisposedException>());
      });
      disposable.dispose();
    });
  });

  group('getManagedTimer', () {
    TimerHarness harness;
    Timer timer;

    setUp(() {
      harness = new TimerHarness();
      timer =
          disposable.getManagedTimer(harness.duration, harness.getCallback());
    });

    test('should cancel timer if disposed before completion', () async {
      expect(timer.isActive, isTrue);
      await disposable.dispose();
      expect(await harness.didCancelTimer, isTrue);
      expect(await harness.didCompleteTimer, isFalse);
    });

    test('disposing should have no effect on timer after it has completed',
        () async {
      await harness.didConclude;
      expect(timer.isActive, isFalse);
      await disposable.dispose();
      expect(await harness.didCancelTimer, isFalse);
      expect(await harness.didCompleteTimer, isTrue);
    });

    test('should return a timer that can call cancel multiple times', () {
      expect(() {
        timer.cancel();
        timer.cancel();
      }, returnsNormally);
    });
  });

  group('getManagedPeriodicTimer', () {
    TimerHarness harness;
    Timer timer;

    setUp(() {
      harness = new TimerHarness();
      timer = disposable.getManagedPeriodicTimer(
          harness.duration, harness.getPeriodicCallback());
    });

    test('should cancel timer if disposed before completion', () async {
      expect(timer.isActive, isTrue);
      await disposable.dispose();
      expect(await harness.didCancelTimer, isTrue);
      expect(await harness.didCompleteTimer, isFalse);
    });

    test(
        'disposing should have no effect on timer after it has cancelled by'
        ' the consumer', () async {
      await harness.didConclude;
      expect(timer.isActive, isFalse);

      await disposable.dispose();
      expect(await harness.didCancelTimer, isFalse);
      expect(await harness.didCompleteTimer, isTrue);
    });

    test('should return a timer that can call cancel multiple times', () {
      expect(() {
        timer.cancel();
        timer.cancel();
      }, returnsNormally);
    });
  });

  group('onDispose', () {
    test('should be called when dispose() is called', () async {
      expect(disposable.wasOnDisposeCalled, isFalse);
      await disposable.dispose();
      expect(disposable.wasOnDisposeCalled, isTrue);
    });
  });

  void testManageMethod(
      String methodName, callback(dynamic argument), dynamic argument,
      {bool doesCallbackReturn: true}) {
    if (doesCallbackReturn) {
      test('should return the argument', () {
        expect(callback(argument), same(argument));
      });
    }

    test('should throw if called with a null argument', () {
      expect(() => callback(null), throwsArgumentError);
    });

    test('should throw if object is disposing', () async {
      disposable.manageDisposer(() async {
        expect(() => callback(argument), throwsStateError);
      });
      await disposable.dispose();
    });

    test('should throw if object has been disposed', () async {
      await disposable.dispose();
      expect(() => callback(argument), throwsStateError);
    });
  }

  group('awaitBeforeDispose', () {
    test('should wait for the future to complete before disposing', () async {
      var completer = new Completer();
      var awaitedFuture = disposable.awaitBeforeDispose(completer.future);
      var disposeFuture = disposable.dispose().then((_) {
        expect(disposable.isDisposing, isFalse,
            reason: 'isDisposing post-complete');
        expect(disposable.isDisposed, isTrue,
            reason: 'isDisposed post-complete');
      });
      await new Future(() {});
      expect(disposable.isDisposing, isTrue,
          reason: 'isDisposing pre-complete');
      expect(disposable.isDisposed, isFalse, reason: 'isDisposed pre-complete');
      completer.complete();
      // It's simpler to do this than ignore a bunch of lints.
      await Future.wait([awaitedFuture, disposeFuture]);
    });

    testManageMethod(
        'waitBeforeDispose',
        (argument) => disposable.awaitBeforeDispose(argument),
        new Future(() {}));
  });

  group('manageCompleter', () {
    test('should complete with an error when parent is disposed', () {
      var completer = new Completer<Null>();
      completer.future.catchError(expectAsync1((exception) {
        expect(exception, new isInstanceOf<ObjectDisposedException>());
      }));
      disposable.manageCompleter(completer);
      disposable.dispose();
    });

    test('should be unmanaged after completion', () {
      var completer = new Completer<Null>();
      disposable.manageCompleter(completer);
      completer.complete(null);
      expect(() => disposable.dispose(), returnsNormally);
    });

    testManageMethod(
        'manageCompleter',
        (argument) => disposable.manageCompleter(argument),
        new Completer<Null>());
  });

  group('manageDisposable', () {
    test('should dispose child when parent is disposed', () async {
      var childThing = disposableFactory();
      disposable.manageDisposable(childThing);
      expect(childThing.isDisposed, isFalse);
      await disposable.dispose();
      expect(childThing.isDisposed, isTrue);
    });

    test('should remove disposable from internal collection if disposed',
        () async {
      var disposeCounter = new DisposeCounter();

      // Manage the disposable child and dispose of it independently
      disposable.manageDisposable(disposeCounter);
      await disposeCounter.dispose();
      await disposable.dispose();

      expect(disposeCounter.disposeCount, 1);
    });

    testManageMethod(
        'manageDisposable',
        (argument) => disposable.manageDisposable(argument),
        disposableFactory(),
        doesCallbackReturn: false);
  });

  group('manageDisposer', () {
    test(
        'should call callback and accept null return value'
        'when parent is disposed', () async {
      disposable.manageDisposer(expectAsync0(() => null));
      await disposable.dispose();
    });

    test(
        'should call callback and accept Future return value'
        'when parent is disposed', () async {
      disposable.manageDisposer(expectAsync0(() => new Future(() {})));
      await disposable.dispose();
    });

    testManageMethod('manageDisposer',
        (argument) => disposable.manageDisposer(argument), () async => null,
        doesCallbackReturn: false);
  });

  group('manageStreamController', () {
    test('should close a broadcast stream when parent is disposed', () async {
      var controller = new StreamController.broadcast();
      disposable.manageStreamController(controller);
      expect(controller.isClosed, isFalse);
      await disposable.dispose();
      expect(controller.isClosed, isTrue);
    });

    test('should close a single-subscription stream when parent is disposed',
        () async {
      var controller = new StreamController();
      var subscription =
          controller.stream.listen(expectAsync1(([_]) {}, count: 0));
      subscription.onDone(expectAsync1(([_]) {}));
      disposable.manageStreamController(controller);
      expect(controller.isClosed, isFalse);
      await disposable.dispose();
      expect(controller.isClosed, isTrue);
      await subscription.cancel();
      await controller.close();
    });

    test(
        'should complete normally for a single-subscription stream, with '
        'a listener, that has been closed when parent is disposed', () async {
      var controller = new StreamController();
      var sub = controller.stream.listen(expectAsync1((_) {}, count: 0));
      disposable.manageStreamController(controller);
      await controller.close();
      await disposable.dispose();
      await sub.cancel();
    });

    test(
        'should complete normally for a single-subscription stream with a '
        'canceled listener when parent is disposed', () async {
      var controller = new StreamController();
      var sub = controller.stream.listen(expectAsync1((_) {}, count: 0));
      disposable.manageStreamController(controller);
      await sub.cancel();
      await disposable.dispose();
    });

    test(
        'should close a single-subscription stream that never had a '
        'listener when parent is disposed', () async {
      var controller = new StreamController();
      disposable.manageStreamController(controller);
      expect(controller.isClosed, isFalse);
      await disposable.dispose();
      expect(controller.isClosed, isTrue);
    });

    testManageMethod(
        'manageStreamController',
        (argument) => disposable.manageStreamController(argument),
        new StreamController(),
        doesCallbackReturn: false);
  });

  group('manageStreamSubscription', () {
    test('should cancel subscription when parent is disposed', () async {
      var controller = new StreamController();
      controller.onCancel = expectAsync1(([_]) {});
      var subscription =
          controller.stream.listen(expectAsync1((_) {}, count: 0));
      disposable.manageStreamSubscription(subscription);
      await disposable.dispose();
      controller.add(null);
      await subscription.cancel();
      await controller.close();
    });

    var controller = new StreamController();
    testManageMethod(
        'manageStreamSubscription',
        (argument) => disposable.manageStreamSubscription(argument),
        controller.stream.listen((_) {}),
        doesCallbackReturn: false);
    controller.close();
  });

  group('flagLeak', () {
    test('should set the leak flag when debug mode is on', () {
      Disposable.enableDebugMode();
      expect(disposable.isLeakFlagSet, isFalse);
      disposable.flagLeak();
      expect(disposable.isLeakFlagSet, isTrue);
      Disposable.disableDebugMode();
    });

    test('should not set the leak flag when debug mode is off', () {
      expect(disposable.isLeakFlagSet, isFalse);
      disposable.flagLeak();
      expect(disposable.isLeakFlagSet, isFalse);
    });

    test('should set the leak flag on dispose when debug mode is on', () async {
      Disposable.enableDebugMode();
      expect(disposable.isLeakFlagSet, isFalse);
      await disposable.dispose();
      expect(disposable.isLeakFlagSet, isTrue);
      Disposable.disableDebugMode();
    });

    test('should not set the leak flag on dispose when debug mode is off',
        () async {
      expect(disposable.isLeakFlagSet, isFalse);
      await disposable.dispose();
      expect(disposable.isLeakFlagSet, isFalse);
    });
  });
}
