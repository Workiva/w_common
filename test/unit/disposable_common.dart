import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:w_common/disposable.dart';
import 'package:w_common/func.dart';

import 'stubs.dart';

void testCommonDisposable(Func<StubDisposable> disposableFactory) {
  StubDisposable disposable;

  void testManageMethod<T>(
      String methodName, T callback(T argument), T argument,
      {bool doesCallbackReturnArgument: true}) {
    if (doesCallbackReturnArgument) {
      test('should return the argument', () {
        expect(callback(argument), same(argument));
      });
    }

    test('should throw if called with a null argument', () {
      expect(() => callback(null), throwsArgumentError);
    });

    test(
        'should not throw if called after diposal is requested but before it starts',
        () async {
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      var future = disposable.dispose();
      await new Future(() {});
      expect(disposable.isOrWillBeDisposed, isTrue);
      callback(argument);
      completer.complete();
      await future;
    });

    test('should throw if called while disposal is in progress', () async {
      disposable.getManagedDisposer(() async {
        expect(() => callback(argument), throwsStateError);
      });
      await disposable.dispose();
    });

    test('should throw if called after disposal', () async {
      await disposable.dispose();
      expect(() => callback(argument), throwsStateError);
    });
  }

  void testManageMethod2(
      String methodName,
      callback(dynamic argument, dynamic secondArgument),
      dynamic argument,
      dynamic secondArgument) {
    test('should throw if called with a null first argument', () {
      expect(() => callback(null, secondArgument), throwsArgumentError);
    });

    test('should throw if called with a null second argument', () {
      expect(() => callback(argument, null), throwsArgumentError);
    });

    test(
        'should not throw if called after diposal is requested but before it starts',
        () async {
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      var future = disposable.dispose();
      await new Future(() {});
      expect(disposable.isOrWillBeDisposed, isTrue);
      callback(argument, secondArgument);
      completer.complete();
      await future;
    });

    test('should throw if called while disposal is in progress', () async {
      disposable.getManagedDisposer(() async {
        expect(() => callback(argument, secondArgument), throwsStateError);
      });
      await disposable.dispose();
    });

    test('should throw if called after disposal', () async {
      await disposable.dispose();
      expect(() => callback(argument, secondArgument), throwsStateError);
    });
  }

  setUp(() {
    disposable = disposableFactory();
  });

  group('dispose', () {
    test('should prevent multiple disposals if called more than once',
        () async {
      var completer = new Completer<Null>();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      // ignore: unawaited_futures
      disposable.dispose();
      await new Future(() {});
      expect(disposable.isOrWillBeDisposed, isTrue);
      expect(disposable.isDisposed, isFalse);
      var future = disposable.dispose();
      completer.complete();
      await future;
      expect(disposable.numTimesOnDisposeCalled, equals(1));
      expect(disposable.numTimesOnWillDisposeCalled, equals(1));
    });
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

    test(
        'should not throw if called after diposal is requested but before it starts',
        () async {
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      // ignore: unawaited_futures
      disposable.dispose();
      await new Future(() {});
      expect(disposable.isOrWillBeDisposed, isTrue);
      await disposable.getManagedDelayedFuture(
          new Duration(milliseconds: 10), () => null);
      completer.complete();
    });

    test('should throw if called while disposal is in progress', () async {
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      // ignore: unawaited_futures
      disposable.dispose();
      // ignore: unawaited_futures
      completer.future.then((_) async {
        await new Future(() {});
        // ignore: deprecated_member_use
        expect(disposable.isDisposing, isTrue);
        expect(
            () => disposable.getManagedDelayedFuture(
                new Duration(seconds: 10), () => null),
            throwsStateError);
      });
      completer.complete();
    });

    test('should throw if called after disposal', () async {
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
        (Disposable argument) => disposable.manageAndReturnDisposable(argument),
        disposableFactory());
  });

  group('manageAndReturnTypedDisposable', () {
    void injectDisposable({Disposable injected}) {
      disposable.injected = injected ??
          disposable.manageAndReturnTypedDisposable(disposableFactory());
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
        'manageAndReturnTypedDisposable',
        (StubDisposable argument) =>
            disposable.manageAndReturnTypedDisposable(argument),
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

    test('should un-manage Disposer when disposed before parent', () async {
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
        'should throw if stream completes with an error and there is no '
        'onError handler', () {
      // ignore: close_sinks
      var controller = new StreamController<Null>();
      controller.addError(new Exception('intentional'));
      runZoned(() {
        disposable.listenToStream(controller.stream, (_) {});
      }, onError: expectAsync2((error, _) {
        expect(error, new isInstanceOf<Exception>());
        expect(error.toString(), 'Exception: intentional');
      }));
    });

    test(
        'should call error handler if stream receives an error '
        'and there was an onError handler set by listenToStream', () {
      // ignore: close_sinks
      var controller = new StreamController<Null>();
      // ignore: cancel_subscriptions
      disposable.listenToStream(controller.stream, (_) {},
          onError: expectAsync2((error, _) {
        expect(error, new isInstanceOf<Exception>());
        expect(error.toString(), 'Exception: intentional');
      }));
      controller.addError(new Exception('intentional'));
    });

    test(
        'should call error handler if stream receives an error '
        'and there was an onError handler set on the subscription', () {
      // ignore: close_sinks
      var controller = new StreamController<Null>();
      // ignore: cancel_subscriptions
      var subscription = disposable.listenToStream(controller.stream, (_) {});
      subscription.onError(expectAsync2((error, _) {
        expect(error, new isInstanceOf<Exception>());
        expect(error.toString(), 'Exception: intentional');
      }));
      controller.addError(new Exception('intentional'));
    });

    test('should accept a unary onError callback', () {
      // ignore: close_sinks
      var controller = new StreamController<Null>();
      disposable.listenToStream(controller.stream, (_) {},
          onError: expectAsync1((error) {
        expect(error, new isInstanceOf<Exception>());
        expect(error.toString(), 'Exception: intentional');
      }));
      controller.addError(new Exception('intentional'));
    });

    test('should accept a binary onError callback', () {
      // ignore: close_sinks
      var controller = new StreamController<Null>();
      disposable.listenToStream(controller.stream, (_) {},
          onError: expectAsync2((error, stackTrace) {
        expect(error, new isInstanceOf<Exception>());
        expect(error.toString(), 'Exception: intentional');
        expect(stackTrace, isNotNull);
        expect(stackTrace, new isInstanceOf<StackTrace>());
      }));
      controller.addError(new Exception('intentional'));
    });

    test(
        'should call onDone callback when controller is closed '
        'and there was an onDone callback set by listenToStream', () {
      // ignore: close_sinks
      var controller = new StreamController<Null>();
      // ignore: cancel_subscriptions
      disposable.listenToStream(controller.stream, (_) {},
          onDone: expectAsync0(() {}));
      controller.close();
    });

    test(
        'should call onDone callback when controller is closed '
        'and there was an onDone callback set on the subscription', () {
      // ignore: close_sinks
      var controller = new StreamController<Null>();
      // ignore: cancel_subscriptions
      var subscription = disposable.listenToStream(controller.stream, (_) {});
      subscription.onDone(expectAsync0(() {}));
      controller.close();
    });

    test('should un-manage subscription when controller is closed', () async {
      var previousTreeSize = disposable.disposalTreeSize;

      // ignore: close_sinks
      var controller = new StreamController<Null>();
      // ignore: cancel_subscriptions
      disposable.listenToStream(controller.stream, (_) {});
      expect(disposable.disposalTreeSize, equals(previousTreeSize + 1));

      await controller.close();
      await new Future(() {});

      expect(disposable.isDisposed, isFalse);
      expect(disposable.disposalTreeSize, equals(previousTreeSize));
    });

    test(
        'should un-manage subscription when the stream emits an error '
        'when cancelOnError is true', () async {
      var previousTreeSize = disposable.disposalTreeSize;

      // ignore: close_sinks
      var controller = new StreamController<Null>();
      // ignore: cancel_subscriptions
      disposable.listenToStream(controller.stream, (_) {},
          cancelOnError: true, onError: (_, [__]) {});
      expect(disposable.disposalTreeSize, equals(previousTreeSize + 1));

      controller.addError(new Exception('intentional'));
      await new Future(() {});

      expect(disposable.isDisposed, isFalse);
      expect(disposable.disposalTreeSize, equals(previousTreeSize));
    });

    test(
        'should not un-manage subscription when the stream emits an error '
        'when cancelOnError is false', () async {
      var previousTreeSize = disposable.disposalTreeSize;

      // ignore: close_sinks
      var controller = new StreamController<Null>();
      // ignore: cancel_subscriptions
      disposable.listenToStream(controller.stream, (_) {},
          cancelOnError: false, onError: (_, [__]) {});
      expect(disposable.disposalTreeSize, equals(previousTreeSize + 1));

      controller.addError(new Exception('intentional'));
      await new Future(() {});

      expect(disposable.isDisposed, isFalse);
      expect(disposable.disposalTreeSize, equals(previousTreeSize + 1));
    });

    group('asFuture should return a future', () {
      test('that completes when the stream closes', () async {
        // ignore: close_sinks
        var controller = new StreamController<Null>();
        // ignore: cancel_subscriptions
        var subscription = disposable.listenToStream(controller.stream, (_) {});
        var future = subscription.asFuture('intentional');
        await controller.close();
        var value = await future;
        expect(value, 'intentional');
      });

      test('that completes when the stream emits an error', () {
        // ignore: close_sinks
        var controller = new StreamController<Null>();
        // ignore: cancel_subscriptions
        var subscription = disposable.listenToStream(controller.stream, (_) {});
        subscription
            .asFuture('intentional')
            .then(expectAsync1((_) {}, count: 0))
            .catchError(expectAsync2((error, [_]) {
          expect(error.toString(), 'Exception: intentional');
        }));
        controller.addError(new Exception('intentional'));
      });

      test(
          'that un-manages the subscription on completion '
          'with an error even when cancelOnError is false', () async {
        var previousTreeSize = disposable.disposalTreeSize;

        // ignore: close_sinks
        var controller = new StreamController<Null>();
        // ignore: cancel_subscriptions
        var subscription = disposable.listenToStream(controller.stream, (_) {},
            cancelOnError: false, onError: (_, [__]) {});
        var future =
            subscription.asFuture('intentional').catchError((_, [__]) {});
        expect(disposable.disposalTreeSize, equals(previousTreeSize + 1));

        controller.addError(new Exception('intentional'));
        await new Future(() {});
        await future;

        expect(disposable.isDisposed, isFalse);
        expect(disposable.disposalTreeSize, equals(previousTreeSize));
      });
    });

    test(
        'should return ManagedStreamSubscription that returns null when an '
        'unwrapped StreamSubscription would have', () async {
      final stream = new StubStream<Object>();
      final unwrappedSubscription = stream.listen((_) {}, cancelOnError: false);
      final managedSubscription = disposable.listenToStream(stream, (_) {});

      expect(unwrappedSubscription.cancel(), isNull);
      expect(managedSubscription.cancel(), isNull);
    });

    test(
        'should un-manage when stream subscription is canceled before '
        'disposal when canceling a stream subscription returns null', () async {
      final previousTreeSize = disposable.disposalTreeSize;
      final stream = new StubStream<Object>();
      final subscription = disposable.listenToStream(stream, (_) {});

      expect(disposable.disposalTreeSize, equals(previousTreeSize + 1));

      await subscription.cancel();
      await new Future<Null>(() {});

      expect(disposable.isDisposed, isFalse);
      expect(disposable.disposalTreeSize, equals(previousTreeSize));
    });

    test(
        'should un-manage when stream subscription is canceled before '
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

    test(
        'should not throw if called after diposal is requested but before it starts',
        () async {
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      // ignore: unawaited_futures
      disposable.dispose();
      await new Future(() {});
      expect(disposable.isOrWillBeDisposed, isTrue);
      disposable.getManagedTimer(new Duration(milliseconds: 10), () => null);
      completer.complete();
    });

    test('should throw if called while disposal is in progress', () async {
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      // ignore: unawaited_futures
      disposable.dispose();
      // ignore: unawaited_futures
      completer.future.then((_) async {
        await new Future(() {});
        // ignore: deprecated_member_use
        expect(disposable.isDisposing, isTrue);
        expect(
            () => disposable.getManagedTimer(
                new Duration(seconds: 10), () => null),
            throwsStateError);
      });
      completer.complete();
    });

    test('should throw if called after disposal', () async {
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

    test(
        'should not throw if called after diposal is requested but before it starts',
        () async {
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      // ignore: unawaited_futures
      disposable.dispose();
      await new Future(() {});
      expect(disposable.isOrWillBeDisposed, isTrue);
      disposable.getManagedPeriodicTimer(
          new Duration(milliseconds: 10), (_) => null);
      completer.complete();
    });

    test('should throw if called while disposal is in progress', () async {
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      // ignore: unawaited_futures
      disposable.dispose();
      // ignore: unawaited_futures
      completer.future.then((_) async {
        await new Future(() {});
        expect(disposable.isOrWillBeDisposed, isTrue);
        expect(
            () => disposable.getManagedPeriodicTimer(
                new Duration(seconds: 10), (_) => null),
            throwsStateError);
      });
      completer.complete();
    });

    test('should throw if called after disposal', () async {
      await disposable.dispose();
      expect(disposable.isDisposed, isTrue);
      expect(
          () => disposable.getManagedPeriodicTimer(
              new Duration(seconds: 10), (_) => null),
          throwsStateError);
    });
  });

  group('onDispose', () {
    test(
        'should be called when dispose() is called, but not until disposal starts',
        () async {
      expect(disposable.wasOnDisposeCalled, isFalse);
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      var future = disposable.dispose();
      await new Future(() {});
      expect(disposable.wasOnDisposeCalled, isFalse);
      completer.complete();
      await future;
      expect(disposable.wasOnDisposeCalled, isTrue);
    });
  });

  group('onWillDispose', () {
    test('should be called immediately when dispose() is called', () async {
      expect(disposable.wasOnWillDisposeCalled, isFalse);
      var completer = new Completer();
      // ignore: unawaited_futures
      disposable.awaitBeforeDispose(completer.future);
      var future = disposable.dispose();
      await new Future(() {});
      expect(disposable.wasOnWillDisposeCalled, isTrue);
      completer.complete();
      await future;
      expect(disposable.wasOnWillDisposeCalled, isTrue);
    });
  });

  group('awaitBeforeDispose', () {
    test('should wait for the future to complete before disposing', () async {
      var completer = new Completer();
      var awaitedFuture = disposable.awaitBeforeDispose(completer.future);
      var disposeFuture = disposable.dispose().then((_) {
        // ignore: deprecated_member_Use
        expect(disposable.isDisposing, isFalse,
            reason: 'isDisposing post-complete');
        expect(disposable.isDisposed, isTrue,
            reason: 'isDisposed post-complete');
      });
      await new Future(() {});
      expect(disposable.isOrWillBeDisposed, isTrue,
          reason: 'isDisposing pre-complete');
      expect(disposable.isDisposed, isFalse, reason: 'isDisposed pre-complete');
      completer.complete();
      // It's simpler to do this than ignore a bunch of lints.
      await Future.wait([awaitedFuture, disposeFuture]);
    });

    test('should allow additional futures to be registered while waiting',
        () async {
      var completer = new Completer();
      var awaitedFuture = disposable.awaitBeforeDispose(completer.future);
      var disposeFuture = disposable.dispose();
      await new Future(() {});
      expect(disposable.isOrWillBeDisposed, isTrue,
          reason: 'isDisposing pre-complete');
      expect(disposable.isDisposed, isFalse, reason: 'isDisposed pre-complete');
      var completer2 = new Completer();
      var awaitedFuture2 = disposable.awaitBeforeDispose(completer2.future);
      completer.complete();
      await new Future(() {});
      expect(disposable.isOrWillBeDisposed, isTrue,
          reason: 'isDisposing pre-complete (future #2)');
      expect(disposable.isDisposed, isFalse,
          reason: 'isDisposed pre-complete (future #2)');
      completer2.complete();
      // It's simpler to do this than ignore a bunch of lints.
      await Future.wait([awaitedFuture, awaitedFuture2, disposeFuture]);
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

    var completer = new Completer<Null>()..complete();
    testManageMethod('manageCompleter',
        (argument) => disposable.manageCompleter(argument), completer);
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

    testManageMethod('manageDisposable', (argument) {
      disposable.manageDisposable(argument);
      return argument;
    }, disposableFactory(), doesCallbackReturnArgument: false);
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

    testManageMethod('manageDisposer', (argument) {
      // ignore: deprecated_member_use
      disposable.manageDisposer(argument);
      return argument;
    }, () async => null, doesCallbackReturnArgument: false);
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

    testManageMethod('manageStreamController', (argument) {
      disposable.manageStreamController(argument);
      return argument;
    }, new StreamController(), doesCallbackReturnArgument: false);
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
    testManageMethod('manageStreamSubscription', (argument) {
      // ignore: deprecated_member_use
      disposable.manageStreamSubscription(argument);
      return argument;
    }, controller.stream.listen((_) {}), doesCallbackReturnArgument: false);
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
