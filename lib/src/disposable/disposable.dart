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
import 'dart:collection';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'package:uuid/uuid.dart';
import 'package:w_common/src/disposable/disposable_manager.dart';

// ignore: one_member_abstracts
abstract class _Disposable {
  Future<Null> dispose();
}

class _InternalDisposable implements _Disposable {
  Disposer _disposer;

  _InternalDisposable(this._disposer);

  @override
  Future<Null> dispose() {
    var disposeFuture = _disposer != null ? _disposer() : null;
    _disposer = null;
    if (disposeFuture == null) {
      return new Future.value();
    }
    return disposeFuture.then((_) => null);
  }
}

/// A [Timer] implementation that exposes a [Future] that resolves when a
/// non-periodic timer finishes it's callback or when any type of [Timer] is
/// cancelled.
class _ObservableTimer implements Timer {
  Completer<Null> _didConclude = new Completer<Null>();
  Timer _timer;

  _ObservableTimer(Duration duration, void callback()) {
    _timer = new Timer(duration, () {
      callback();
      _didConclude.complete();
    });
  }

  _ObservableTimer.periodic(Duration duration, void callback(Timer t)) {
    _timer = new Timer.periodic(duration, callback);
  }

  /// The timer has either been completed or has been cancelled.
  Future<Null> get didConclude => _didConclude.future;

  @override
  void cancel() {
    _timer.cancel();
    if (!_didConclude.isCompleted) {
      _didConclude.complete();
    }
  }

  @override
  bool get isActive => _timer.isActive;
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
///        StreamController _controller = new StreamController();
///
///        MyDisposable(Stream someStream) {
///          manageStreamSubscription(someStream.listen((_) => print('some stream')));
///          manageStreamController(_controller);
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
///        StreamController _controller = new StreamController();
///
///        MyDisposable() {
///          var thing = new ThingThatRequiresCleanup();
///          manageDisposer(() {
///            thing.cleanUp();
///            return new Future(() {});
///          });
///        }
///      }
///
/// Cleanup will then be automatically performed when the containing
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
class Disposable implements _Disposable, DisposableManagerV3 {
  static bool _debugMode = false;
  static Logger _logger;
  static Uuid _uuid = new Uuid();

  static void disableDebugMode() {
    _debugMode = false;
    _logger.clearListeners();
    _logger = null;
  }

  static void enableDebugMode() {
    _debugMode = true;
    _logger = new Logger('Disposable');
  }

  final Set<Future> _awaitableFutures = new HashSet<Future>();
  Completer<Null> _didDispose = new Completer<Null>();
  String _guid = _uuid.v4();
  final Set<_Disposable> _internalDisposables = new HashSet<_Disposable>();
  bool _isDisposing = false;

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

  @mustCallSuper
  @override
  Future<T> awaitBeforeDispose<T>(Future<T> future) {
    _throwOnInvalidCall('awaitBeforeDispose', 'future', future);
    _awaitableFutures.add(future);
    future.then((_) {
      if (!isDisposedOrDisposing) {
        _awaitableFutures.remove(future);
      }
    }).catchError((_) {
      if (!isDisposedOrDisposing) {
        _awaitableFutures.remove(future);
      }
    });
    return future;
  }

  /// Dispose of the object, cleaning up to prevent memory leaks.
  @override
  Future<Null> dispose() async {
    _logDispose();

    if (isDisposed) {
      return null;
    }
    if (_isDisposing) {
      return didDispose;
    }
    _isDisposing = true;

    await Future.wait(_awaitableFutures);
    _awaitableFutures.clear();

    for (var disposable in _internalDisposables) {
      await disposable.dispose();
    }
    _internalDisposables.clear();

    await onDispose();

    _completeDisposeFuture();
  }

  @mustCallSuper
  @override
  Future<T> getManagedDelayedFuture<T>(Duration duration, T callback()) {
    var completer = new Completer<T>();
    var timer =
        new _ObservableTimer(duration, () => completer.complete(callback()));
    var disposable = new _InternalDisposable(() async {
      timer.cancel();
      completer.completeError(new ObjectDisposedException());
    });
    _internalDisposables.add(disposable);
    timer.didConclude.then((Null _) {
      if (!isDisposedOrDisposing) {
        _internalDisposables.remove(disposable);
      }
    });
    return completer.future;
  }

  @mustCallSuper
  @override
  Timer getManagedTimer(Duration duration, void callback()) {
    var timer = new _ObservableTimer(duration, callback);
    _addObservableTimerDisposable(timer);
    return timer;
  }

