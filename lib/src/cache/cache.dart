import 'dart:async';

import 'package:meta/meta.dart';

import 'package:w_common/disposable.dart';
import 'package:w_common/func.dart';

/// Immutable payload that indicates a change in a [Cache].
class CacheContext<TIdentifier, TValue> {
  /// Identifies a single instance of a [TValue]
  final TIdentifier id;

  /// The current value stored in the [Cache] for the attributed [TIdentifier].
  final TValue value;

  CacheContext(this.id, this.value);
}

/// Maintians a reference to a given any [TValue] attributed to a [TIdentifier].
///
/// References are retained for the lifecycle of the instance of the [Cache],
/// unless explicitly removed.
class Cache<TIdentifier, TValue> extends Object with Disposable {
  /// The backing store for values in the [Cache].
  Map<TIdentifier, Future<TValue>> _cache = <TIdentifier, Future<TValue>>{};

  // ignore: close_sinks
  StreamController<CacheContext<TIdentifier, TValue>> _didUpdateController =
      new StreamController<CacheContext<TIdentifier, TValue>>.broadcast();

  // ignore: close_sinks
  StreamController<CacheContext<TIdentifier, TValue>> _didRemoveController =
      new StreamController<CacheContext<TIdentifier, TValue>>.broadcast();

  /// A collection of pending removals for a given [TIdentifier].
  Map<TIdentifier, Completer<Null>> _removalCompleters =
      <TIdentifier, Completer<Null>>{};

  Cache() {
    [_didRemoveController, _didUpdateController]
        .forEach(manageStreamController);
  }

  /// The collection of removals from the [Cache].
  Stream<CacheContext<TIdentifier, TValue>> get didRemove =>
      _didRemoveController.stream;

  /// The collection of changes to the [Cache].
  ///
  /// Values are emitted when the cached value is changes.
  Stream<CacheContext<TIdentifier, TValue>> get didUpdate =>
      _didUpdateController.stream;

  /// Returns a value from the cache for a given [TIdentifier] or adds the
  /// [TValue] returned by the value factory when the value does not exist in
  /// the cache.
  ///
  /// All calls to [get] await a call to the [onGet] lifecycle method before
  /// returning the cached value. If the [Cache] does not contain an instance
  /// for the given [TIdentifier], the given [valueFactory] is called and an
  /// [CacheContext] event is emitted on the [didUpdate] stream. A call to [get]
  /// that returns a cached value does not emit this event as the [Cache] has
  /// not updated.
  ///
  /// Calls to [get] are evaluated syncronously and will return the future value
  /// established by the first call to [get]. This allows calls to get to
  /// return the same value regardless of completion of asyncronous calls to
  /// the [onGet] lifecycle methods or [valueFactory].
  ///
  /// ```
  /// var a = cache.get('id', _superLongCall);
  /// var b = cache.get('id', _superLongCall);
  /// var c = cache.get('id', _superLongCall);
  ///
  /// // All of the values in this list are the same instance returned by the
  /// // first call to `_superLongCall`.
  /// var values = Future.wait([a, b, c]);
  /// ```
  ///
  /// If the [Cache] [isDisposedOrDisposing] then a [StateError] is thrown.
  @mustCallSuper
  Future<TValue> get(TIdentifier id, Func<TValue> valueFactory) {
    _throwWhenDisposed('get');

    // Await any pending cached futures
    if (_cache.containsKey(id)) {
      return _cache[id].then((TValue value) async {
        await onGet(id, value);
        return value;
      });
    }

    // Install Future value
    final Completer<TValue> completer = new Completer<TValue>();
    _cache[id] = completer.future;
    final TValue value = valueFactory.call();

    onGet(id, value).then((Null _) {
      _didUpdateController.add(new CacheContext(id, value));
      completer.complete(value);
    });

    return _cache[id];
  }

