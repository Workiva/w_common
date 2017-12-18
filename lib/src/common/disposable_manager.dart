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
/// Deprecated: Use [DisposableManagerV7] instead.
@deprecated
abstract class DisposableManager {
  /// Automatically dispose another object when this object is disposed.
  ///
  /// The parameter may not be `null`.
  ///
  /// Deprecated: 1.8.0
  /// To be removed: 2.0.0
  ///
  /// Use `manageAndReturnTypedDisposable` instead. One will need to update
  /// to [DisposableManagerV7] or above for this.
  @deprecated
  void manageDisposable(Disposable disposable);

  /// Automatically handle arbitrary disposals using a callback.
  ///
  /// The parameter may not be `null`.
  ///
  /// Deprecated: 1.7.0
  /// To be removed: 2.0.0
  ///
  /// Use `getManagedDisposer` instead. One will need to update to
  /// [DisposableManagerV5] or above for this.
  @deprecated
  void manageDisposer(Disposer disposer);

  /// Automatically cancel a stream controller when this object is disposed.
  ///
  /// The parameter may not be `null`.
  void manageStreamController(StreamController controller);

  /// Automatically cancel a stream subscription when this object is disposed.
  ///
  /// This method should not be used for subscriptions that will be canceled
  /// manually by the consumer because we have no way of knowing when a
  /// subscription is canceled, so we will hold on to the reference until the
  /// parent object is disposed.
  ///
  /// The parameter may not be `null`.
  ///
  /// Deprecated: 1.7.0
  /// To be removed: 2.0.0
  ///
  /// Use `listenToStream` instead. One will need to update to
  /// [DisposableManagerV4] or above for this.
  @deprecated
  void manageStreamSubscription(StreamSubscription subscription);
}

/// Managers for disposable members.
///
/// This interface allows consumers to exercise more control over how
/// disposal is implemented for their classes.
///
/// When new management methods are to be added, they should be added
/// here first, then implemented in [Disposable].
///
/// Deprecated: Use [DisposableManagerV7] instead.
@deprecated
abstract class DisposableManagerV2 implements DisposableManager {
  /// Creates a [Timer] instance that will be cancelled if active
  /// upon disposal.
  Timer getManagedTimer(Duration duration, void callback());

  /// Creates a periodic [Timer] that will be cancelled if active
  /// upon disposal.
  Timer getManagedPeriodicTimer(Duration duration, void callback(Timer timer));
}

