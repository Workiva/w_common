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
import 'dart:js' as js;

import 'package:meta/meta.dart';
import 'package:w_common/func.dart';

import 'package:w_common/src/common/disposable.dart' as disposable_common;

class _InnerDisposable extends disposable_common.Disposable {
  @override
  String get disposableTypeName => '_InnerDisposable';

  Func<Future<Null>>? onDisposeHandler;
  Func<Future<Null>>? onWillDisposeHandler;

  @override
  Future<Null> onDispose() {
    if (onDisposeHandler != null) {
      return onDisposeHandler!.call();
    }
    return Future(() => null);
  }

  @override
  Future<Null> onWillDispose() {
    if (onWillDisposeHandler != null) {
      return onWillDisposeHandler!.call();
    }
    return Future(() => null);
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
  /// The name of the factory function added to the window that produces
  /// [disposable_common.LeakFlag] objects when called (with a single
  /// argument: a [String] description).
  static const String leakFlagFactoryName = 'leakFlagFactory';

  /// Disables logging enabled by [enableDebugMode].
  static void disableDebugMode() {
    disposable_common.Disposable.disableDebugMode();

    // If there is a leak flag factory function on the window, remove it.
    if (js.context.hasProperty(leakFlagFactoryName)) {
      js.context.deleteProperty(leakFlagFactoryName);
    }
  }

  /// Causes messages to be logged for various lifecycle and management events.
  ///
  /// This should only be used for debugging and profiling as it can result
  /// in a huge number of messages being generated.
  ///
  /// Also attaches a method named `leakFlagFactory` to the window which
  /// consumers can call, with a [String] description as its sole argument, to
  /// generate a [disposable_common.LeakFlag] object. This can be used to
  /// generate a [disposable_common.LeakFlag]
  /// and manually attach it to an object. For example, this may be useful in
  /// code transpiled to JavaScript from another language.
  static void enableDebugMode({bool? disableLogging, bool? disableTelemetry}) {
    disposable_common.Disposable.enableDebugMode(
        disableLogging: disableLogging, disableTelemetry: disableTelemetry);

    // Attach a leak flag factory function to the window to allow consumers to
    // attach leak flags to arbitrary objects.
    if (!js.context.hasProperty(leakFlagFactoryName)) {
      js.context[leakFlagFactoryName] = _leakFlagFactory;
    }
  }

  final _InnerDisposable _disposable = _InnerDisposable();

  @override
  Future<Null> get didDispose => _disposable.didDispose;

  @override
  String get disposableTypeName => disposable_common.defaultDisposableTypeName;

  @override
  int get disposalTreeSize => _disposable.disposalTreeSize;

  @override
  bool get isDisposed => _disposable.isDisposed;

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
      ..onDisposeHandler = onDispose
      ..onWillDisposeHandler = onWillDispose;
    // We want the description to be the runtime type of this
    // object, not the proxy disposable, so we need to set
    // the leak flag here, before we delegate the `dispose`
    // call.
    flagLeak();
    return _disposable.dispose();
  }

  @override
  void flagLeak([String? description]) {
    _disposable.flagLeak(
        description ?? '$disposableTypeName (runtimeType: $runtimeType)');
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
          {Function? onError, void onDone()?, bool? cancelOnError}) =>
      _disposable.listenToStream(stream, onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  T manageAndReturnTypedDisposable<T extends disposable_common.Disposable>(
          T disposable) =>
      _disposable.manageAndReturnTypedDisposable(disposable);

  @override
  Completer<T> manageCompleter<T>(Completer<T> completer) =>
      _disposable.manageCompleter(completer);

  @override
  void manageDisposable(disposable_common.Disposable? disposable) =>
      _disposable.manageDisposable(disposable);

  @override
  disposable_common.ManagedDisposer getManagedDisposer(
          disposable_common.Disposer? disposer) =>
      _disposable.getManagedDisposer(disposer);

  @override
  void manageStreamController(StreamController<dynamic> controller) =>
      _disposable.manageStreamController(controller);

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
      {bool useCapture = false, EventTarget? documentObject}) {
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
      {bool useCapture = false}) {
    _subscribeToEvent(element, event, callback, useCapture);
  }

  /// Adds an event listener to the window object and removes the event
  /// listener upon disposal.
  ///
  /// If using this method, you cannot manually use the `removeEventListener`
  /// method on the window singleton to remove the listener. At this point
  /// the only way to remove the listener is to use the [dispose] method.
  void subscribeToWindowEvent(String event, EventListener callback,
      {bool useCapture = false, EventTarget? windowObject}) {
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
      return Future.value();
    });
  }
}

disposable_common.LeakFlag _leakFlagFactory(String? description) {
  return disposable_common.LeakFlag(description);
}
