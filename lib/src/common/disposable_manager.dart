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

import 'package:w_common/src/common/disposable.dart';

/// Managers for disposable members.
///
/// This interface allows consumers to exercise more control over how
/// disposal is implemented for their classes.
///
/// When new management methods are to be added, they should be added
/// here first, then implemented in [Disposable].
// ignore: deprecated_member_use
abstract class DisposableManager {
  /// Add [future] to a list of futures that will be awaited before the
  /// object is disposed.
  ///
  /// For example, a long-running network request might use
  /// a [Disposable] instance when it returns. If we started to dispose
  /// while the request was pending, upon returning the request's callback
  /// would throw. We can avoid this by waiting on the request's future.
  ///
  ///      class MyDisposable extends Disposable {
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
  /// returned by `callback`, after the given amount of time has elapsed.
  ///
  /// If the object is disposed before the time has elapsed the future
  /// will complete with an [ObjectDisposedException] error.
  Future<T> getManagedDelayedFuture<T>(Duration duration, T callback());

  /// Creates a periodic [Timer] that will be cancelled if it is still
  /// active when this object is disposed.
  Timer getManagedPeriodicTimer(Duration duration, void callback(Timer timer));

  /// Creates a [Timer] instance that will be cancelled if it is still
  /// active when this object is disposed.
  Timer getManagedTimer(Duration duration, void callback());

  /// Returns a [StreamSubscription] which handles events from the stream using
  /// the provided [onData], [onError] and [onDone] handlers.
  ///
  /// Consult documentation for Stream.listen for more info.
  ///
  /// If the returned `StreamSubscription` is cancelled manually (i.e. canceled
  /// before disposal of the parent object) [Disposable] will clean up the
  /// internal reference allowing the subscription to be garbage collected.
  ///
  /// Neither parameter may be `null`.
  StreamSubscription<T> listenToStream<T>(
      Stream<T> stream, void onData(T event),
      {Function onError, void onDone(), bool cancelOnError});

  /// Automatically dispose another object when this object is disposed.
  ///
  /// This method returns the provided [Disposable] in addition to handling
  /// its disposal. One common case is dealing with optional parameters:
  ///
  ///      class MyDisposable extends Disposable {
  ///        // This object also extends disposable
  ///        MyObject _internal;
  ///
  ///        MyDisposable({MyObject optional}) {
  ///          // If optional is injected, we should not manage it.
  ///          // If we create our own internal reference we should manage it.
  ///          _internal = optional ??
  ///              manageAndReturnTypedDisposable(new MyObject());
  ///        }
  ///
  ///        // ...
  ///      }
  ///
  /// This method allows the consumer to build up trees of managed objects
  /// which can be disposed as a group through their root object.
  ///
  /// The parameter may not be `null`.
  T manageDisposable<T extends Disposable>(T disposable);

  /// Ensure that a completer is completed when the object is disposed.
  ///
  /// If the completer has not been completed by the time the object
  /// is disposed, it will be completed with an [ObjectDisposedException]
  /// error.
  Completer<T> manageCompleter<T>(Completer<T> completer);

  /// Automatically handle arbitrary disposals using a callback.
  ///
  /// The provided [Disposer] will be called on disposal of the parent
  /// object (the parent object is `MyDisposable` in the example below).
  /// A [ManagedDisposer] is returned in case the [Disposer] should be
  /// invoked and cleaned up before disposal of the parent object.
  ///
  ///      class MyDisposable extends Disposable {
  ///        void makeRequest() {
  ///          var request = new FancyServerRequest();
  ///
  ///          // This will ensure that cancel is called if MyDisposable is
  ///          // disposed.
  ///          var disposable = getManagedDisposer(request.cancel);
  ///
  ///          // Evict request if it has not completed within a given time
  ///          // frame. All internal references will be cleaned up, even
  ///          // if the MyDisposable instance is disposed prematurely.
  ///          getManagedTimer(new Duration(minutes: 2), disposable.dispose);
  ///
  ///          // ...
  ///        }
  ///      }
  ///
  /// Note: [Disposable] will store a reference to `disposer` until an explicit
  /// `dispose` call to either the parent object, or the returned
  /// [ManagedDisposer]. The reference to `disposer` will prevent the callback
  /// and anything referenced in the callback from being garbage collected until
  /// one of these two things happens.
  ///
  /// These references can be a vector
  /// for memory leaks. For this reason it is recommended to avoid
  /// references in [Disposer] to objects not created by the parent object.
  /// These objects should be managed by their own parent.
  ///
  /// Example BAD use case: `request` should not be referenced in a [Disposer]
  /// because `MyDisposable` did not create it.
  ///
  ///      class MyDisposable extends Disposable {
  ///        void addRequest(Request request) {
  ///          // ...
  ///
  ///          // request comes from an external source, the reference held by
  ///          // this closure may introduce a memory leak.
  ///          getManagedDisposer(request.cancel);
  ///        }
  ///      }
  ///
  /// The parameter may not be `null`.
  ManagedDisposer getManagedDisposer(Disposer disposer);

  /// Automatically close a stream controller when this object is disposed.
  ///
  /// The parameter may not be `null`.
  void manageStreamController(StreamController controller);
}

/// Exception thrown when an operation cannot be completed because the
/// disposable object upon which it depended has been disposed.
///
/// For example, if a managed delayed future hasn't completed by the time
/// the object managing it is disposed, the future will complete with
/// an instance of this exception.
class ObjectDisposedException implements Exception {}
