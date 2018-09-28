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

import 'package:w_common/src/common/disposable_manager.dart';
import 'package:w_common/src/common/disposable_state.dart';
import 'package:w_common/src/common/managed_stream_subscription.dart';
import 'package:w_common/src/leak_flagger.dart';

// ignore: one_member_abstracts
abstract class _Disposable {
  Future<void> dispose();
}

/// Used to invoke, and remove references to, a [Disposer] before disposal
/// of the parent object.
class ManagedDisposer implements _Disposable {
  Disposer _disposer;
  final Completer<void> _didDispose = new Completer<void>();
  bool _isDisposing = false;

  /// Instantiate a managed disposer.
  ManagedDisposer(this._disposer);

  /// A [Future] that will complete when this object has been disposed.
  Future<void> get didDispose => _didDispose.future;

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
  Future<void> dispose() {
    if (isDisposedOrDisposing) {
      return didDispose;
    }
    _isDisposing = true;

    final disposeFuture = _disposer != null
        ? (_disposer() ?? new Future.value())
        : new Future.value();
    _disposer = null;

    return disposeFuture.then((_) {
      _disposer = null;
      _didDispose.complete();
      _isDisposing = false;
    });
  }
}

/// A [Timer] implementation that exposes a [Future] that resolves when a
/// non-periodic timer finishes it's callback or when any type of [Timer] is
/// cancelled.
class _ObservableTimer implements Timer {
  final _didConclude = new Completer<void>();
  Timer _timer;

  _ObservableTimer(Duration duration, void callback()) {
    _timer = new Timer(duration, () {
      callback();
      _complete();
    });
  }

  _ObservableTimer.periodic(Duration duration, void callback(Timer t)) {
    _timer = new Timer.periodic(duration, callback);
  }

  void _complete() {
    if (!_didConclude.isCompleted) {
      _didConclude.complete();
    }
  }

  /// The timer has either been completed or has been cancelled.
  Future<void> get didConclude => _didConclude.future;

  @override
  void cancel() {
    _timer.cancel();
    _complete();
  }

  @override
  bool get isActive => _timer.isActive;

  @override
  int get tick {
    // TODO: Once fully transitioned to Dart 2 just return
    // the tick value from our internal timer
    // return _timer.tick;
    throw new UnsupportedError('Timer.tick is unsupported');
  }
}

/// A function that, when called, disposes of one or more objects.
typedef Future<dynamic> Disposer();

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
/// Helper methods, such as [listenToStream] allow certain
/// cleanup to be automated. Managed subscriptions will be automatically
/// canceled when [dispose] is called on the object.
///
///      class MyDisposable extends Object with Disposable {
///        StreamController _controller = new StreamController();
///
///        MyDisposable(Stream someStream) {
///          listenToStream(someStream, (_) => print('some stream'));
///          manageStreamController(_controller);
///        }
///
///        Future<void> onDispose() {
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
///          _disposable.listenToStream(someStream, (_) => null));
///        }
///
///        @override
///        StreamSubscription<T> listenToStream<T>(
///            Stream<T> stream, void onData(T event),
///            {Function onError, void onDone(), bool cancelOnError}) {
///          return _disposable.listenToStream(
///            stream, onData,
///            onError: onError,
///            onDone: onDone,
///            cancelOnError: cancelOnError
///          );
///        }
///
///        // ...more methods
///
///        Future<void> unload() async {
///          await _disposable.dispose();
///        }
///      }
///
/// In this case, we want `MyLifecycleThing` to have its own lifecycle
/// without explicit reference to [Disposable]. To do this, we use
/// composition to include the [Disposable] machinery without changing
/// the public interface of our class or polluting its lifecycle.
class Disposable implements _Disposable, DisposableManager, LeakFlagger {
  static bool _debugMode = false;
  static Logger _logger;

  /// Disables logging enabled by [enableDebugMode].
  static void disableDebugMode() {
    if (_debugMode) {
      _debugMode = false;
      _logger.clearListeners();
      _logger = null;
    }
  }

