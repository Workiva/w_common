import 'dart:async';

import 'package:meta/meta.dart';
import 'package:w_common/func.dart';
import 'package:w_common/src/common/disposable.dart';

/// Immutable payload that indicates a change in a [Cache].
class CacheContext<TIdentifier, TValue> {
  /// Identifies a single instance of a [TValue]
  final TIdentifier id;

  /// The current value stored in the [Cache] for the attributed [TIdentifier].
  final TValue value;

  CacheContext(this.id, this.value);
}

/// Caching strategy to be used by [Cache].
///
/// Caching Strategies can be opaquely swapped out independently of the
/// consumption pattern of [Cache] or any other cache implementation.
class CachingStrategy<TIdentifier, TValue> {
  /// Custom logic to be executed after a [Cache.get] or [Cache.getAsync].
  Future<Null> onDidGet(TIdentifier id, TValue value) async {}

  /// Custom logic to be executed after a [Cache.release].
  ///
  /// [Cache.release] awaits the completion of a pending value factory associated
  /// with the given [TIdentifier] before the onDidRelease lifecycle method is
  /// called.
  ///
  /// [Cache.release] indicates that the [TIdentifier], [TValue] pair have been
  /// marked as as eligible for removal from the cache. Whether the value is
  /// actually removed is determined here. The [remove] callback will remove the
  /// given item from the cache. For example the following implementation would
  /// set an eviction timer of 30 seconds.
  ///
  ///     @override
  ///     Future<Null> onDidRelease(TIdentifier id, TValue value, Future<Null>
  ///         remove(TIdentifier id)) async {
  ///       var timer = getManagedTimer(new Duration(seconds:30), () {
  ///         remove(id);
  ///       });
  ///     }
  ///
  /// Values should not be removed unnecessarily. In the example below it is
  /// expected that both `a`, `b` and `c` would resolve to the same value while
  /// only making `_superLongAsyncCall` once. Here [Cache.release] and
  /// [Cache.getAsync] are called synchronously before `_superLongAsyncCall` has
  /// completed. The strategy has enough information to know that even though
  /// release was called there is no need for the value to be evicted and
  /// recomputed (because of the get immediately after the release). Release is
  /// a suggestion, every release does not need to be paired with a removal. If
  /// consumers wanted `_superLongAsyncCall` in the example below to be run
  /// twice, [Cache.remove] could be used.
  ///
  ///     var a = cache.getAsync('id', _superLongAsyncCall);
  ///     var release = cache.release('id');
  ///     var b = cache.getAsync('id', _superLongAsyncCall);
  ///
  ///     await release;
  ///     // _superLongAsyncCall and onDidRelease have now completed
  ///
  ///     var c = cache.getAsync('id', _superLongAsyncCall);
  Future<Null> onDidRelease(TIdentifier id, TValue value,
      Future<Null> remove(TIdentifier id)) async {}

  /// Custom logic to be executed after a [Cache.remove].
  ///
  /// This indicates that the [TIdentifier], [TValue] pair are no longer in the
  /// cache.
  Future<Null> onDidRemove(TIdentifier id, TValue value) async {}

  /// Custom logic to be executed before a [Cache.get] or [Cache.getAsync].
  void onWillGet(TIdentifier id) {}

  /// Custom logic to be executed before a [Cache.release].
  void onWillRelease(TIdentifier id) {}

  /// Custom logic to be executed before a [Cache.remove].
  void onWillRemove(TIdentifier id) {}
}

/// Maintains a reference to a given [TValue] associated with a [TIdentifier].
///
/// References are retained for the lifecycle of the instance of the [Cache],
/// unless explicitly removed.
class Cache<TIdentifier, TValue> extends Object with Disposable {
  /// The backing store for values in the [Cache].
  Map<TIdentifier, Future<TValue>> _cache = <TIdentifier, Future<TValue>>{};

  /// The current caching strategy, set at construction.
  final CachingStrategy<TIdentifier, TValue> _cachingStrategy;

