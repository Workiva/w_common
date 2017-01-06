import 'dart:async';

import 'package:test/test.dart';

import 'package:w_common/src/cache/cache.dart';

void main() {
  group('Cache', () {
    Cache<String, Object> cache;
    CacheEvents<String, Object> cacheEvents;
    final String cachedId = '1';
    final Object cachedValue = new Object();
    final String notCachedId = '2';
    final Object notCachedValue = new Object();
    final String putId = '3';
    final Object putValue = new Object();

    setUp(() async {
      cache = new Cache();
      await cache.get(cachedId, () => cachedValue);

      cacheEvents = new CacheEvents(cache);
    });

    group('get', () {
      test('should return cached value when identifier is cached', () async {
        var value = await cache.get(cachedId, () => notCachedValue);
        expect(value, same(cachedValue));
      });

      test(
          'should return same value when called successively '
          'synchronously', () async {
        var cachedValues = <Future<Object>>[
          cache.get(notCachedId, () => notCachedValue),
          cache.get(notCachedId, () => new Object())
        ];
        var completedValues = await Future.wait(cachedValues);
        expect(completedValues[0], same(notCachedValue));
        expect(completedValues[1], same(notCachedValue));
      });

      test('should return factory value when identifier is not cached',
          () async {
        var value = await cache.get(notCachedId, () => notCachedValue);
        expect(value, same(notCachedValue));
      });

      test('should call valueFactory if identifier is not cached', () async {
        var didCallValueFactory = false;
        await cache.get(notCachedId, () {
          didCallValueFactory = true;
          return notCachedValue;
        });
        expect(didCallValueFactory, isTrue);
      });

      test('should not call valueFactory if identifier is cached', () async {
        var didCallValueFactory = false;
        await cache.get(cachedId, () {
          didCallValueFactory = true;
          return notCachedValue;
        });
        expect(didCallValueFactory, isFalse);
      });

      test('should not dispatch didUpdate event on cached get', () async {
        cache.didUpdate
            .listen(expectAsync1((CacheContext context) {}, count: 0));
        await cache.get(cachedId, () => new Object());
      });

      test('should dispatch didUpdate event on uncached get', () async {
        cache.didUpdate.listen(expectAsync1((CacheContext context) {
          expect(context.id, notCachedId);
          expect(context.value, notCachedValue);
        }));
        await cache.get(notCachedId, () => notCachedValue);
      });

      test('should call onGet when value is not cached', () async {
        ChildCache childCache = new ChildCache();
        await childCache.get(cachedId, () => cachedValue);
        expect(childCache.onGetId, cachedId);
        expect(childCache.onGetValue, cachedValue);
      });

      test('should call onGet when value is cached', () async {
        ChildCache childCache = new ChildCache();
        await childCache.put(putId, putValue);
        await childCache.get(putId, () => notCachedValue);
        expect(childCache.onGetId, putId);
        expect(childCache.onGetValue, putValue);
      });

      test('should throw when disposed', () async {
        await cache.dispose();
        expect(() => cache.get(cachedId, () => cachedValue), throwsStateError);
      });
    });

    group('containsKey', () {
      test('should return false when identifier has not been cached', () {
        expect(cache.containsKey(notCachedId), isFalse);
      });

      test('should return true when identifier has been cached', () {
        expect(cache.containsKey(cachedId), isTrue);
      });

      test('should return false when identifier has been removed', () async {
        await cache.remove(cachedId);
        expect(cache.containsKey(cachedId), isFalse);
      });

      test('should throw when disposed', () async {
        await cache.dispose();
        expect(
            () => cache.get(cachedId, () => notCachedValue), throwsStateError);
      });
    });

    group('put', () {
      test('should update cache', () async {
        await cache.put(putId, putValue);
        final getValue = await cache.get(putId, () => null);
        expect(getValue, same(putValue));
      });

      test('should call onPut', () async {
        final ChildCache childCache = new ChildCache();

        await childCache.put(putId, putValue);
        expect(childCache.onPutId, putId);
        expect(childCache.onPutValue, putValue);
      });

      test('should put synchronously', () {
        final getA = cache.getAsync(notCachedId, () async {
          await new Future.delayed(new Duration(milliseconds: 100));
          return notCachedValue;
        });

        final put = cache.put(notCachedId, putValue);
        final getB = cache.get(notCachedId, () => new Object());

        getA.then(expectAsync1(
            (Object value) => expect(value, same(notCachedValue))));
        getB.then(
            expectAsync1((Object value) => expect(value, same(putValue))));
        put.then(expectAsync1((Object value) => expect(value, same(putValue))));
      });

      test('should throw when disposed', () async {
        await cache.dispose();
        expect(() => cache.put(putId, null), throwsStateError);
      });
    });

    group('remove', () {
      test('should dispatch one didUpdate event when identifier is removed',
          () async {
        cache.didUpdate.listen(expectAsync1((CacheContext context) {
          expect(context.id, cachedId);
          expect(context.value, isNull);
        }, count: 1));
        await cache.remove(cachedId);
        await cache.remove(cachedId);
      });

      test(
          'should dispatch one didUpdate event when identifier is removed '
          'synchronously', () {
        cache.didUpdate.listen(expectAsync1((CacheContext context) {
          expect(context.id, cachedId);
          expect(context.value, isNull);
        }, count: 1));
        cache.remove(cachedId);
        cache.remove(cachedId);
      });

      test('should dispatch one didRemove event when identifier is removed',
          () async {
        cache.didRemove.listen(expectAsync1((CacheContext context) {
          expect(context.id, cachedId);
          expect(context.value, cachedValue);
        }, count: 1));
        await cache.remove(cachedId);
        await cache.remove(cachedId);
      });

      test(
          'should dispatch one didRemove event when identifier is removed '
          'synchronously', () {
        cache.didRemove.listen(expectAsync1((CacheContext context) {
          expect(context.id, cachedId);
          expect(context.value, cachedValue);
        }, count: 1));
        cache.remove(cachedId);
        cache.remove(cachedId);
      });

      test('should not dispatch didUpdate event when identifier is not cached',
          () async {
        cache.didUpdate.listen(expectAsync1((CacheContext _) {}, count: 0));
        await cache.remove(notCachedId);
      });

      test('should call onRemove when value was cached', () async {
        ChildCache childCache = new ChildCache();
        await childCache.get(cachedId, () => cachedValue);
        await childCache.remove(cachedId);
        expect(childCache.onRemoveId, cachedId);
        expect(childCache.onRemoveValue, cachedValue);
      });

      test('should not call onRemove when identifer is not cached', () async {
        ChildCache childCache = new ChildCache();
        await childCache.remove(cachedId);
        expect(childCache.onRemoveId, isNull);
        expect(childCache.onRemoveValue, isNull);
      });

      test('should remove after pending get if called synchronously', () {
        cache.get(notCachedId, () => notCachedValue);
        cache.remove(notCachedId).then(expectAsync1((Null _) {
          expect(cacheEvents.ids, [notCachedId, notCachedId]);
          expect(cacheEvents.values, [notCachedValue, null]);
        }));
      });

      test('should remove after pending getAsync if called synchronously', () {
        cache.getAsync(notCachedId, () async {
          await new Future.delayed(new Duration(milliseconds: 100));
          return notCachedValue;
        });
        cache.remove(notCachedId).then(expectAsync1((Null _) {
          expect(cacheEvents.ids, [notCachedId, notCachedId]);
          expect(cacheEvents.values, [notCachedValue, null]);
        }));
      });

      test('should remove after pending put if called synchronously', () {
        cache.put(putId, putValue);
        cache.remove(putId).then(expectAsync1((Null _) {
          expect(cacheEvents.ids, [putId, putId]);
          expect(cacheEvents.values, [putValue, null]);
        }));
      });

      test('should throw when disposed', () async {
        await cache.dispose();
        expect(() => cache.remove(cachedId), throwsStateError);
      });
    });
  });
}

class CacheEvents<TIdentifier, TValue> {
  final Cache<TIdentifier, TValue> _cache;
  List<TIdentifier> _ids = <TIdentifier>[];
  List<TValue> _values = <TValue>[];

  CacheEvents(this._cache) {
    _cache.didUpdate.listen((CacheContext<TIdentifier, TValue> context) {
      _ids.add(context.id);
      _values.add(context.value);
    });
  }

  Iterable<TIdentifier> get ids => _ids;

  Iterable<TValue> get values => _values;
}

class ChildCache extends Cache<String, Object> {
  String onGetId;
  Object onGetValue;
  String onPutId;
  Object onPutValue;
  String onRemoveId;
  Object onRemoveValue;

  @override
  Future<Null> onGet(String id, Object value) async {
    onGetId = id;
    onGetValue = value;
  }

  @override
  Future<Null> onRemove(String id, Object value) async {
    onRemoveId = id;
    onRemoveValue = value;
  }

  @override
  Future<Null> onPut(String id, Object value) async {
    onPutId = id;
    onPutValue = value;
  }
}
