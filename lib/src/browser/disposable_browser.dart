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
import 'dart:html';

import 'package:meta/meta.dart';
import 'package:w_common/func.dart';

import 'package:w_common/src/common/disposable.dart' as disposable_common;

class _InnerDisposable extends disposable_common.Disposable {
  Func<Future<Null>> onDisposeHandler;
  Func<Future<Null>> onWillDisposeHandler;

  @override
  Future<Null> onDispose() {
    return onDisposeHandler();
  }

  @override
  Future<Null> onWillDispose() {
    return onWillDisposeHandler();
  }
}

/// Allows the creation of managed objects, including helpers for common
/// patterns.
///
/// We recommend consuming this class in one of two ways.
///
///   1. As a base class
///   2. As a concrete proxy
///
/// We do not recommend using this class as a mixin or as an interface.
/// Use as a mixin can cause the `onDispose` method to be shadowed. Use
/// as an interface is just cumbersome.
///
/// If an interface is desired, the `DisposableManager...` interfaces
/// are available.
///
/// In the case below, the class is used as a mixin. This provides both
/// default implementations and flexibility since it does not occupy
/// a spot in the class hierarchy. However, consumers should use caution
/// if they choose to employ this pattern.
///
/// Helper methods, such as [listenToStream] allow certain cleanup to be
/// automated. Managed subscriptions will be automatically canceled when
/// [dispose] is called on the object.
///
///      class MyDisposable extends Object with Disposable {
///        StreamController _controller = new StreamController();
///
///        MyDisposable(Stream someStream) {
///          listenToStream(someStream, (_) => print('some stream'));
///          manageStreamController(_controller);
///        }
///
///        Future<Null> onDispose() {
///          // Other cleanup
///        }
///      }
///
/// The [getManagedDisposer] helper allows you to clean up arbitrary objects
/// on dispose so that you can avoid keeping track of them yourself. To
/// use it, simply provide a callback that returns a [Future] of any
/// kind. For example:
///
///      class MyDisposable extends Object with Disposable {
///        StreamController _controller = new StreamController();
///
///        MyDisposable() {
///          var thing = new ThingThatRequiresCleanup();
///          getManagedDisposer(() {
///            thing.cleanUp();
///            return new Future(() {});
///          });
///        }
///      }
///
/// Cleanup will then be automatically performed when the parent
/// object is disposed. If returning a future is inconvenient or
/// otherwise undesirable, you may also return `null` explicitly.
///
/// Implementing the [onDispose] method is entirely optional and is only
/// necessary if there is cleanup required that is not covered by one of
/// the helpers.
///
/// It is possible to schedule a callback to be called after the object
/// is disposed for purposes of further, external, cleanup or bookkeeping
/// (for example, you might want to remove any objects that are disposed
/// from a cache). To do this, use the [didDispose] future:
///
///      var myDisposable = new MyDisposable();
///      myDisposable.didDispose.then((_) {
///        // External cleanup
///      });
///
/// Below is an example of using the class as a concrete proxy.
///
///      class MyLifecycleThing implements DisposableManager {
///        Disposable _disposable = new Disposable();
///
///        MyLifecycleThing() {
///          _disposable.manageStreamSubscription(someStream.listen(() => null));
///        }
///
///        @override
///        void manageStreamSubscription(StreamSubscription sub) {
///          _disposable.manageStreamSubscription(sub);
///        }
///
///        // ...more methods
///
///        Future<Null> unload() async {
///          await _disposable.dispose();
///        }
///      }
///
/// In this case, we want `MyLifecycleThing` to have its own lifecycle
/// without explicit reference to [Disposable]. To do this, we use
/// composition to include the [Disposable] machinery without changing
/// the public interface of our class or polluting its lifecycle.
class Disposable implements disposable_common.Disposable {
  /// Disables logging enabled by [enableDebugMode].
  static void disableDebugMode() =>
      disposable_common.Disposable.disableDebugMode();

  /// Causes messages to be logged for various lifecycle and management events.
  ///
  /// This should only be used for debugging and profiling as it can result
  /// in a huge number of messages being generated.
  static void enableDebugMode() =>
      disposable_common.Disposable.enableDebugMode();

  final _InnerDisposable _disposable = new _InnerDisposable();

  @override
  Future<Null> get didDispose => _disposable.didDispose;

  @override
  int get disposalTreeSize => _disposable.disposalTreeSize;

  @override
  bool get isDisposed => _disposable.isDisposed;

  @deprecated
  @override
  bool get isDisposedOrDisposing => _disposable.isDisposedOrDisposing;

  @deprecated
  @override
  bool get isDisposing => _disposable.isDisposing;

  @override
  bool get isLeakFlagSet => _disposable.isLeakFlagSet;

