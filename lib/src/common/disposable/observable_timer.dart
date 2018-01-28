// Copyright 2017 Workiva Inc.
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

/// A [Timer] implementation that exposes a [Future] that resolves when a
/// non-periodic timer finishes it's callback or when any type of [Timer] is
/// cancelled.
class ObservableTimer implements Timer {
  Completer<Null> _didConclude = new Completer<Null>();
  Timer _timer;

  ObservableTimer(Duration duration, void callback()) {
    _timer = new Timer(duration, () {
      callback();
      _complete();
    });
  }

  ObservableTimer.periodic(Duration duration, void callback(Timer t)) {
    _timer = new Timer.periodic(duration, callback);
  }

  void _complete() {
    if (!_didConclude.isCompleted) {
      _didConclude.complete();
    }
  }

  /// The timer has either been completed or has been cancelled.
  Future<Null> get didConclude => _didConclude.future;

  @override
  void cancel() {
    _timer.cancel();
    _complete();
  }

  @override
  bool get isActive => _timer.isActive;
}