  @mustCallSuper
  @override
  Timer getManagedPeriodicTimer(Duration duration, void callback(Timer timer)) {
    var timer = new _ObservableTimer.periodic(duration, callback);
    _addObservableTimerDisposable(timer);
    return timer;
  }

  @mustCallSuper
  @override
  Completer<T> manageCompleter<T>(Completer<T> completer) {
    _throwOnInvalidCall('manageCompleter', 'completer', completer);
    _logManageMessage('completer', completer);

    var disposable = new _InternalDisposable(() async {
      if (!completer.isCompleted) {
        completer.completeError(new ObjectDisposedException());
      }
    });
    _internalDisposables.add(disposable);

    completer.future.catchError((e) {
      if (!isDisposedOrDisposing) {
        _logUnmanageMessage('completer', completer);
        _internalDisposables.remove(disposable);
      }
    }).then((_) {
      if (!isDisposedOrDisposing) {
        _logUnmanageMessage('completer', completer);
        _internalDisposables.remove(disposable);
      }
    });

    return completer;
  }

  @mustCallSuper
  @override
  void manageDisposable(Disposable disposable) {
    _throwOnInvalidCall('manageDisposable', 'disposable', disposable);
    _logManageMessage('disposable', disposable);

    _internalDisposables.add(disposable);
    disposable.didDispose.then((_) {
      if (!isDisposedOrDisposing) {
        _logUnmanageMessage('disposable', disposable);
        _internalDisposables.remove(disposable);
      }
    });
  }

  @mustCallSuper
  @override
  void manageDisposer(Disposer disposer) {
    _throwOnInvalidCall('manageDisposer', 'disposer', disposer);
    _logManageMessage('disposer', disposer);

    _internalDisposables.add(new _InternalDisposable(disposer));
  }

  @mustCallSuper
  @override
  void manageStreamController(StreamController controller) {
    _throwOnInvalidCall('manageStreamController', 'controller', controller);
    // If a single-subscription stream has a subscription and that
    // subscription is subsequently canceled, the `done` future will
    // complete, but there is no other way for us to tell that this
    // is what has happened. If we then listen to the stream (since
    // closing a stream that was never listened to never completes) we'll
    // get an exception. This workaround allows us to "know" when a
    // subscription has been canceled so we don't bother trying to
    // listen to the stream before closing it.
    _logManageMessage('stream controller', controller);

    bool isDone = false;

    var disposable = new _InternalDisposable(() {
      if (!controller.hasListener && !controller.isClosed && !isDone) {
        controller.stream.listen((_) {});
      }
      return controller.close();
    });

    controller.done.then((_) {
      isDone = true;
      if (!isDisposedOrDisposing) {
        _logUnmanageMessage('stream controller', controller);
        _internalDisposables.remove(disposable);
      }
      disposable.dispose();
    });

    _internalDisposables.add(disposable);
  }

  @mustCallSuper
  @override
  void manageStreamSubscription(StreamSubscription subscription) {
    _throwOnInvalidCall(
        'manageStreamSubscription', 'subscription', subscription);
    _logManageMessage('stream subscription', subscription);

    _internalDisposables
        .add(new _InternalDisposable(() => subscription.cancel()));
  }

  /// Callback to allow arbitrary cleanup on dispose.
  @protected
  Future<Null> onDispose() async {
    return null;
  }

  void _addObservableTimerDisposable(_ObservableTimer timer) {
    _InternalDisposable disposable =
        new _InternalDisposable(() async => timer.cancel());
    _internalDisposables.add(disposable);
    timer.didConclude.then((Null _) {
      if (!isDisposedOrDisposing) {
        _internalDisposables.remove(disposable);
      }
    });
  }

  void _completeDisposeFuture() {
    _didDispose.complete();
    _isDisposing = false;
    if (_debugMode) {
      _logger.info('Disposed object $_guid');
    }
  }

  void _logDispose() {
    if (_debugMode) {
      _logger.info('Disposing object $_guid of type $runtimeType');
    }
  }

  void _logUnmanageMessage(String type, Object target) {
    if (_debugMode) {
      _logger.info('Object $_guid unmanaging $type ${target.hashCode}');
    }
  }

  void _logManageMessage(String type, Object target) {
    if (_debugMode) {
      _logger.info('Object $_guid managing $type ${target.hashCode}');
    }
  }

  void _throwOnInvalidCall(
      String methodName, String parameterName, dynamic parameterValue) {
    if (parameterValue == null) {
      throw new ArgumentError.notNull(parameterName);
    }
    if (isDisposing) {
      throw new StateError('$methodName not allowed, object is disposing');
    }
    if (isDisposed) {
      throw new StateError(
          '$methodName not allowed, object is already disposed');
    }
  }
}