  @override
  bool get isOrWillBeDisposed => _disposable.isOrWillBeDisposed;

  @override
  Future<T> awaitBeforeDispose<T>(Future<T> future) =>
      _disposable.awaitBeforeDispose(future);

  @override
  Future<Null> dispose() {
    _disposable
      ..onDisposeHandler = this.onDispose
      ..onWillDisposeHandler = this.onWillDispose;
    return _disposable.dispose().then((_) {
      // We want the description to be the runtime type of this
      // object, not the proxy disposable, so we need to reset
      // the leak flag here.
      flagLeak(runtimeType.toString());
    });
  }

  @override
  void flagLeak([String description]) {
    _disposable.flagLeak(description);
  }

  @override
  Future<T> getManagedDelayedFuture<T>(Duration duration, T callback()) =>
      _disposable.getManagedDelayedFuture(duration, callback);

  @override
  Timer getManagedPeriodicTimer(
          Duration duration, void callback(Timer timer)) =>
      _disposable.getManagedPeriodicTimer(duration, callback);

  @override
  Timer getManagedTimer(Duration duration, void callback()) =>
      _disposable.getManagedTimer(duration, callback);

  @override
  StreamSubscription<T> listenToStream<T>(
          Stream<T> stream, void onData(T event),
          {Function onError, void onDone(), bool cancelOnError}) =>
      _disposable.listenToStream(stream, onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  disposable_common.Disposable manageAndReturnDisposable(
          disposable_common.Disposable disposable) =>
      _disposable.manageAndReturnDisposable(disposable);

  @override
  T manageAndReturnTypedDisposable<T extends disposable_common.Disposable>(
          T disposable) =>
      _disposable.manageAndReturnTypedDisposable(disposable);

  @override
  Completer<T> manageCompleter<T>(Completer<T> completer) =>
      _disposable.manageCompleter(completer);

  @override
  void manageDisposable(disposable_common.Disposable disposable) =>
      _disposable.manageDisposable(disposable);

  @deprecated
  @override
  void manageDisposer(disposable_common.Disposer disposer) =>
      _disposable.manageDisposer(disposer);

  @override
  disposable_common.ManagedDisposer getManagedDisposer(
          disposable_common.Disposer disposer) =>
      _disposable.getManagedDisposer(disposer);

  @override
  void manageStreamController(StreamController controller) =>
      _disposable.manageStreamController(controller);

  @deprecated
  @override
  void manageStreamSubscription(StreamSubscription subscription) =>
      _disposable.manageStreamSubscription(subscription);

  /// Callback to allow arbitrary cleanup on dispose.
  @override
  @protected
  Future<Null> onDispose() async {
    return null;
  }

  /// Callback to allow arbitrary cleanup as soon as disposal is requested (i.e.
  /// [dispose] is called) but prior to disposal actually starting.
  ///
  /// Disposal will _not_ start before the [Future] returned from this method
  /// completes.
  @override
  @protected
  Future<Null> onWillDispose() async {
    return null;
  }

  /// Adds an event listener to the document object and removes the event
  /// listener upon disposal.
  ///
  /// If using this method, you cannot manually use the `removeEventListener`
  /// method on the document singleton to remove the listener. At this point
  /// the only way to remove the listener is to use the [dispose] method.
  void subscribeToDocumentEvent(String event, EventListener callback,
      {bool useCapture, EventTarget documentObject}) {
    if (documentObject == null) {
      documentObject = document;
    }
    _subscribeToEvent(documentObject, event, callback, useCapture);
  }

  /// Adds an event listener to the element object and removes the event
  /// listener upon disposal.
  ///
  /// If using this method, you cannot manually use the `removeEventListener`
  /// method on the element to remove the listener. At this point the only way
  /// to remove the listener is to use the [dispose] method.
  void subscribeToDomElementEvent(
      Element element, String event, EventListener callback,
      {bool useCapture}) {
    _subscribeToEvent(element, event, callback, useCapture);
  }

  /// Adds an event listener to the window object and removes the event
  /// listener upon disposal.
  ///
  /// If using this method, you cannot manually use the `removeEventListener`
  /// method on the window singleton to remove the listener. At this point
  /// the only way to remove the listener is to use the [dispose] method.
  void subscribeToWindowEvent(String event, EventListener callback,
      {bool useCapture, EventTarget windowObject}) {
    if (windowObject == null) {
      windowObject = window;
    }
    _subscribeToEvent(windowObject, event, callback, useCapture);
  }

  void _subscribeToEvent(EventTarget eventTarget, String event,
      EventListener callback, bool useCapture) {
    eventTarget.addEventListener(event, callback, useCapture);
    _disposable.getManagedDisposer(() {
      eventTarget.removeEventListener(event, callback, useCapture);
    });
  }
}
