import 'dart:async';

import 'package:w_common/src/common/cache/cache.dart';

/// Maintains the number of references to an instance of a cache value.
class ReferenceCountingStrategy<TIdentifier, TValue>
    extends CachingStrategy<TIdentifier, TValue> {
  Map<TIdentifier, int> _count = <TIdentifier, int>{};

  int referenceCount(TIdentifier id) {
    return _count[id] ?? 0;
  }

  @override
  Future<void> onDidRelease(
      TIdentifier id, TValue value, Future<void> remove(TIdentifier id)) async {
    if (!_count.containsKey(id)) {
      return null;
    }

    if (referenceCount(id) == 0) {
      await remove(id);
    }
  }

  @override
  Future<void> onDidRemove(TIdentifier id, TValue value) async {
    _count.remove(id);
  }

  @override
  void onWillGet(TIdentifier id) {
    _count[id] = _count.putIfAbsent(id, () => 0) + 1;
  }

  @override
  void onWillRelease(TIdentifier id) {
    if (_count[id] != null && _count[id]! > 0) {
      _count[id] = _count[id]!-1;
    }
  }
}
