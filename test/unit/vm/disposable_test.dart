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

import '../stubs.dart';

void main() {
  group('Disposable', () {
    DisposableThing thing;

    setUp(() {
      thing = new DisposableThing();
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

    group('manageDisposable', () {
      test('should dispose child when parent is disposed', () async {
        var childThing = new DisposableThing();
        thing.testManageDisposable(childThing);
        expect(childThing.isDisposed, isFalse);
        await thing.dispose();
        expect(childThing.isDisposed, isTrue);
      });

      test('should throw if called with a null argument', () {
        expect(() => thing.testManageDisposable(null), throwsArgumentError);
      });
    });

    group('manageDisposer', () {
      test(
          'should call callback and accept null return value'
          'when parent is disposed', () async {
        thing.testManageDisposer(expectAsync0(() => null));
        await thing.dispose();
      });

      test(
          'should call callback and accept Future return value'
          'when parent is disposed', () async {
        thing.testManageDisposer(expectAsync0(() => new Future(() {})));
        await thing.dispose();
      });

      test('should throw if called with a null argument', () {
        expect(() => thing.testManageDisposer(null), throwsArgumentError);
      });
    });

    group('manageStreamController', () {
      test('should close a broadcast stream when parent is disposed', () async {
        var controller = new StreamController.broadcast();
        thing.testManageStreamController(controller);
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
        thing.testManageStreamController(controller);
        expect(controller.isClosed, isFalse);
        await thing.dispose();
        expect(controller.isClosed, isTrue);
        await subscription.cancel();
        await controller.close();
      });

      test(
          'should close a single-subscription stream with no listener'
          'when parent is disposed', () async {
        var controller = new StreamController();
        thing.testManageStreamController(controller);
        expect(controller.isClosed, isFalse);
        await thing.dispose();
        expect(controller.isClosed, isTrue);
      });

      test('should throw if called with a null argument', () {
        expect(
            () => thing.testManageStreamController(null), throwsArgumentError);
      });
    });

    group('manageStreamSubscription', () {
      test('should cancel subscription when parent is disposed', () async {
        var controller = new StreamController();
        controller.onCancel = expectAsync1(([_]) {});
        var subscription =
            controller.stream.listen(expectAsync1((_) {}, count: 0));
        thing.testManageStreamSubscription(subscription);
        await thing.dispose();
        controller.add(null);
        await subscription.cancel();
        await controller.close();
      });

      test('should throw if called with a null argument', () {
        expect(() => thing.testManageStreamSubscription(null),
            throwsArgumentError);
      });
    });
  });
}
