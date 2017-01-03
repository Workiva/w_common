import 'dart:async';

import 'package:meta/meta.dart';

import 'package:w_common/src/cache/cache.dart';

/// Maintains the number of references for an instance of an cache value.
class ReferenceCache<TIdentifier, TValue> extends Cache<TIdentifier, TValue> {
  Map<TIdentifier, int> _count = {};

  @override
  @protected
  @mustCallSuper
  Future<Null> onGet(TIdentifier id, TValue value) async {
    _count[id] = _count.putIfAbsent(id, () => 0) + 1;
  }

  @override
  @protected
  @mustCallSuper
  Future<Null> onPut(TIdentifier id, TValue value) async {
    _count[id] = 1;
  }

  /// A lifecycle method called when the cache releases a count for a given
  /// [TIdentifier].
  @protected
  @mustCallSuper
  Future<Null> onRelease(TIdentifier id) async {}

  @override
  @protected
  @mustCallSuper
  Future<Null> onRemove(TIdentifier id, TValue value) async {
    _count.remove(id);
  }

  /// The number of references maintained for a given [TIdentifier].
  ///
  /// If the [ReferenceCache] [isDisposedOrDisposing] then a [StateError] is
  /// thrown.
  int referenceCount(TIdentifier id) {
    _throwIfDisposed('referenceCount');
    return _count[id] ?? 0;
  }

  /// Releases a reference for a given [TIdentifier] and removes the
  /// [TIdentifier] from the [ReferenceCache] when the last reference is
  /// released.
  ///
  /// If the [ReferenceCache] [isDisposedOrDisposing] then a [StateError] is
  /// thrown.
  @mustCallSuper
  Future<Null> release(TIdentifier id) {
    _throwIfDisposed('release');

    var refs = referenceCount(id);

    if (refs == 0) {
      return new Future.value();
    }

    final Completer<Null> completer = new Completer<Null>();

    if (refs == 1) {
      remove(id).then((Null _) async {
        await onRelease(id);
        completer.complete();
      });
    } else {
      onRelease(id).then((Null _) => completer.complete());
    }

    _count[id] = refs - 1;
    return completer.future;
  }

  void _throwIfDisposed(String op) {
    if (isDisposedOrDisposing) {
      throw new StateError("Cannot $op with disposed ReferenceCache");
    }
  }
}
