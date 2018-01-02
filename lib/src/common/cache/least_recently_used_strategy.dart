import 'dart:async';
import 'dart:collection';

import 'package:w_common/cache.dart';

/// A [CachingStrategy] that will hold the last n most recently used [TValue]s.
///
/// When n = 0 the strategy will remove a [TIdentifier] [TValue] pair immediately
/// on release.
class LeastRecentlyUsedStrategy<TIdentifier, TValue>
    extends CachingStrategy<TIdentifier, TValue> {
  final Queue<TIdentifier> _removalQueue = new Queue<TIdentifier>();

  /// The number of recently used [TIdentifier] [TValue] pairs to keep in the
  /// cache before removing the least recently used pair form the cache.
  final int _keep;

  LeastRecentlyUsedStrategy(this._keep) {
    if (_keep < 0) {
      throw new ArgumentError(
          'Cannot keep a negative number of most recently used items in the cache');
    }
  }

  @override
  Future<Null> onDidRelease(
      TIdentifier id, TValue value, Future<Null> remove(TIdentifier id)) async {
    while (_removalQueue.length > _keep) {
      await remove(_removalQueue.removeLast());
    }
  }

  @override
  Future<Null> onDidRemove(TIdentifier id, TValue value) async {
    _removalQueue.remove(id);
  }

  @override
  void onWillGet(TIdentifier id) {
    _removalQueue.remove(id);
  }

  @override
  void onWillRelease(TIdentifier id) {
    if (!_removalQueue.contains(id)) {
      _removalQueue.addFirst(id);
    }
  }
}
