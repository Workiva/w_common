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
@deprecated
abstract class DisposableManagerV2 implements DisposableManager {
  /// Creates a [Timer] instance that will be cancelled if active
  /// upon disposal.
  Timer getManagedTimer(Duration duration, void callback());

  /// Creates a periodic [Timer] that will be cancelled if active
  /// upon disposal.
  Timer getManagedPeriodicTimer(Duration duration, void callback(Timer timer));
}

abstract class DisposableManagerV3 implements DisposableManagerV2 {
  /// Add [future] to a list of futures that will be awaited before the
  /// object is disposed.
  ///
  /// For example, a long-running network request might use
  /// a [Disposable] instance when it returns. If we started to dispose
  /// while the request was pending, upon returning the request's callback
  /// would throw. We can avoid this by waiting on the request's future.
  ///
  ///      class MyApi extends Object with Disposable {
  ///        MyHelper helper;
  ///
  ///        MyApi() {
  ///          helper = manageDisposable(new MyHelper());
  ///        }
  ///
  ///        Future makeRequest(String message) {
  ///          return waitBeforeDispose(
  ///              helper.sendRequest(onSuccess: (response) {
  ///            // If the `MyApi` instance was disposed while the request
  ///            // was pending, this would normally result in an exception
  ///            // being thrown. But instead, the dispose process will wait
  ///            // for the request to complete before disposing of `helper'.
  ///            helper.handleResponse(message, response);
  ///          }))
  ///        }
  ///      }
  Future<T> awaitBeforeDispose<T>(Future<T> future);

  /// Creates a [Future] that will complete, with the value
  /// returned by [callback], after the given amount of time has elapsed.
  ///
  /// If the object is disposed before the time has elapsed the future
  /// will complete with an [ObjectDisposedException] error.
  Future<T> getManagedDelayedFuture<T>(Duration duration, T callback());

  /// Ensure that a completer is completed when the object is disposed.
  ///
  /// If the completer has not been completed by the time the object
  /// is disposed, it will be completed with an [ObjectDisposedException]
  /// error.
  Completer<T> manageCompleter<T>(Completer<T> completer);
}

/// Exception thrown when an operation cannot be completed because the
/// disposable object upon which it depended has been disposed.
///
/// For example, if a managed delayed future hasn't completed by the time
/// the object managing it is disposed, the future will complete with
/// an instance of this exception.
class ObjectDisposedException implements Exception {}
