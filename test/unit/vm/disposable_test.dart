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

class DisposableThing extends Object with Disposable {
  bool wasOnDisposeCalled = false;

  @override
  Future<Null> onDispose() {
    expect(isDisposed, isFalse);
    expect(isDisposing, isTrue);
    expect(isDisposedOrDisposing, isTrue);
    wasOnDisposeCalled = true;
    var future = new Future<Null>(() => null);
    future.then((_) async {
      await new Future(() {}); // Give it a chance to update state.
      expect(isDisposed, isTrue);
      expect(isDisposing, isFalse);
      expect(isDisposedOrDisposing, isTrue);
    });
    return future;
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

    void testManageMethod(String methodName, callback(argument), argument,
        {doesCallbackReturn: true}) {
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

    group('manageDisposable', () {
      test('should dispose child when parent is disposed', () async {
        var childThing = new DisposableThing();
        thing.manageDisposable(childThing);
        expect(childThing.isDisposed, isFalse);
        await thing.dispose();
        expect(childThing.isDisposed, isTrue);
      });

      testManageMethod(
          'manageDisposable',
          (argument) => thing.manageDisposable(argument),
          new DisposableThing());
    });

    group('manageDisposer', () {
      test(
          'should call callback and accept null return value'
          'when parent is disposed', () async {
        thing.manageDisposer(expectAsync0(() => null, count: 1) as Disposer);
        await thing.dispose();
      });

      test(
          'should call callback and accept Future return value'
          'when parent is disposed', () async {
        thing.manageDisposer(expectAsync0(() => new Future(() {}), count: 1));
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
        subscription.onDone(expectAsync1(([_]) {}, count: 1));
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

      testManageMethod(
          'manageStreamController',
          (argument) => thing.manageStreamController(argument),
          new StreamController());
    });

    group('manageStreamSubscription', () {
      test('should cancel subscription when parent is disposed', () async {
        var controller = new StreamController();
        controller.onCancel = expectAsync1(([_]) {}, count: 1);
        var subscription =
            controller.stream.listen(expectAsync1((_) {}, count: 0));
        thing.manageStreamSubscription(subscription);
        await thing.dispose();
        controller.add(null);
        await controller.close();
      });

      var controller = new StreamController();
      testManageMethod(
          'manageStreamSubscription',
          (argument) => thing.manageStreamSubscription(argument),
          controller.stream.listen((_) {}));
      controller.close();
    });

    group('waitBeforeDispose', () {
      test('should wait for the future to complete before disposing', () async {
        var completer = new Completer();
        thing.waitBeforeDispose(completer.future);
        thing.dispose().then((_) {
          expect(thing.isDisposing, isFalse,
              reason: 'isDisposing post-complete');
          expect(thing.isDisposed, isTrue, reason: 'isDisposed post-complete');
        });
        await new Future(() {});
        expect(thing.isDisposing, isTrue, reason: 'isDisposing pre-complete');
        expect(thing.isDisposed, isFalse, reason: 'isDisposed pre-complete');
        completer.complete();
      });

      testManageMethod('waitBeforeDispose',
          (argument) => thing.waitBeforeDispose(argument), new Future(() {}));
    });
  });
}
