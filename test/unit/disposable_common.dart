import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:w_common/disposable.dart';
import 'package:w_common/func.dart';

import 'stubs.dart';

void testCommonDisposable(Func<StubDisposable> disposableFactory) {
  StubDisposable disposable;

  void testManageMethod(
      String methodName, callback(dynamic argument), dynamic argument,
      {bool doesCallbackReturnArgument: true}) {
    if (doesCallbackReturnArgument) {
      test('should return the argument', () {
        expect(callback(argument), same(argument));
      });
    }

    test('should throw if called with a null argument', () {
      expect(() => callback(null), throwsArgumentError);
    });

    test('should throw if object is disposing', () async {
      disposable.getManagedDisposer(() async {
        expect(() => callback(argument), throwsStateError);
      });
      await disposable.dispose();
    });

    test('should throw if object has been disposed', () async {
      await disposable.dispose();
      expect(() => callback(argument), throwsStateError);
    });
  }

  void testManageMethod2(
      String methodName,
      callback(dynamic argument, dynamic secondArgument),
      dynamic argument,
      dynamic secondArgument) {
    test('should throw if called with a null argument', () {
      expect(() => callback(null, secondArgument), throwsArgumentError);
    });

    test('should throw if called with a null argument', () {
      expect(() => callback(argument, null), throwsArgumentError);
    });

    test('should throw if object is disposing', () async {
      disposable.getManagedDisposer(() async {
        expect(() => callback(argument, secondArgument), throwsStateError);
      });
      await disposable.dispose();
    });

    test('should throw if object has been disposed', () async {
      await disposable.dispose();
      expect(() => callback(argument, secondArgument), throwsStateError);
    });
  }

  Stream getNullReturningSubscriptionStream() {
    var stream = new MockStream();
    var nullReturningSub = new MockStreamSubscription();

    when(nullReturningSub.cancel()).thenReturn(null);
    when(stream.listen(typed(any),
            onDone: typed(any, named: 'onDone'),
            onError: typed(any, named: 'onError'),
            cancelOnError: typed(any, named: 'cancelOnError')))
        .thenReturn(nullReturningSub);

    return stream;
  }

  setUp(() {
    disposable = disposableFactory();
  });

  group('disposalTreeSize', () {
    test('should count all managed objects', () {
      var controller = new StreamController();
      disposable.manageStreamController(controller);
      disposable.listenToStream(controller.stream, (_) {});
      disposable.manageDisposable(disposableFactory());
      disposable.manageCompleter(new Completer());
      disposable.getManagedTimer(new Duration(days: 1), () {});
      disposable
          .getManagedDelayedFuture(new Duration(days: 1), () {})
          .catchError((_) {}); // Because we dispose prematurely.
      disposable.getManagedPeriodicTimer(new Duration(days: 1), (_) {});
      expect(disposable.disposalTreeSize, 8);
      return disposable.dispose().then((_) {
        expect(disposable.disposalTreeSize, 1);
      });
    });

    test('should count nested objects', () {
      var nestedThing = disposableFactory();
      nestedThing.manageDisposable(disposableFactory());
      disposable.manageDisposable(nestedThing);
      expect(disposable.disposalTreeSize, 3);
      return disposable.dispose().then((_) {
        expect(disposable.disposalTreeSize, 1);
      });
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

    test('should throw during disposal', () async {
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      // ignore: unawaited_futures
      disposable.dispose();
      await new Future(() {});
      expect(disposable.isDisposing, isTrue);
      expect(
          () => disposable.getManagedDelayedFuture(
              new Duration(seconds: 10), () => null),
          throwsStateError);
      completer.complete();
    });

    test('should throw after disposal', () async {
      await disposable.dispose();
      expect(disposable.isDisposed, isTrue);
      expect(
          () => disposable.getManagedDelayedFuture(
              new Duration(seconds: 10), () => null),
          throwsStateError);
    });
  });

  group('manageAndReturnDisposable', () {
    void injectDisposable({Disposable injected}) {
      disposable.injected =
          injected ?? disposable.manageAndReturnDisposable(disposableFactory());
    }

    test('should dispose managed disposable', () async {
      injectDisposable();
      await disposable.dispose();
      expect(disposable.injected, isNotNull);
      expect(disposable.isDisposed, isTrue);
      expect(disposable.injected.isDisposed, isTrue);
    });

    test('should not dispose injected variable', () async {
      injectDisposable(injected: disposableFactory());
      await disposable.dispose();
      expect(disposable.injected, isNotNull);
      expect(disposable.isDisposed, isTrue);
      expect(disposable.injected.isDisposed, isFalse);
    });

    testManageMethod(
        'manageAndReturnDisposable',
        (argument) => disposable.manageAndReturnDisposable(argument),
        disposableFactory());
  });

  group('getManagedDisposer', () {
    test(
        'should call callback and accept null return value'
        'when parent is disposed', () async {
      disposable.getManagedDisposer(expectAsync0(() => null));
      await disposable.dispose();
    });

    test(
        'should call callback and accept Future return value'
        'when parent is disposed', () async {
      disposable.getManagedDisposer(expectAsync0(() => new Future(() {})));
      await disposable.dispose();
    });

    test(
        'should call callback and accept null return value'
        'when disposed before parent', () async {
      var managedDisposable =
          disposable.getManagedDisposer(expectAsync0(() => null));
      await managedDisposable.dispose();
    });

    test(
        'should call callback and accept Future return value'
        'when disposed before parent', () async {
      var managedDisposable =
          disposable.getManagedDisposer(expectAsync0(() => new Future(() {})));
      await managedDisposable.dispose();
    });

    test(
        'regression test: for historical reasons dispose should return a'
        'synchronous (immediately completing rather than enqueued) future'
        'when a Disposer returns null', () async {
      var testList = <String>[];
      // ignore: unawaited_futures
      new Future(() {
        testList.add('b');
      });

      var managedDisposable = disposable.getManagedDisposer(() => null);

      // ignore: unawaited_futures
      managedDisposable.dispose().then((_) {
        testList.add('a');
      });

      await new Future(() {});

      expect(testList, equals(['a', 'b']));
    });

    test('should remove references to Disposer when disposed before parent',
        () async {
      var previousTreeSize = disposable.disposalTreeSize;

      var managedDisposable = disposable.getManagedDisposer(() {});

      expect(disposable.disposalTreeSize, equals(previousTreeSize + 1));

      await managedDisposable.dispose();
      await new Future(() {});

      expect(disposable.isDisposed, isFalse);
      expect(disposable.disposalTreeSize, equals(previousTreeSize));
    });

    testManageMethod('getManagedDisposer',
        (argument) => disposable.getManagedDisposer(argument), () {},
        doesCallbackReturnArgument: false);
  });

  group('listenToStream', () {
    test('should cancel subscription when parent is disposed', () async {
      var controller = new StreamController();
      controller.onCancel = expectAsync1(([_]) {}, count: 1);
      disposable.listenToStream(
          controller.stream, expectAsync1((_) {}, count: 0));
      await disposable.dispose();
      controller.add(null);
      await controller.close();
    });

    test('should not throw if stream subscription is canceled after disposal',
        () async {
      var controller = new StreamController<Null>();
      StreamSubscription<Null> subscription =
          disposable.listenToStream<Null>(controller.stream, (_) {});
      await disposable.dispose();
      expect(() async => await subscription.cancel(), returnsNormally);
      await controller.close();
    });

    test(
        'should return ManagedStreamSubscription that returns null when an'
        'unwrapped StreamSubscription would have', () async {
      var stream = getNullReturningSubscriptionStream();

      var unwrappedSubscription = stream.listen((_) {},
          onDone: null, onError: null, cancelOnError: false);

      expect(unwrappedSubscription.cancel(), isNull);

      var managedSubscription = disposable.listenToStream(stream, (_) {});

      expect(managedSubscription.cancel(), isNull);
    });

    test(
        'should remove references when stream subscription is closed before'
        'disposal when canceling a stream subscription returns null', () async {
      var previousTreeSize = disposable.disposalTreeSize;

      var stream = getNullReturningSubscriptionStream();

      StreamSubscription subscription =
          disposable.listenToStream(stream, (_) {});

      expect(disposable.disposalTreeSize, equals(previousTreeSize + 1));

      await subscription.cancel();
      await new Future(() {});

      expect(disposable.isDisposed, isFalse);
      expect(disposable.disposalTreeSize, equals(previousTreeSize));
    });

    test(
        'should remove references when stream subscription is closed before'
        'disposal when canceling a stream subscription returns a Future',
        () async {
      var previousTreeSize = disposable.disposalTreeSize;
      var controller = new StreamController<Null>();
      StreamSubscription<Null> subscription =
          disposable.listenToStream<Null>(controller.stream, (_) {});

      expect(disposable.disposalTreeSize, equals(previousTreeSize + 1));

      await subscription.cancel();
      await new Future(() {});

      expect(disposable.isDisposed, isFalse);
      expect(disposable.disposalTreeSize, equals(previousTreeSize));

      await controller.close();
    });

    var controller = new StreamController();
    testManageMethod2(
        'listenToStream',
        (argument, secondArgument) =>
            disposable.listenToStream(argument, secondArgument),
        controller.stream,
        (_) {});
    controller.close();
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

    test('should return a timer that can be canceled inside its callback',
        () async {
      timer.cancel();
      timer = disposable.getManagedTimer(harness.duration, expectAsync0(() {
        timer.cancel();
      }));
    });

    test('should throw during disposal', () async {
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      // ignore: unawaited_futures
      disposable.dispose();
      await new Future(() {});
      expect(disposable.isDisposing, isTrue);
      expect(
          () =>
              disposable.getManagedTimer(new Duration(seconds: 10), () => null),
          throwsStateError);
      completer.complete();
    });

    test('should throw after disposal', () async {
      await disposable.dispose();
      expect(disposable.isDisposed, isTrue);
      expect(
          () =>
              disposable.getManagedTimer(new Duration(seconds: 10), () => null),
          throwsStateError);
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

    test('should return a timer that can be canceled inside its callback',
        () async {
      timer.cancel();
      timer = disposable.getManagedTimer(harness.duration, expectAsync0(() {
        timer.cancel();
      }));
    });

    test('should throw during disposal', () async {
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      // ignore: unawaited_futures
      disposable.dispose();
      await new Future(() {});
      expect(disposable.isDisposing, isTrue);
      expect(
          () => disposable.getManagedPeriodicTimer(
              new Duration(seconds: 10), (_) => null),
          throwsStateError);
      completer.complete();
    });

    test('should throw after disposal', () async {
      await disposable.dispose();
      expect(disposable.isDisposed, isTrue);
      expect(
          () => disposable.getManagedPeriodicTimer(
              new Duration(seconds: 10), (_) => null),
          throwsStateError);
    });
  });

  group('onDispose', () {
    test('should be called when dispose() is called', () async {
      expect(disposable.wasOnDisposeCalled, isFalse);
      await disposable.dispose();
      expect(disposable.wasOnDisposeCalled, isTrue);
    });
  });

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
        doesCallbackReturnArgument: false);
  });

  group('manageDisposer', () {
    test(
        'should call callback and accept null return value'
        'when parent is disposed', () async {
      // ignore: deprecated_member_use
      disposable.manageDisposer(expectAsync0(() => null));
      await disposable.dispose();
    });

    test(
        'should call callback and accept Future return value'
        'when parent is disposed', () async {
      // ignore: deprecated_member_use
      disposable.manageDisposer(expectAsync0(() => new Future(() {})));
      await disposable.dispose();
    });

    testManageMethod(
        'manageDisposer',
        // ignore: deprecated_member_use
        (argument) => disposable.manageDisposer(argument),
        () async => null,
        doesCallbackReturnArgument: false);
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
        doesCallbackReturnArgument: false);
  });

  group('manageStreamSubscription', () {
    test('should cancel subscription when parent is disposed', () async {
      var controller = new StreamController();
      controller.onCancel = expectAsync1(([_]) {});
      var subscription =
          controller.stream.listen(expectAsync1((_) {}, count: 0));
      // ignore: deprecated_member_use
      disposable.manageStreamSubscription(subscription);
      await disposable.dispose();
      controller.add(null);
      await subscription.cancel();
      await controller.close();
    });

    var controller = new StreamController();
    testManageMethod(
        'manageStreamSubscription',
        // ignore: deprecated_member_use
        (argument) => disposable.manageStreamSubscription(argument),
        controller.stream.listen((_) {}),
        doesCallbackReturnArgument: false);
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