  /// Causes messages to be logged for various lifecycle and management events.
  ///
  /// This should only be used for debugging and profiling as it can result
  /// in a huge number of messages being generated.
  static void enableDebugMode() {
    if (!_debugMode) {
      _debugMode = true;
      _logger = new Logger('w_common.Disposable');
    }
  }

  final _awaitableFutures = new HashSet<Future>();
  final _didDispose = new Completer<void>();
  LeakFlag _leakFlag;
  final _internalDisposables = new HashSet<_Disposable>();
  DisposableState _state = DisposableState.initialized;

  /// A [Future] that will complete when this object has been disposed.
  Future<void> get didDispose => _didDispose.future;

  /// The total size of the disposal tree rooted at the current Disposable
  /// instance.
  ///
  /// This should only be used for debugging and profiling as it can incur
  /// a significant performance penalty if the tree is large.
  int get disposalTreeSize {
    var size = 1;
    for (var disposable in _internalDisposables) {
      if (disposable is Disposable) {
        size += disposable.disposalTreeSize;
      } else {
        size++;
      }
    }
    return size;
  }

  /// Whether this object has been disposed.
  bool get isDisposed => _didDispose.isCompleted;

  /// Whether this object has been disposed or is currently disposing.
  ///
  /// This will become `true` after [dispose] is called, but not until all
  /// [Future]s registered via [awaitBeforeDispose] have resolved, and will
  /// remain `true` forever.
  ///
  /// This is equivalent to:
  ///
  ///     object.isDisposed || object.isDisposing
  ///
  /// Deprecated: 1.9.0
  /// To be removed: 2.0.0
  ///
  /// This was intended as a convenience method to be used to guard against APIs
  /// being called after disposal has started. Consumers should now use
  /// [isOrWillBeDisposed] instead because it also returns true when this
  /// instance is in the "awaiting disposal" state that is entered as soon as
  /// [dispose] is called, whereas this getter does not return true until
  /// disposal has actually started.
  @deprecated
  bool get isDisposedOrDisposing => isDisposed || isDisposing;

  /// Whether this object is in the process of being disposed.
  ///
  /// This will become `true` after [dispose] is called, but not until all
  /// [Future]s registered via [awaitBeforeDispose] have resolved, and will
  /// become `false` once the [didDispose] future completes.
  ///
  /// Deprecated: 1.9.0
  /// To be removed: 2.0.0
  ///
  /// [isOrWillBeDisposed] should be used instead.
  ///
  /// This getter is useful for [Disposable] tests, but for public consumption,
  /// [isOrWillBeDisposed] is more useful because it remains true throughout the
  /// "awaiting disposal", "disposing", and "disposed" states.
  @deprecated
  bool get isDisposing => _state == DisposableState.disposing;

  @override
  bool get isLeakFlagSet => _leakFlag != null;

  /// Whether the disposal of this object has been requested, is in progress, or
  /// is complete.
  ///
  /// This will become `true` as soon as the [dispose] method is called and will
  /// remain `true` forever.
  ///
  /// Recommended usage of this boolean is to guard public APIs such that all
  /// calls after disposal has been requested (via [dispose]) are rejected:
  ///
  ///     Response sendRequest() async {
  ///       if (isOrWillBeDisposed) {
  ///         throw new StateError(
  ///             'sendRequest() cannot be called, object is disposing');
  ///       }
  ///       ...
  ///     }
  bool get isOrWillBeDisposed =>
      _state == DisposableState.awaitingDisposal ||
      _state == DisposableState.disposing ||
      _state == DisposableState.disposed;

  @mustCallSuper
  @override
  Future<T> awaitBeforeDispose<T>(Future<T> future) {
    _throwOnInvalidCall('awaitBeforeDispose', 'future', future);
    _awaitableFutures.add(future);
    future.then((_) {
      if (!isOrWillBeDisposed) {
        _awaitableFutures.remove(future);
      }
    }).catchError((_) {
      if (!isOrWillBeDisposed) {
        _awaitableFutures.remove(future);
      }
    });
    return future;
  }

