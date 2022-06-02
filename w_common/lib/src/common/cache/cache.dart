import 'dart:async';

import 'package:logging/logging.dart';
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

/// An abstraction over [Map] that helps avoid paying construction costs for
/// expensive objects.
///
/// Objects are created or existing ones returned with [get] or its `async`
/// equivalent [getAsync] and marked as eligible for removal with [release]. If
/// the [TValue] stored requires some sort of destruction this should be done in
/// a callback registered with the [didRemove] stream.
///
/// References are retained for the lifecycle of the instance of the [Cache],
/// unless explicitly removed.
class Cache<TIdentifier, TValue> extends Object with Disposable {
  @override
  String get disposableTypeName => 'Cache';

  final Logger _log = Logger('w_common.Cache');

  /// Any apply to item callbacks currently in flight.
  final Map<TIdentifier, List<Future<dynamic>>> _applyToItemCallBacks =
      <TIdentifier, List<Future<dynamic>>>{};

  /// The backing store for values in the [Cache].
  final Map<TIdentifier, Future<TValue>> _cache =
      <TIdentifier, Future<TValue>>{};

  /// Whether a given identifier has been released.
  final Map<TIdentifier, bool> _isReleased = <TIdentifier, bool>{};

  /// The current caching strategy, set at construction.
  final CachingStrategy<TIdentifier, TValue> _cachingStrategy;

  // ignore: close_sinks
  StreamController<CacheContext<TIdentifier, TValue>> _didReleaseController =
      StreamController<CacheContext<TIdentifier, TValue>>.broadcast();

  // ignore: close_sinks
  StreamController<CacheContext<TIdentifier, TValue>> _didRemoveController =
      StreamController<CacheContext<TIdentifier, TValue>>.broadcast();

  // ignore: close_sinks
  StreamController<CacheContext<TIdentifier, TValue>> _didUpdateController =
      StreamController<CacheContext<TIdentifier, TValue>>.broadcast();

  Cache(this._cachingStrategy) {
    [_didReleaseController, _didRemoveController, _didUpdateController]
        .forEach(manageStreamController);
  }

  @visibleForTesting
  Map<TIdentifier, List<Future<dynamic>>> get applyToItemCallBacks =>
      _applyToItemCallBacks;

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

  /// Keys that may, or may not, be released.
  ///
  /// Deprecated: 1.12.0
  /// To be removed: 2.0.0
  ///
  /// This entry point is deprecated in favor of the more precisely named
  /// [releasedKeys] and [liveKeys].
  @deprecated
  Iterable<TIdentifier> get keys => _cache.keys;

  /// Keys that have not been released.
  Iterable<TIdentifier> get liveKeys =>
      _cache.keys.where((TIdentifier key) => !_isReleased[key]);

  /// Values that have not been released.
  ///
  /// To access a released value a [get] or [getAsync] should be used.
  Future<Iterable<TValue>> get liveValues =>
      Future.wait(liveKeys.map((TIdentifier key) => _cache[key]));

  /// Keys that have been released but are not yet removed.
  Iterable<TIdentifier> get releasedKeys =>
      _cache.keys.where((TIdentifier key) => _isReleased[key]);

  /// Values that have not been released.
  ///
  /// To access a released value a [get] or [getAsync] should be used.
  ///
  /// Deprecated: 1.12.0
  /// To be removed: 2.0.0
  ///
  /// This entry point is deprecated in favor of the more precisely named
  /// [liveValues].
  @deprecated
  Future<Iterable<TValue>> get values => liveValues;

