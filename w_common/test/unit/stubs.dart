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
  Disposable? injected;
  int numTimesOnDisposeCalled = 0;
  int numTimesOnWillDisposeCalled = 0;
  bool wasOnDisposeCalled = false;
  bool wasOnWillDisposeCalled = false;

  @override
  Future<Null> onDispose() {
    expect(isDisposed, isFalse);
    expect(isOrWillBeDisposed, isTrue);
    numTimesOnDisposeCalled++;
    wasOnDisposeCalled = true;
    var future = Future<Null>(() => null);
    future.then((_) async {
      await Future(() {}); // Give it a chance to update state.
      expect(isDisposed, isTrue);
      expect(isOrWillBeDisposed, isTrue);
    });
    return future;
  }

  @override
  Future<Null> onWillDispose() {
    expect(isDisposed, isFalse);
    expect(isOrWillBeDisposed, isTrue);
    numTimesOnWillDisposeCalled++;
    wasOnWillDisposeCalled = true;
    return Future(() {});
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

typedef OnDataCallback<T> = void Function(T event);

typedef OnDoneCallback = void Function();

class StubStream<T> extends Stream<T> {
  @override
  StreamSubscription<T> listen(OnDataCallback<T>? onData,
      {Function? onError, OnDoneCallback? onDone, bool? cancelOnError}) {
    final sub = MockStreamSubscription<T>();
    when(sub.cancel()).thenReturn(Future<void>.value());
    return sub;
  }
}

class TimerHarness {
  bool _didCancelTimer = true;
  Completer<bool>? _didCancelTimerCompleter;
  bool _didCompleteTimer = false;
  Completer<bool>? _didCompleteTimerCompleter;
  final Completer<Null> _didConcludeCompleter = Completer<Null>();
  final Duration _timerDuration = Duration(milliseconds: 10);

  Duration get duration => _timerDuration;

  Future<bool> get didCancelTimer =>
      _didCancelTimerCompleter?.future ??
      Future.error(StateError(
          'getCallback() must be called before didCancelTimer is valid'));

  Future<bool> get didCompleteTimer =>
      _didCompleteTimerCompleter?.future ??
      Future.error(
          'getCallback() must be called before didCompleteTimer is valid');

  Future<Null> get didConclude => _didConcludeCompleter.future;

  TimerHarnessCallback getCallback() {
    _setupInternalTimer();
    return () {
      _didCompleteTimer = true;
      _didCancelTimer = false;
    };
  }

  TimerHarnessPeriodicCallback getPeriodicCallback({int count = 2}) {
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

  void _setupInternalTimer({int count = 1}) {
    _didCompleteTimerCompleter = Completer<bool>();
    _didCancelTimerCompleter = Completer<bool>();

    var internalDuration = Duration(milliseconds: (count * 10) + 5);
    Timer(internalDuration, () {
      _didCompleteTimerCompleter!.complete(_didCompleteTimer);
      _didCancelTimerCompleter!.complete(_didCancelTimer);
      _didConcludeCompleter.complete();
    });
  }
}