  /// Dispose of the object, cleaning up to prevent memory leaks.
  @override
  Future<void> dispose() async {
    Stopwatch stopwatch;
    if (_debugMode) {
      stopwatch = new Stopwatch()..start();
    }

    _logDispose();

    if (isDisposed) {
      return null;
    }
    if (isOrWillBeDisposed) {
      return didDispose;
    }

    _state = DisposableState.awaitingDisposal;

    await onWillDispose();

    while (_awaitableFutures.isNotEmpty) {
      final futures = _awaitableFutures.toList();
      _awaitableFutures.clear();
      await Future.wait(futures);
    }

    _state = DisposableState.disposing;

    for (var disposable in _internalDisposables) {
      await disposable.dispose();
    }
    _internalDisposables.clear();

    await onDispose();

    _didDispose.complete();
    _state = DisposableState.disposed;
    if (_debugMode) {
      _logger.info('Disposed object $hashCode of type $runtimeType');
    }

    if (_debugMode) {
      stopwatch.stop();
      _logger
          .info('$runtimeType $hashCode took ${stopwatch.elapsedMicroseconds /
          1000000.0} seconds to dispose');
    }

    flagLeak();
  }

  @mustCallSuper
  @override
  void flagLeak([String description]) {
    if (_debugMode && _leakFlag == null) {
      _leakFlag = new LeakFlag(description ?? runtimeType.toString());
    }
  }

  @mustCallSuper
  @override
  Future<T> getManagedDelayedFuture<T>(Duration duration, T callback()) {
    _throwOnInvalidCall2(
        'getManagedDelayedFuture', 'duration', 'callback', duration, callback);
    final completer = new Completer<T>();
    final timer =
        new _ObservableTimer(duration, () => completer.complete(callback()));
    final disposable = new ManagedDisposer(() async {
      timer.cancel();
      completer.completeError(new ObjectDisposedException());
    });
    _logManageMessage(completer.future);
    _internalDisposables.add(disposable);
    timer.didConclude.then((_) {
      // ignore: deprecated_member_use
      if (!isDisposedOrDisposing) {
        _logUnmanageMessage(completer.future);
        _internalDisposables.remove(disposable);
      }
    });
    return completer.future;
  }

  @mustCallSuper
  @override
  ManagedDisposer getManagedDisposer(Disposer disposer) {
    _throwOnInvalidCall('getManagedDisposer', 'disposer', disposer);
    _logManageMessage(disposer);

    final disposable = new ManagedDisposer(disposer);

    _internalDisposables.add(disposable);

    disposable.didDispose.then((_) {
      // ignore: deprecated_member_use
      if (!isDisposedOrDisposing) {
        _logUnmanageMessage(disposer);
        _internalDisposables.remove(disposable);
      }
    });

    return disposable;
  }

  @mustCallSuper
  @override
  Timer getManagedTimer(Duration duration, void callback()) {
    _throwOnInvalidCall2(
        'getManagedTimer', 'duration', 'callback', duration, callback);
    final timer = new _ObservableTimer(duration, callback);
    _addObservableTimerDisposable(timer);
    return timer;
  }

  @mustCallSuper
  @override
  Timer getManagedPeriodicTimer(Duration duration, void callback(Timer timer)) {
    _throwOnInvalidCall2(
        'getManagedPeriodicTimer', 'duration', 'callback', duration, callback);
    final timer = new _ObservableTimer.periodic(duration, callback);
    _addObservableTimerDisposable(timer);
    return timer;
  }