  /// Does the [Cache] contain the given [TIdentifier]?
  ///
  /// If the [Cache] [isOrWillBeDisposed] then a [StateError] is thrown.
  ///
  /// Deprecated: 1.12.0
  /// To be removed: 2.0.0
  ///
  /// This entry point is deprecated in favor of using [liveKeys].contains
  /// or [releasedKeys].contains directly.
  @deprecated
  bool containsKey(TIdentifier id) {
    _throwWhenDisposed('containsKey');
    return liveKeys.contains(id) || releasedKeys.contains(id);
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
    _log.finest('get id: $id');
    _throwWhenDisposed('get');
    _cachingStrategy.onWillGet(id);
    _isReleased[id] = false;
    // Await any pending cached futures
    if (_cache.containsKey(id)) {
      return _cache[id].then((TValue value) async {
        await _cachingStrategy.onDidGet(id, value);
        return value;
      });
    }

    // Install Future value
    final Completer<TValue> completer = Completer<TValue>();
    _cache[id] = completer.future;
    try {
      final TValue value = valueFactory.call();

      _cachingStrategy.onDidGet(id, value).then((Null _) {
        _didUpdateController.add(CacheContext(id, value));
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
    _log.finest('getAsync id: $id');
    _throwWhenDisposed('getAsync');
    _isReleased[id] = false;
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
      _didUpdateController.add(CacheContext(id, value));
      return value;
    });

    return _cache[id];
  }

  /// Marks a [TIdentifier] [TValue] pair as eligible for removal.
  ///
  /// The decision of whether or not to actually remove the value will be up to
  /// the current [CachingStrategy].
  ///
  /// Release indicates that consuming code has finished with the [TIdentifier]
  /// [TValue] pair associated with [id]. This pair may be removed immediately or
  /// in time depending on the [CachingStrategy]. Access to the pair will be
  /// blocked immediately, i.e. the [liveValues] getter won't report this
  /// item, even if the pair isn't immediately removed from the cache. A [get] or
  /// [getAsync] must be performed to mark the item as ineligible for removal and
  /// live in the cache again.
  ///
  /// If the [Cache] [isOrWillBeDisposed] then a [StateError] is thrown.
  @mustCallSuper
  Future<Null> release(TIdentifier id) {
    _log.finest('release id: $id');
    _throwWhenDisposed('release');
    _isReleased[id] = true;
    // Await any pending cached futures
    if (_cache.containsKey(id)) {
      _cachingStrategy.onWillRelease(id);
      return _cache[id].then((TValue value) async {
        await _cachingStrategy.onDidRelease(id, value, remove);
        _didReleaseController.add(CacheContext(id, value));
      }).catchError((Object error, StackTrace stackTrace) {
        return null;
      });
    }

    return Future.value();
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
    _log.finest('remove id: $id');
    _throwWhenDisposed('remove');
    _isReleased.remove(id);
    if (_cache.containsKey(id)) {
      _cachingStrategy.onWillRemove(id);
      final removedValue = _cache.remove(id);
      return removedValue.then((TValue value) async {
        if (_applyToItemCallBacks[id] != null) {
          await Future.wait(_applyToItemCallBacks[id]);
        }
        await _cachingStrategy.onDidRemove(id, value);
        _didRemoveController.add(CacheContext(id, value));
        _didUpdateController.add(CacheContext(id, null));
      }).catchError((Object error, StackTrace stackTrace) {
        return null;
      });
    }

    return Future.value();
  }

  /// Returns `true` and calls [callback] if there is a cached, unreleased
  /// [TValue] associated with [id]; returns `false` otherwise.
  ///
  /// This does not perform a [get] or [getAsync], and as a result, will not
  /// affect retention or removal of a [TIdentifier][TValue] pair from the cache.
  ///
  /// Any [TIdentifier] [TValue] pair removals will wait for the Future returned by
  /// the call to [callback] before emitting [didRemove] events.
  ///
  /// If the [Cache] [isOrWillBeDisposed] then a [StateError] is thrown.
  Future<bool> applyToItem(
      TIdentifier id, dynamic callback(Future<TValue> value)) {
    _log.finest('applyToItem id: $id');
    _throwWhenDisposed('applyToItem');
    if (_isReleased[id] != false) {
      return Future<bool>.value(false);
    }

    final callBackResult = callback(_cache[id]);
    if (callBackResult is Future<dynamic>) {
      // In this case we're only interested in the computation being done or not
      // done, not in the result
      final errorlessCallbackResult = callBackResult.catchError((_) {});

      _applyToItemCallBacks.putIfAbsent(id, () => <Future<dynamic>>[]);
      _applyToItemCallBacks[id].add(errorlessCallbackResult);

      errorlessCallbackResult.whenComplete(() {
        _applyToItemCallBacks[id].remove(errorlessCallbackResult);
        if (_applyToItemCallBacks[id].isEmpty) {
          _applyToItemCallBacks.remove(id);
        }
      });

      // Return future that will complete with either true or the error
      // generated from callback
      return callBackResult.then((_) => true);
    }
    return Future<bool>.value(true);
  }

  void _throwWhenDisposed(String op) {
    if (isOrWillBeDisposed) {
      throw StateError('Cannot $op when Cache is disposed');
    }
  }
}
