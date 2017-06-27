// Copyright 2016 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:test/test.dart';

import 'package:w_common/disposable.dart';

import '../stubs.dart';
import './vm_stubs.dart';

void main() {
  group('Disposable', () {
    DisposableThing thing;

    setUp(() {
      thing = new DisposableThing();
    });

    group('disposalTreeSize', () {
      test('should count all managed objects', () {
        var controller = new StreamController();
        var subscription = controller.stream.listen((_) {});
        thing.manageStreamController(controller);
        thing.manageStreamSubscription(subscription);
        thing.manageDisposable(new DisposableThing());
        thing.manageCompleter(new Completer());
        thing.getManagedTimer(new Duration(days: 1), () {});
        thing
            .getManagedDelayedFuture(new Duration(days: 1), () {})
            .catchError((_) {}); // Because we dispose prematurely.
        thing.getManagedPeriodicTimer(new Duration(days: 1), (_) {});
        expect(thing.disposalTreeSize, 8);
        thing.dispose().then(expectAsync1((_) {
          expect(thing.disposalTreeSize, 1);
        }));
      });

      test('should count nested objects', () {
        var nestedThing = new DisposableThing();
        nestedThing.manageDisposable(new DisposableThing());
        thing.manageDisposable(nestedThing);
        expect(thing.disposalTreeSize, 3);
        thing.dispose().then(expectAsync1((_) {
          expect(thing.disposalTreeSize, 1);
        }));
      });
    });

    group('getManagedDelayedFuture', () {
      test('should complete after specified duration', () async {
        var start = new DateTime.now().millisecondsSinceEpoch;
        await thing.getManagedDelayedFuture(
            new Duration(milliseconds: 10), () => null);
        var end = new DateTime.now().millisecondsSinceEpoch;
        expect(end - start, greaterThanOrEqualTo(10));
      });

      test('should complete with an error on premature dispose', () {
        var future =
            thing.getManagedDelayedFuture(new Duration(days: 1), () => null);
        future.catchError((e) {
          expect(e, new isInstanceOf<ObjectDisposedException>());
        });
        thing.dispose();
      });
    });

    group('getManagedTimer', () {
      TimerHarness harness;
      Timer timer;

      setUp(() {
        harness = new TimerHarness();
        timer = thing.getManagedTimer(harness.duration, harness.getCallback());
      });

      test('should cancel timer if disposed before completion', () async {
        expect(timer.isActive, isTrue);
        await thing.dispose();
        expect(await harness.didCancelTimer, isTrue);
        expect(await harness.didCompleteTimer, isFalse);
      });

      test('disposing should have no effect on timer after it has completed',
          () async {
        await harness.didConclude;
        expect(timer.isActive, isFalse);
        await thing.dispose();
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
        timer = thing.getManagedPeriodicTimer(
            harness.duration, harness.getPeriodicCallback());
      });

      test('should cancel timer if disposed before completion', () async {
        expect(timer.isActive, isTrue);
        await thing.dispose();
        expect(await harness.didCancelTimer, isTrue);
        expect(await harness.didCompleteTimer, isFalse);
      });

      test(
          'disposing should have no effect on timer after it has cancelled by'
          ' the consumer', () async {
        await harness.didConclude;
        expect(timer.isActive, isFalse);

        await thing.dispose();
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
        expect(thing.wasOnDisposeCalled, isFalse);
        await thing.dispose();
        expect(thing.wasOnDisposeCalled, isTrue);
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
        thing.manageDisposer(() async {
          expect(() => callback(argument), throwsStateError);
        });
        await thing.dispose();
      });

      test('should throw if object has been disposed', () async {
        await thing.dispose();
        expect(() => callback(argument), throwsStateError);
      });
    }

    group('awaitBeforeDispose', () {
      test('should wait for the future to complete before disposing', () async {
        var completer = new Completer();
        var awaitedFuture = thing.awaitBeforeDispose(completer.future);
        var disposeFuture = thing.dispose().then((_) {
          expect(thing.isDisposing, isFalse,
              reason: 'isDisposing post-complete');
          expect(thing.isDisposed, isTrue, reason: 'isDisposed post-complete');
        });
        await new Future(() {});
        expect(thing.isDisposing, isTrue, reason: 'isDisposing pre-complete');
        expect(thing.isDisposed, isFalse, reason: 'isDisposed pre-complete');
        completer.complete();
        // It's simpler to do this than ignore a bunch of lints.
        await Future.wait([awaitedFuture, disposeFuture]);
      });

      testManageMethod('waitBeforeDispose',
          (argument) => thing.awaitBeforeDispose(argument), new Future(() {}));
    });

    group('manageCompleter', () {
      test('should complete with an error when parent is disposed', () {
        var completer = new Completer<Null>();
        completer.future.catchError(expectAsync1((exception) {
          expect(exception, new isInstanceOf<ObjectDisposedException>());
        }));
        thing.manageCompleter(completer);
        thing.dispose();
      });

      test('should be unmanaged after completion', () {
        var completer = new Completer<Null>();
        thing.manageCompleter(completer);
        completer.complete(null);
        expect(() => thing.dispose(), returnsNormally);
      });

      testManageMethod('manageCompleter',
          (argument) => thing.manageCompleter(argument), new Completer<Null>());
    });

    group('manageDisposable', () {
      test('should dispose child when parent is disposed', () async {
        var childThing = new DisposableThing();
        thing.manageDisposable(childThing);
        expect(childThing.isDisposed, isFalse);
        await thing.dispose();
        expect(childThing.isDisposed, isTrue);
      });

      test('should remove disposable from internal collection if disposed',
          () async {
        var disposable = new DisposeCounter();

        // Manage the disposable child and dispose of it independently
        thing.manageDisposable(disposable);
        await disposable.dispose();
        await thing.dispose();

        expect(disposable.disposeCount, 1);
      });

      testManageMethod('manageDisposable',
          (argument) => thing.manageDisposable(argument), new DisposableThing(),
          doesCallbackReturn: false);
    });

    group('manageDisposer', () {
      test(
          'should call callback and accept null return value'
          'when parent is disposed', () async {
        thing.manageDisposer(expectAsync0(() => null));
        await thing.dispose();
      });

      test(
          'should call callback and accept Future return value'
          'when parent is disposed', () async {
        thing.manageDisposer(expectAsync0(() => new Future(() {})));
        await thing.dispose();
      });

      testManageMethod('manageDisposer',
          (argument) => thing.manageDisposer(argument), () async => null,
          doesCallbackReturn: false);
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
        var subscription =
            controller.stream.listen(expectAsync1(([_]) {}, count: 0));
        subscription.onDone(expectAsync1(([_]) {}));
        thing.manageStreamController(controller);
        expect(controller.isClosed, isFalse);
        await thing.dispose();
        expect(controller.isClosed, isTrue);
        await subscription.cancel();
        await controller.close();
      });

      test(
          'should complete normally for a single-subscription stream, with '
          'a listener, that has been closed when parent is disposed', () async {
        var controller = new StreamController();
        var sub = controller.stream.listen(expectAsync1((_) {}, count: 0));
        thing.manageStreamController(controller);
        await controller.close();
        await thing.dispose();
        await sub.cancel();
      });

      test(
          'should complete normally for a single-subscription stream with a '
          'canceled listener when parent is disposed', () async {
        var controller = new StreamController();
        var sub = controller.stream.listen(expectAsync1((_) {}, count: 0));
        thing.manageStreamController(controller);
        await sub.cancel();
        await thing.dispose();
      });

      test(
          'should close a single-subscription stream that never had a '
          'listener when parent is disposed', () async {
        var controller = new StreamController();
        thing.manageStreamController(controller);
        expect(controller.isClosed, isFalse);
        await thing.dispose();
        expect(controller.isClosed, isTrue);
      });

      testManageMethod(
          'manageStreamController',
          (argument) => thing.manageStreamController(argument),
          new StreamController(),
          doesCallbackReturn: false);
    });

    group('manageStreamSubscription', () {
      test('should cancel subscription when parent is disposed', () async {
        var controller = new StreamController();
        controller.onCancel = expectAsync1(([_]) {});
        var subscription =
            controller.stream.listen(expectAsync1((_) {}, count: 0));
        thing.manageStreamSubscription(subscription);
        await thing.dispose();
        controller.add(null);
        await subscription.cancel();
        await controller.close();
      });

      var controller = new StreamController();
      testManageMethod(
          'manageStreamSubscription',
          (argument) => thing.manageStreamSubscription(argument),
          controller.stream.listen((_) {}),
          doesCallbackReturn: false);
      controller.close();
    });
  });
}