  // ignore: close_sinks
  StreamController<CacheContext<TIdentifier, TValue>> _didReleaseController =
      new StreamController<CacheContext<TIdentifier, TValue>>.broadcast();

  // ignore: close_sinks
  StreamController<CacheContext<TIdentifier, TValue>> _didRemoveController =
      new StreamController<CacheContext<TIdentifier, TValue>>.broadcast();

  // ignore: close_sinks
  StreamController<CacheContext<TIdentifier, TValue>> _didUpdateController =
      new StreamController<CacheContext<TIdentifier, TValue>>.broadcast();

  Cache(this._cachingStrategy) {
    [_didReleaseController, _didRemoveController, _didUpdateController]
        .forEach(manageStreamController);
  }

  /// A stream of [CacheContext]s that dispatches when an item is released from
  /// the cache.
  ///
  /// This does not necessarily mean that the item has been removed, only that it
  /// has been marked as eligible for removal. The [didRemove] stream contains
  /// information about true removal.
  Stream<CacheContext<TIdentifier, TValue>> get didRelease =>
      _didReleaseController.stream;

  /// A stream of [CacheContext]s that dispatches when an item is removed from
  /// the cache.
  Stream<CacheContext<TIdentifier, TValue>> get didRemove =>
      _didRemoveController.stream;

  /// The stream of [CacheContext]s that dispatches when an item is updated in
  /// the cache.
  Stream<CacheContext<TIdentifier, TValue>> get didUpdate =>
      _didUpdateController.stream;

  Iterable<TIdentifier> get keys => _cache.keys;

  Future<Iterable<TValue>> get values => Future.wait(_cache.values);

  /// Does the [Cache] contain the given [TIdentifier]?
  ///
  /// If the [Cache] [isOrWillBeDisposed] then a [StateError] is thrown.
  bool containsKey(TIdentifier id) {
    _throwWhenDisposed('determine if identifier is cached');
    return _cache.containsKey(id);
  }

  /// Returns a value from the cache for a given [TIdentifier].
  ///
  /// If the [TIdentifier] is not present in the cache the value returned by the
  /// given [valueFactory] is added to the cache and returned.
  ///
  /// All calls to [get] await a call to the current caching strategy's
  /// [CachingStrategy.onDidGet] lifecycle method before returning the cached value.
  /// If the [Cache] does not contain an instance for the given [TIdentifier],
  /// the given [valueFactory] is called and a [CacheContext] event is emitted on
  /// the [didUpdate] stream. A call to [get] that returns a cached value does
  /// not emit this event as the [Cache] has not changed.
  ///
  /// Calls to [get] are evaluated synchronously and will return the future value
  /// established by the first call to [get]. This allows calls to [get] to
  /// return the same value regardless of completion of asynchronous calls to the
  /// current caching strategy's [CachingStrategy.onDidGet] lifecycle method or
  /// [valueFactory].
  ///
  ///     var a = cache.get('id', _superLongCall);
  ///     var b = cache.get('id', _superLongCall);
  ///     var c = cache.get('id', _superLongCall);
  ///
  ///     // The futures in this list will all resolve to the same instance,
  ///     // which was returned by `_superLongCall` the first time `get` was called.
  ///     var values = Future.wait([a, b, c]);
  ///
  /// If the [Cache] [isOrWillBeDisposed] then a [StateError] is thrown.
  @mustCallSuper
  Future<TValue> get(TIdentifier id, Func<TValue> valueFactory) {
    _throwWhenDisposed('get');
    _cachingStrategy.onWillGet(id);
    // Await any pending cached futures
    if (_cache.containsKey(id)) {
      return _cache[id].then((TValue value) async {
        await _cachingStrategy.onDidGet(id, value);
        return value;
      });
    }

    // Install Future value
    final Completer<TValue> completer = new Completer<TValue>();
    _cache[id] = completer.future;
    try {
      final TValue value = valueFactory.call();

      _cachingStrategy.onDidGet(id, value).then((Null _) {
        _didUpdateController.add(new CacheContext(id, value));
        completer.complete(value);
      });
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }

    return _cache[id];
  }

