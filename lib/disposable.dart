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

import 'package:meta/meta.dart';

// ignore: one_member_abstracts
abstract class _Disposable {
  Future<Null> dispose();
}

class _InternalDisposable implements _Disposable {
  Disposer _disposer;

  _InternalDisposable(this._disposer);

  @override
  Future<Null> dispose() {
    var disposeFuture = _disposer();
    _disposer = null;
    if (disposeFuture == null) {
      return new Future(() => null);
    }
    return disposeFuture.then((_) => null);
  }
}

/// Managers for disposable members.
///
/// This interface allows consumers to exercise more control over how
/// disposal is implemented for their classes.
///
/// When new management methods are to be added, they should be added
/// here first, then implemented in [Disposable].
abstract class DisposableManager {
  Disposable manageDisposable(Disposable disposable);
  void manageDisposer(Disposer disposer);
  StreamController<T> manageStreamController<T>(StreamController<T> controller);
  StreamSubscription<T> manageStreamSubscription<T>(
      StreamSubscription<T> subscription);
  Future<T> waitBeforeDispose<T>(Future<T> future);
}

/// A function that, when called, disposes of one or more objects.
typedef Future<dynamic> Disposer();

/// Allows the creation of managed objects, including helpers for common patterns.
///
/// There are four ways to consume this class: as a mixin, a base class,
/// an interface, and a concrete class used as a proxy. All should work
/// fine but the first is the simplest
/// and most powerful. Using the class as an interface will require
/// significant effort.
///
/// In the case below, the class is used as a mixin. This provides both
/// default implementations and flexibility since it does not occupy
/// a spot in the class hierarchy.
///
/// Helper methods, such as [manageStreamSubscription] allow certain
/// cleanup to be automated. Managed subscriptions will be automatically
/// canceled when [dispose] is called on the object.
///
///      class MyDisposable extends Object with Disposable {
///        StreamController _controller;
///
///        MyDisposable(Stream someStream) {
///          manageStreamSubscription(someStream.listen((_) => print('some stream')));
///          _controller = manageStreamController(new StreamController());
///        }
///
///        Future<Null> onDispose() {
///          // Other cleanup
///        }
///      }
///
/// The [manageDisposer] helper allows you to clean up arbitrary objects
/// on dispose so that you can avoid keeping track of them yourself. To
/// use it, simply provide a callback that returns a [Future] of any
/// kind. For example:
///
///      class MyDisposable extends Object with Disposable {
///        MyDisposable() {
///          var thing = new ThingThatRequiresCleanup();
///          manageDisposer(() {
///            // `thing.cleanUp()` is async here.
///            return thing.cleanUp();
///          });
///        }
///      }
///
/// Cleanup will then be automatically performed when the containing
/// object is disposed. If returning a future is inconvenient or
/// otherwise undesireable, you may also return `null` explicitly.
///
/// Implementing the [onDispose] method is entirely optional and is only
/// necessary if there is cleanup required that is not covered by one of
/// the helpers.
///
/// It is possible to schedule a callback to be called after the object
/// is disposed for purposes of further, external cleanup or bookkeeping
/// (for example, you might want to remove any objects that are disposed
/// from a cache). To do this, use the [didDispose] future:
///
///      var myDisposable = new MyDisposable();
///      myDisposable.didDispose.then((_) {
///        // External cleanup
///      });
///
/// Below is an example of using the class as a concrete proxy. For a
/// more extensive example of this, see the
/// [w_module](https://github.com/Workiva/w_module/) package.
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
///
/// Implementing the [DisposableManager] interface is not required.
class Disposable implements _Disposable, DisposableManager {
  Completer<Null> _didDispose = new Completer<Null>();
  bool _isDisposing = false;
  List<_Disposable> _internalDisposables = [];
  Set<Future<dynamic>> _blockingFutures = new Set<Future<dynamic>>();

  /// A [Future] that will complete when this object has been disposed.
  Future<Null> get didDispose => _didDispose.future;

  /// Whether this object has been disposed.
  bool get isDisposed => _didDispose.isCompleted;

