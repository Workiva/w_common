import 'dart:async';
import 'dart:collection';

import 'package:w_common/cache.dart';

/// A [CachingStrategy] that will hold the last n most recently used [TValue]s.
///
/// When n = 0 the strategy will remove a [TIdentifier] [TValue] pair immediately
/// on release.
class LeastRecentlyUsedStrategy<TIdentifier, TValue>
    extends CachingStrategy<TIdentifier, TValue> {
  /// [TIdentifier]s that have been released but not yet removed in order of most
  /// to least recently used.
  final Queue<TIdentifier> _removalQueue = new Queue<TIdentifier>();

  /// The number of recently used [TIdentifier] [TValue] pairs to keep in the
  /// cache before removing the least recently used pair from the cache.
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
    // If there are more than _keep items in the queue remove the least recently
    // used.
    while (_removalQueue.length > _keep) {
      await remove(_removalQueue.removeLast());
    }
  }

  @override
  void onWillGet(TIdentifier id) {
    // A get has been called for id, removing it is now unnecessary.
    _removalQueue.remove(id);
  }

  @override
  void onWillRelease(TIdentifier id) {
    // id has been released, add it to the front of the removal queue. If
    // necessary, the least recently used items will be removed in onDidRemove
    // which the cache will call after any pending async value factory
    // associated with id completes. Items are added to the removal queue in
    // onWillRelease rather than onDidRelease to allow a get called before an
    // async value factory completes to cancel an unnecessary removal.
    if (!_removalQueue.contains(id)) {
      _removalQueue.addFirst(id);
    }
  }

  @override
  void onWillRemove(TIdentifier id) {
    // id will be removed, removing it again is unnecessary.
    _removalQueue.remove(id);
  }
}