  /// Returns a value from the cache for a given [TIdentifier].
  ///
  /// If the [TIdentifier] is not present in the cache the value returned by the
  /// given [valueFactory] is added to the cache and returned.
  ///
  /// All calls to [getAsync] await a call to the current caching strategy's
  /// [CachingStrategy.onDidGet] method before returning the cached value. If the
  /// [Cache] does not contain an instance for the given [TIdentifier], the given
  /// [valueFactory] is called and a [CacheContext] event is emitted on the
  /// [didUpdate] stream. A call to [getAsync] that returns a cached value does
  /// not emit this event as the [Cache] has not updated.
  ///
  /// Calls to [getAsync] are evaluated synchronously and will return the future
  /// value established by the first call to [get]. This allows calls to
  /// [getAsync] to return the same value regardless of completion of
  /// asynchronous calls to the current caching strategy's
  /// [CachingStrategy.onDidGet] method or [valueFactory].
  ///
  ///     var a = cache.getAsync('id', _superLongAsyncCall);
  ///     var b = cache.getAsync('id', _superLongAsyncCall);
  ///     var c = cache.getAsync('id', _superLongAsyncCall);
  ///
  ///     // The futures in this list will all resolve to the same instance,
  ///     // which was returned by `_superLongAsyncCall` the first time `get` was
  ///     // called.
  ///     var values = Future.wait([a, b, c]);
  ///
  /// If the [Cache] [isOrWillBeDisposed] then a [StateError] is thrown.
  @mustCallSuper
  Future<TValue> getAsync(TIdentifier id, Func<Future<TValue>> valueFactory) {
    _throwWhenDisposed('getAsync');
    _cachingStrategy.onWillGet(id);
    // Await any pending cached futures
    if (_cache.containsKey(id)) {
      return _cache[id].then((TValue value) async {
        await _cachingStrategy.onDidGet(id, value);
        return value;
      });
    }

    // Install Future value
    _cache[id] = valueFactory.call().then((TValue value) async {
      await _cachingStrategy.onDidGet(id, value);
      _didUpdateController.add(new CacheContext(id, value));
      return value;
    });

    return _cache[id];
  }

  /// Marks a [TIdentifier] [TValue] pair as eligible for removal.
  ///
  /// The decision of whether or not to actually remove the value will be up to
  /// the current [CachingStrategy].
  @mustCallSuper
  Future<Null> release(TIdentifier id) {
    _throwWhenDisposed('release');
    // Await any pending cached futures
    if (_cache.containsKey(id)) {
      _cachingStrategy.onWillRelease(id);
      return _cache[id].then((TValue value) async {
        await _cachingStrategy.onDidRelease(id, value, remove);
        _didReleaseController.add(new CacheContext(id, value));
      }).catchError((Object error, StackTrace stackTrace) {
        return null;
      });
    }

    return new Future.value();
  }

  /// Removes the reference to a [TValue] associated with the given
  /// [TIdentifier].
  ///
  /// A [CacheContext] value is emitted by the [didUpdate] stream upon
  /// successful removal of the given [TIdentifier]. In addition, a
  /// [CacheContext] value is emitted by the [didRemove] stream upon successful
  /// removal from the cache.
  ///
  /// If the [Cache] [isOrWillBeDisposed] then a [StateError] is thrown.
  @mustCallSuper
  Future<Null> remove(TIdentifier id) {
    _throwWhenDisposed('remove');
    if (_cache.containsKey(id)) {
      _cachingStrategy.onWillRemove(id);
      final removedValue = _cache.remove(id);
      return removedValue.then((TValue value) async {
        await _cachingStrategy.onDidRemove(id, value);
        _didRemoveController.add(new CacheContext(id, value));
        _didUpdateController.add(new CacheContext(id, null));
      }).catchError((Object error, StackTrace stackTrace) {
        return null;
      });
    }

    return new Future.value();
  }

  void _throwWhenDisposed(String op) {
    if (isOrWillBeDisposed) {
      throw new StateError('Cannot $op when Cache is disposed');
    }
  }
}