  @mustCallSuper
  @override
  StreamSubscription<T> listenToStream<T>(
      Stream<T> stream, void onData(T event),
      {Function onError, void onDone(), bool cancelOnError}) {
    _throwOnInvalidCall2('listenToStream', 'stream', 'onData', stream, onData);
    final managedStreamSubscription = new ManagedStreamSubscription(
        stream, onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    _logManageMessage(managedStreamSubscription);

    final disposable = new ManagedDisposer(() {
      _logUnmanageMessage(managedStreamSubscription);
      return managedStreamSubscription.cancel();
    });

    _internalDisposables.add(disposable);

    managedStreamSubscription.didComplete.then((_) {
      // ignore: deprecated_member_use
      if (!isDisposedOrDisposing) {
        _logUnmanageMessage(disposable);
        _internalDisposables.remove(disposable);
      }
    });

    return managedStreamSubscription;
  }

  @mustCallSuper
  @override
  T manageDisposable<T extends Disposable>(T disposable) {
    _throwOnInvalidCall('manageAndReturnDisposable', 'disposable', disposable);
    _manageDisposable(disposable);

    return disposable;
  }

  @mustCallSuper
  @override
  Completer<T> manageCompleter<T>(Completer<T> completer) {
    _throwOnInvalidCall('manageCompleter', 'completer', completer);
    _logManageMessage(completer);

    final disposable = new ManagedDisposer(() async {
      if (!completer.isCompleted) {
        completer.completeError(new ObjectDisposedException());
      }
    });
    _internalDisposables.add(disposable);

    completer.future.catchError((e) {
      // ignore: deprecated_member_use
      if (!isDisposedOrDisposing) {
        _logUnmanageMessage(completer);
        _internalDisposables.remove(disposable);
      }
    }).then((_) {
      // ignore: deprecated_member_use
      if (!isDisposedOrDisposing) {
        _logUnmanageMessage(completer);
        _internalDisposables.remove(disposable);
      }
    });

    return completer;
  }

  void _manageDisposable(Disposable disposable) {
    _throwOnInvalidCall('manageDisposable', 'disposable', disposable);
    _logManageMessage(disposable);

    _internalDisposables.add(disposable);
    disposable.didDispose.then((_) {
      // ignore: deprecated_member_use
      if (!isDisposedOrDisposing) {
        _logUnmanageMessage(disposable);
        _internalDisposables.remove(disposable);
      }
    });
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
    _logManageMessage(controller);

    var isDone = false;

    final disposable = new ManagedDisposer(() {
      if (!controller.hasListener && !controller.isClosed && !isDone) {
        controller.stream.listen((_) {});
      }
      return controller.close();
    });

    controller.done.then((_) {
      isDone = true;
      // ignore: deprecated_member_use
      if (!isDisposedOrDisposing) {
        _logUnmanageMessage(controller);
        _internalDisposables.remove(disposable);
      }
      disposable.dispose();
    });

    _internalDisposables.add(disposable);
  }

  /// Callback to allow arbitrary cleanup on dispose.
  @protected
  Future<void> onDispose() async => null;

  /// Callback to allow arbitrary cleanup as soon as disposal is requested (i.e.
  /// [dispose] is called) but prior to disposal actually starting.
  ///
  /// Disposal will _not_ start before the [Future] returned from this method
  /// completes.
  @protected
  Future<void> onWillDispose() async => null;

  void _addObservableTimerDisposable(_ObservableTimer timer) {
    final disposable =
        new ManagedDisposer(() async => timer.cancel());
    _internalDisposables.add(disposable);
    timer.didConclude.then((_) {
      // ignore: deprecated_member_use
      if (!isDisposedOrDisposing) {
        _internalDisposables.remove(disposable);
      }
    });
  }

  void _logDispose() {
    if (_debugMode) {
      _logger.info('Disposing object $hashCode of type $runtimeType');
    }
  }

  void _logUnmanageMessage(Object target) {
    if (_debugMode) {
      _logger.info(
          '$runtimeType $hashCode unmanaging ${target.runtimeType} ${target.hashCode}');
    }
  }

  void _logManageMessage(Object target) {
    if (_debugMode) {
      _logger.info(
          '$runtimeType $hashCode managing ${target.runtimeType} ${target.hashCode}');
    }
  }

  void _throwOnInvalidCall(
      String methodName, String parameterName, Object parameterValue) {
    if (parameterValue == null) {
      throw new ArgumentError.notNull(parameterName);
    }
    // ignore: deprecated_member_use
    if (isDisposing) {
      throw new StateError('$methodName not allowed, object is disposing');
    }
    if (isDisposed) {
      throw new StateError(
          '$methodName not allowed, object is already disposed');
    }
  }

  void _throwOnInvalidCall2(
      String methodName,
      String parameterName,
      String secondParameterName,
      Object parameterValue,
      Object secondParameterValue) {
    if (secondParameterValue == null) {
      throw new ArgumentError.notNull(secondParameterName);
    }
    _throwOnInvalidCall(methodName, parameterName, parameterValue);
  }
}
