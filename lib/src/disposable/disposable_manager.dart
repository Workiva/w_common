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

import 'package:w_common/disposable.dart';

/// Managers for disposable members.
///
/// This interface allows consumers to exercise more control over how
/// disposal is implemented for their classes.
///
/// Use DisposableManagerV2 instead.
@deprecated
abstract class DisposableManager {
  /// Automatically dispose another object when this object is disposed.
  ///
  /// The parameter may not be `null`.
  void manageDisposable(Disposable disposable);

  /// Automatically handle arbitrary disposals using a callback.
  ///
  /// The parameter may not be `null`.
  void manageDisposer(Disposer disposer);

  /// Automatically cancel a stream controller when this object is disposed.
  ///
  /// The parameter may not be `null`.
  void manageStreamController(StreamController controller);

  /// Automatically cancel a stream subscription when this object is disposed.
  ///
  /// The parameter may not be `null`.
  void manageStreamSubscription(StreamSubscription subscription);
}

/// Managers for disposable members.
///
/// This interface allows consumers to exercise more control over how
/// disposal is implemented for their classes.
///
/// When new management methods are to be added, they should be added
/// here first, then implemented in [Disposable].
abstract class DisposableManagerV2 implements DisposableManager {
  /// Creates a [Timer] instance that will be cancelled if active upon disposal.
  Timer getManagedTimer(Duration duration, void callback());

  /// Creates a periodic [Timer] that will be cancelled if active upon disposal.
  Timer getManagedPeriodicTimer(Duration duration, void callback(Timer timer));

  @override
  void manageDisposable(Disposable disposable);

  @override
  void manageDisposer(Disposer disposer);

  @override
  void manageStreamController(StreamController controller);

  @override
  void manageStreamSubscription(StreamSubscription subscription);
}
