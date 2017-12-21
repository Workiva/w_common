import 'package:test/test.dart';
import 'package:w_common/src/common/cache/cache.dart';
import 'package:w_common/src/common/cache/reference_counting_strategy.dart';

void main() {
  group('ReferenceCountingStrategy', () {
    Cache<String, Object> cache;
    ReferenceCountingStrategy<String, Object> referenceCountingStrategy;
    final String cachedId = '1';
    final Object cachedValue = new Object();
    final String notCachedId = '2';

    setUp(() async {
      referenceCountingStrategy = new ReferenceCountingStrategy();
      cache = new Cache(referenceCountingStrategy);
      await cache.get(cachedId, () => cachedValue);
    });

    group('onGet', () {
      test('should increment reference count', () async {
        expect(referenceCountingStrategy.referenceCount(cachedId), 1);
        await cache.get(cachedId, () => null);
        expect(referenceCountingStrategy.referenceCount(cachedId), 2);
      });
    });

    group('onRemove', () {
      test('should reset reference count to 0', () async {
        expect(referenceCountingStrategy.referenceCount(cachedId), 1);
        await cache.remove(cachedId);
        expect(referenceCountingStrategy.referenceCount(cachedId), isNull);
      });
    });

    group('referenceCount', () {
      test('should return number of get calls', () async {
        expect(referenceCountingStrategy.referenceCount(cachedId), 1);
        await cache.get(cachedId, () => cachedValue);
        expect(referenceCountingStrategy.referenceCount(cachedId), 2);
      });

      test('should return null for uncached results', () {
        expect(referenceCountingStrategy.referenceCount(notCachedId), null);
      });
    });

    group('release', () {
      test('should not decrement referenceCount below zero', () async {
        expect(referenceCountingStrategy.referenceCount(notCachedId), isNull);
        await cache.release(notCachedId);
        expect(referenceCountingStrategy.referenceCount(notCachedId), isNull);
      });

      test(
          'should not remove identifier form cache when reference '
          'count is greater than 1', () async {
        cache.didUpdate.listen(expectAsync1((CacheContext _) {}, count: 0));
        await cache.get(cachedId, () => cachedValue);
        expect(referenceCountingStrategy.referenceCount(cachedId), 2);
        await cache.release(cachedId);
      });

      test(
          'should remove identifier from cache when last reference '
          'is released', () async {
        cache.didUpdate.listen(expectAsync1((CacheContext context) {
          expect(context.id, cachedId);
          expect(context.value, null);
        }));
        await cache.release(cachedId);
      });

      test(
          'should remove identifier from cache when last reference '
          'is released', () async {
        cache.didUpdate.listen(expectAsync1((CacheContext context) {
          expect(context.id, cachedId);
          expect(context.value, null);
        }));
        await cache.get(cachedId, () => cachedValue);
        expect(referenceCountingStrategy.referenceCount(cachedId), 2);
        await cache.release(cachedId);
        expect(referenceCountingStrategy.referenceCount(cachedId), 1);
        await cache.release(cachedId);
        expect(referenceCountingStrategy.referenceCount(cachedId), isNull);
      });

      test('should throw StateError when disposed', () async {
        await cache.dispose();
        expect(() => cache.release(cachedId), throwsStateError);
      });
    });
  });
}