  /// Whether this object has been disposed or is disposing.
  ///
  /// This will become `true` as soon as the [dispose] method is called
  /// and will remain `true` forever. This is intended as a convenience
  /// and `object.isDisposedOrDisposing` will always be the same as
  /// `object.isDisposed || object.isDisposing`.
  bool get isDisposedOrDisposing => isDisposed || isDisposing;

  /// Whether this object is in the process of being disposed.
  ///
  /// This will become `true` as soon as the [dispose] method is called
  /// and will become `false` once the [didDispose] future completes.
  bool get isDisposing => _isDisposing;

  /// Dispose of the object, cleaning up to prevent memory leaks.
  @override
  Future<Null> dispose() async {
    if (isDisposed) {
      return null;
    }
    if (_isDisposing) {
      return didDispose;
    }
    _isDisposing = true;

    await Future.wait(_blockingFutures);
    // We need to filter out nulls because a subscription cancel
    // method is allowed to return a plain old null value.
    await Future.wait(_internalDisposables
        .map((disposable) => disposable.dispose())
        .where((future) => future != null));

    _internalDisposables = null;
    _blockingFutures = null;

    return onDispose().then(_completeDisposeFuture);
  }

  /// Automatically dispose another object when this object is disposed.
  ///
  /// The parameter may not be `null`.
  @mustCallSuper
  @override
  Disposable manageDisposable(Disposable disposable) {
    _throwOnInvalidCall(disposable, 'manageDisposable');
    _internalDisposables.add(disposable);
    return disposable;
  }

  /// Automatically handle arbitrary disposals using a callback.
  ///
  /// The parameter may not be `null`.
  @mustCallSuper
  @override
  void manageDisposer(Disposer disposer) {
    _throwOnInvalidCall(disposer, 'manageDisposer');
    _internalDisposables.add(new _InternalDisposable(disposer));
  }

  /// Automatically cancel a stream controller when this object is disposed.
  ///
  /// The parameter may not be `null`.
  @mustCallSuper
  @override
  StreamController<T> manageStreamController<T>(
      StreamController<T> controller) {
    _throwOnInvalidCall(controller, 'manageStreamController');
    _internalDisposables.add(new _InternalDisposable(() {
      if (!controller.hasListener) {
        controller.stream.listen((_) {});
      }
      return controller.close();
    }));
    return controller;
  }

  /// Automatically cancel a stream subscription when this object is disposed.
  ///
  /// The parameter may not be `null`.
  @mustCallSuper
  @override
  StreamSubscription<T> manageStreamSubscription<T>(
      StreamSubscription<T> subscription) {
    _throwOnInvalidCall(subscription, 'manageStreamSubscription');
    _internalDisposables
        .add(new _InternalDisposable(() => subscription.cancel()));
    return subscription;
  }

  /// Callback to allow arbitrary cleanup on dispose.
  @protected
  Future<Null> onDispose() async {
    return null;
  }

  /// Add [future] to a list of futures that will be awaited before the
  /// object is disposed.
  ///
  /// For example, a long-running network request might result in the use
  /// of a [Disposable] instance when it returns. If we started to dispose
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
  @mustCallSuper
  @override
  Future<T> waitBeforeDispose<T>(Future<T> future) {
    _throwOnInvalidCall(future, 'waitBeforeDispose');
    if (!_blockingFutures.contains(future)) {
      Future removeFuture;
      removeFuture = future.then((_) {
        _blockingFutures.remove(future);
        _blockingFutures.remove(removeFuture);
      });
      _blockingFutures.addAll([future, removeFuture]);
    }
    return future;
  }

  Null _completeDisposeFuture(Null _) {
    _didDispose.complete();
    _isDisposing = false;
    return null;
  }

  void _throwOnInvalidCall(dynamic argument, String name) {
    if (argument == null) {
      throw new ArgumentError.notNull(name);
    }
    if (isDisposing) {
      throw new StateError('$name not allowed, object is disposing');
    }
    if (isDisposed) {
      throw new StateError('$name not allowed, object is already disposed');
    }
  }
}