/// Managers for disposable members.
///
/// This interface allows consumers to exercise more control over how
/// disposal is implemented for their classes.
///
/// When new management methods are to be added, they should be added
/// here first, then implemented in [Disposable].
///
/// Deprecated: 1.7.0
/// To be removed: 2.0.0
///
/// Use [DisposableManagerV7] instead.
@deprecated
abstract class DisposableManagerV3 implements DisposableManagerV2 {
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

/// Managers for disposable members.
///
/// This interface allows consumers to exercise more control over how
/// disposal is implemented for their classes.
///
/// When new management methods are to be added, they should be added
/// here first, then implemented in [Disposable].
///
/// Deprecated: 1.7.0
/// To be removed: 2.0.0
///
/// Use [DisposableManagerV7] instead.
@deprecated
abstract class DisposableManagerV4 implements DisposableManagerV3 {
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
}

/// Managers for disposable members.
///
/// This interface allows consumers to exercise more control over how
/// disposal is implemented for their classes.
///
/// When new management methods are to be added, they should be added
/// here first, then implemented in [Disposable].
///
/// Deprecated: 1.8.0
/// To be removed: 2.0.0
///
/// Use [DisposableManagerV7] instead.
@deprecated
abstract class DisposableManagerV5 implements DisposableManagerV4 {
  /// Automatically handle arbitrary disposals using a callback.
  ///
  /// The passed [Disposer] will be called on disposal of the parent object (the
  /// parent object is `MyDisposable` in the example below). A [ManagedDisposer]
  /// is returned in case the [Disposer] should be invoked and cleaned up before
  /// disposal of the parent object.
  ///
  ///      class MyDisposable extends Disposable {
  ///        void makeRequest() {
  ///          var request = new Request();
  ///
  ///          // This will ensure that cancel is called if MyDisposable is
  ///          // disposed.
  ///          var disposable = getManagedDisposer(request.cancel);
  ///
  ///          // Evict request if it has not completed within a given time
  ///          // frame. All internal references will be cleaned up.
  ///          getManagedTimer(new Duration(minutes: 2), disposable.dispose);
  ///
  ///          // ...
  ///        }
  ///      }
  ///
  /// Note: [Disposable] will store a reference to [disposer] until an explicit
  /// `dispose` call to either the parent object, or the returned
  /// [ManagedDisposer]. The reference to [disposer] will prevent the callback
  /// and anything referenced in the callback from being garbage collected until
  /// one of these two things happen. These references can be a vector for memory
  /// leaks. For this reason it is recommended to avoid references in [disposer]
  /// to objects not created by the parent object. These objects should be
  /// managed by their parent. At most one would need to manage the parent using
  /// [manageDisposable].
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
}

/// Managers for disposable members.
///
/// This interface allows consumers to exercise more control over how
/// disposal is implemented for their classes.
///
/// When new management methods are to be added, they should be added
/// here first, then implemented in [Disposable].
///
/// Deprecated: 1.10.0
/// To be removed: 2.0.0
///
/// Use [DisposableManagerV7] instead.
@deprecated
abstract class DisposableManagerV6 implements DisposableManagerV5 {
  /// Automatically dispose another object when this object is disposed.
  ///
  /// This method is an extension to `manageDisposable` and returns the
  /// passed in [Disposable] in addition to handling its disposal. The
  /// method should be used when a variable is set and should
  /// conditionally be managed for disposal. The most common case will
  /// be dealing with optional parameters:
  ///
  ///      class MyDisposable extends Disposable {
  ///        // This object also extends disposable
  ///        MyObject _internal;
  ///
  ///        MyDisposable({MyObject optional}) {
  ///          // If optional is injected, we should not manage it.
  ///          // If we create our own internal reference we should manage it.
  ///          _internal = optional ??
  ///              manageAndReturnDisposable(new MyObject());
  ///        }
  ///
  ///        // ...
  ///      }
  ///
  /// The parameter may not be `null`.
  ///
  /// Use `manageAndReturnTypedDisposable` instead. One will need to update
  /// to [DisposableManagerV7] or above for this.
  @deprecated
  Disposable manageAndReturnDisposable(Disposable disposable);
}

/// Managers for disposable members.
///
/// This interface allows consumers to exercise more control over how
/// disposal is implemented for their classes.
///
/// When new management methods are to be added, they should be added
/// here first, then implemented in [Disposable].
// ignore: deprecated_member_use
abstract class DisposableManagerV7 implements DisposableManagerV6 {
  /// Automatically dispose another object when this object is disposed.
  ///
  /// This method is an extension to `manageAndReturnDisposable` and returns the
  /// passed in [Disposable] as its original type in addition to handling its
  /// disposal. The method should be used when a variable is set and should
  /// conditionally be managed for disposal. The most common case will be dealing
  /// with optional parameters:
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
  /// The parameter may not be `null`.
  T manageAndReturnTypedDisposable<T extends Disposable>(T disposable);
}

/// An interface that allows a class to flag potential leaks by marking
/// itself with a particular class when it is disposed.
abstract class LeakFlagger {
  /// Whether the leak flag for this object has been set.
  ///
  /// The flag should only be set in debug mode. If debug mode is
  /// on, the flag should be set at the end of the disposal process.
  /// At this point, the object is expected to be eligible for
  /// garbage collection.
  bool get isLeakFlagSet;

  /// Flag the object as having been disposed in a way that allows easier
  /// profiling.
  ///
  /// The leak flag is only set after disposal, so most instances found
  /// in a heap snapshot will indicate memory leaks.
  ///
  /// Consumers can search a heap snapshot for the `LeakFlag` class to
  /// see all instances of the flag.
  void flagLeak([String description]);
}

/// Exception thrown when an operation cannot be completed because the
/// disposable object upon which it depended has been disposed.
///
/// For example, if a managed delayed future hasn't completed by the time
/// the object managing it is disposed, the future will complete with
/// an instance of this exception.
class ObjectDisposedException implements Exception {}