  /// Returns a value from the cache for a given [TIdentifier] or adds the
  /// [TValue] resolved from the [Future] returned by factory when the value
  /// does not exist in the cache.
  ///
  /// All calls to [get] await a call to the [onGet] lifecycle method before
  /// returning the cached value. If the [Cache] does not contain an instance
  /// for the given [TIdentifier], the given [valueFactory] is called and an
  /// [CacheContext] event is emitted on the [didUpdate] stream. A call to [get]
  /// that returns a cached value does not emit this event as the [Cache] has
  /// not updated.
  ///
  /// Calls to [get] are evaluated syncronously and will return the future value
  /// established by the first call to [get]. This allows calls to get to
  /// return the same value regardless of completion of asyncronous calls to
  /// the [onGet] lifecycle methods or [valueFactory].
  ///
  /// ```
  /// var a = cache.getAsync('id', _superLongAsyncCall);
  /// var b = cache.getAsync('id', _superLongAsyncCall);
  /// var c = cache.getAsync('id', _superLongAsyncCall);
  ///
  /// // All of the values in this list are the same instance returned by the
  /// // first call to `_superLongAsyncCall`.
  /// var values = Future.wait([a, b, c]);
  /// ```
  ///
  /// If the [Cache] [isDisposedOrDisposing] then a [StateError] is thrown.
  @mustCallSuper
  Future<TValue> getAsync(TIdentifier id, Func<Future<TValue>> valueFactory) {
    _throwWhenDisposed('getAsync');

    // Await any pending cached futures
    if (_cache.containsKey(id)) {
      return _cache[id].then((TValue value) async {
        await onGet(id, value);
        return value;
      });
    }

    // Install Future value
    final Completer<TValue> completer = new Completer<TValue>();
    _cache[id] = completer.future;
    valueFactory.call().then((TValue value) async {
      await onGet(id, value);
      _didUpdateController.add(new CacheContext(id, value));
      completer.complete(value);
    });

    return _cache[id];
  }

  /// Is the given identifier in the [Cache]?
  ///
  /// If the [Cache] [isDisposedOrDisposing] then a [StateError] is thrown.
  bool isCached(TIdentifier id) {
    _throwWhenDisposed('determine if identifier is cached');
    return _cache.containsKey(id);
  }

  /// Allows consumers to define behavior that is executed when a [TValue] is
  /// obtained from the [Cache].
  @protected
  Future<Null> onGet(TIdentifier id, TValue value) async {}

  /// Allows consumers to define behavior that is executed when a [TValue] is
  /// put in the [Cache].
  @protected
  Future<Null> onPut(TIdentifier id, TValue value) async {}

  /// Allows consumers to define behavior that is executed when a [TValue] is
  /// removed.
  @protected
  Future<Null> onRemove(TIdentifier id, TValue value) async {}

  /// Updates the current value for a given [TIdentifier] with the given
  /// [TValue].
  ///
  /// Putting a value into the [Cache] results in the imeddiate replacement. Any
  /// future call to [get] or [getAsync] will return the given [value]. Any call
  /// to put will await the completion of the [onPut] lifecycle method before
  /// returning the given value. A [CacheContext] event is emitted by the
  /// [didUpdate] stream upon completion of the [put].
  ///
  /// If the [Cache] [isDisposedOrDisposing] then a [StateError] is thrown.
  Future<TValue> put(TIdentifier id, TValue value) {
    _throwWhenDisposed('put');
    final Completer<TValue> completer = new Completer<TValue>();
    _cache[id] = completer.future;

    onPut(id, value).then((Null _) {
      _didUpdateController.add(new CacheContext(id, value));
      completer.complete(value);
    });

    return _cache[id];
  }

  /// Removes the reference to a [TValue] associated with the given
  /// [TIdentifier].
  ///
  /// If a value is currently cached for the given [TIdentifier], the completion
  /// of the [get] or [put] that inserted the [TIdentifier] into the cache is
  /// awaited before removal. This ensures that any pending asyncronous calls
  /// against the cache resovle to a value.
  ///
  /// A [CacheContext] value is emitted by the [didUpdate] stream upon
  /// successfull removal of the given [TIdentifier]. In addition, a
  /// [CacheContext] value is emitted by the [didRemove] stream upon successfull
  /// removal from the cache.
  ///
  /// If the [Cache] [isDisposedOrDisposing] then a [StateError] is thrown.
  @mustCallSuper
  Future<Null> remove(TIdentifier id) {
    _throwWhenDisposed('remove');
    if (_cache.containsKey(id)) {
      return _removalCompleters.putIfAbsent(id, () {
        final completer = new Completer<Null>();

        _cache[id].then((TValue value) async {
          await onRemove(id, value);
          await _cache.remove(id);
          _removalCompleters.remove(id);
          _didRemoveController.add(new CacheContext(id, value));
          _didUpdateController.add(new CacheContext(id, null));
          completer.complete();
        });

        return completer;
      }).future;
    }

    return new Future.value();
  }

  void _throwWhenDisposed(String op) {
    if (isDisposedOrDisposing) {
      throw new StateError('Cannot $op when Cache is disposed');
    }
  }
}
