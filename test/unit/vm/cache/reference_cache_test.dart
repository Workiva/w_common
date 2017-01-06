import 'package:test/test.dart';

import 'package:w_common/src/cache/cache.dart';
import 'package:w_common/src/cache/reference_cache.dart';

void main() {
  group('ReferenceCache', () {
    ReferenceCache<String, Object> cache;
    final String cachedId = '1';
    final Object cachedValue = new Object();
    final String notCachedId = '2';

    setUp(() async {
      cache = new ReferenceCache();
      await cache.get(cachedId, () => cachedValue);
    });

    group('onGet', () {
      test('should increment reference count', () async {
        expect(cache.referenceCount(cachedId), 1);
        await cache.get(cachedId, () => null);
        expect(cache.referenceCount(cachedId), 2);
      });
    });

    group('onPut', () {
      test('should set reference count to 1', () async {
        await cache.get(cachedId, () => null);
        await cache.get(cachedId, () => null);
        expect(cache.referenceCount(cachedId), 3);
        await cache.put(cachedId, new Object());
        expect(cache.referenceCount(cachedId), 1);
      });
    });

    group('onRemove', () {
      test('should reset reference count to 0', () async {
        expect(cache.referenceCount(cachedId), 1);
        await cache.remove(cachedId);
        expect(cache.referenceCount(cachedId), 0);
      });
    });

    group('referenceCount', () {
      test('should return number of get calls', () async {
        expect(cache.referenceCount(cachedId), 1);
        await cache.get(cachedId, () => cachedValue);
        expect(cache.referenceCount(cachedId), 2);
      });

      test('should return zero for uncached results', () {
        expect(cache.referenceCount(notCachedId), 0);
      });
    });

    group('release', () {
      test('should not decrement referenceCount below zero', () async {
        expect(cache.referenceCount(notCachedId), 0);
        await cache.release(notCachedId);
        expect(cache.referenceCount(notCachedId), 0);
      });

      test(
          'should not remove identifier form cache when reference '
          'count is greater than 1', () async {
        cache.didUpdate.listen(expectAsync1((CacheContext _) {}, count: 0));
        await cache.get(cachedId, () => cachedValue);
        expect(cache.referenceCount(cachedId), 2);
        await cache.release(cachedId);
      });

      test(
          'should remove identifier from cache when last reference '
          'is released', () async {
        cache.didUpdate.listen((CacheContext context) {
          expect(context.id, cachedId);
          expect(context.value, null);
        });
        await cache.release(cachedId);
      });

      test('should throw StateError when disposed', () async {
        await cache.dispose();
        expect(() => cache.release(cachedId), throwsStateError);
      });
    });
  });
}
