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

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:w_common/disposable.dart';

import './typedefs.dart';

abstract class StubDisposable implements Disposable {
  Disposable injected;
  int numTimesOnDisposeCalled = 0;
  int numTimesOnWillDisposeCalled = 0;
  bool wasOnDisposeCalled = false;
  bool wasOnWillDisposeCalled = false;

  @override
  Future<Null> onDispose() {
    expect(isDisposed, isFalse);
    // ignore: deprecated_member_use
    expect(isDisposing, isTrue);
    // ignore: deprecated_member_use
    expect(isDisposedOrDisposing, isTrue);
    expect(isOrWillBeDisposed, isTrue);
    numTimesOnDisposeCalled++;
    wasOnDisposeCalled = true;
    var future = new Future<Null>(() => null);
    future.then((_) async {
      await new Future(() {}); // Give it a chance to update state.
      expect(isDisposed, isTrue);
      // ignore: deprecated_member_use
      expect(isDisposing, isFalse);
      // ignore: deprecated_member_use
      expect(isDisposedOrDisposing, isTrue);
      expect(isOrWillBeDisposed, isTrue);
    });
    return future;
  }

  @override
  Future<Null> onWillDispose() {
    expect(isDisposed, isFalse);
    // ignore: deprecated_member_use
    expect(isDisposing, isFalse);
    // ignore: deprecated_member_use
    expect(isDisposedOrDisposing, isFalse);
    expect(isOrWillBeDisposed, isTrue);
    numTimesOnWillDisposeCalled++;
    wasOnWillDisposeCalled = true;
    return new Future(() {});
  }
}

class DisposeCounter extends Disposable {
  @override
  String get disposableTypeName => 'DisposeCounter';

  int disposeCount = 0;
  @override
  Future<Null> dispose() {
    disposeCount++;
    return super.dispose();
  }
}

class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}

typedef void OnDataCallback<T>(T event);

typedef void OnDoneCallback();

class StubStream<T> extends Stream<T> {
  @override
  StreamSubscription<T> listen(OnDataCallback<T> onData,
      {Function onError, OnDoneCallback onDone, bool cancelOnError}) {
    final sub = new MockStreamSubscription<T>();
    when(sub.cancel()).thenReturn(null);
    return sub;
  }
}

class TimerHarness {
  bool _didCancelTimer = true;
  Completer<bool> _didCancelTimerCompleter;
  bool _didCompleteTimer = false;
  Completer<bool> _didCompleteTimerCompleter;
  final Completer<Null> _didConcludeCompleter = new Completer<Null>();
  final Duration _timerDuration = new Duration(milliseconds: 10);

  Duration get duration => _timerDuration;

  Future<bool> get didCancelTimer =>
      _didCancelTimerCompleter?.future ??
      new Future.error(new StateError(
          'getCallback() must be called before didCancelTimer is valid'));

  Future<bool> get didCompleteTimer =>
      _didCompleteTimerCompleter?.future ??
      new Future.error(
          'getCallback() must be called before didCompleteTimer is valid');

  Future<Null> get didConclude => _didConcludeCompleter.future;

  TimerHarnessCallback getCallback() {
    _setupInternalTimer();
    return () {
      _didCompleteTimer = true;
      _didCancelTimer = false;
    };
  }

  TimerHarnessPeriodicCallback getPeriodicCallback({int count: 2}) {
    _setupInternalTimer(count: count);
    var _callCount = 0;
    return (Timer t) {
      _callCount++;
      if (_callCount == count) {
        t.cancel();
        _didCancelTimer = false;
        _didCompleteTimer = true;
      }
    };
  }

  void _setupInternalTimer({int count: 1}) {
    _didCompleteTimerCompleter = new Completer<bool>();
    _didCancelTimerCompleter = new Completer<bool>();

    var internalDuration = new Duration(milliseconds: (count * 10) + 5);
    new Timer(internalDuration, () {
      _didCompleteTimerCompleter.complete(_didCompleteTimer);
      _didCancelTimerCompleter.complete(_didCancelTimer);
      _didConcludeCompleter.complete();
    });
  }
}
