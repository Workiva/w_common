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

import '../typedefs.dart';

class DisposableThing extends Object with Disposable {
  bool wasOnDisposeCalled = false;

  void testManageDisposable(Disposable thing) {
    manageDisposable(thing);
  }

  void testManageDisposer(Disposer disposer) {
    manageDisposer(disposer);
  }

  void testManageStreamController(StreamController controller) {
    manageStreamController(controller);
  }

  void testManageStreamSubscription(StreamSubscription subscription) {
    manageStreamSubscription(subscription);
  }

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
        thing.testManageDisposer(expectAsync(() => null, count: 1) as Disposer);
        await thing.dispose();
      });

      test(
          'should call callback and accept Future return value'
          'when parent is disposed', () async {
        thing.testManageDisposer(
            expectAsync(() => new Future(() {}), count: 1) as Disposer);
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
        var subscription = controller.stream
            .listen(expectAsync(([_]) {}, count: 0) as StreamListener);
        subscription.onDone(expectAsync(([_]) {}, count: 1) as StreamListener);
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
        controller.onCancel = expectAsync(([_]) {}, count: 1);
        var subscription = controller.stream
            .listen(expectAsync((_) {}, count: 0) as StreamListener);
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
