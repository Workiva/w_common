import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:w_common/src/common/cache/cache.dart';

void main() {
  group('Cache', () {
    Cache<String, Object> cache;
    final String cachedId = '1';
    final Object cachedValue = new Object();
    final String notCachedId = '2';
    final Object notCachedValue = new Object();

    setUp(() async {
      cache = new Cache(new MockCachingStrategy());
      await cache.get(cachedId, () => cachedValue);
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

      test('should return error thrown by factory function', () {
        var error = new StateError('Factory Error');
        var value = cache.get(notCachedId, () => throw error);
        expect(value, throwsA(same(error)));
      });

      test('should return error thrown by async factory function', () {
        var error = new StateError('Async Factory Error');
        var value = cache.getAsync(notCachedId, () async => throw error);
        expect(value, throwsA(same(error)));
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

      test('should call onDidGet when value is not cached', () async {
        var mockCachingStrategy = new MockCachingStrategy();
        var childCache = new Cache(mockCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);

        verify(mockCachingStrategy.onDidGet(cachedId, cachedValue));
      });

      test('should call onDidGet when value is cached', () async {
        var mockCachingStrategy = new MockCachingStrategy();
        var childCache = new Cache(mockCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.get(cachedId, () => cachedValue);

        verify(mockCachingStrategy.onDidGet(cachedId, cachedValue)).called(2);
      });

      test('should throw when disposed', () async {
        await cache.dispose();
        expect(() => cache.get(cachedId, () => cachedValue), throwsStateError);
      });

      test(
          'should call valueFactory if identifer has been removed but removal '
          'is not complete', () async {
        final value1 = new Object();
        final value2 = new Object();
        cache.didRemove.listen(expectAsync1((CacheContext context) {
          expect(context.id, notCachedId);
          expect(context.value, value2);
        }));
        // Get a unached value that completes in the future
        final completer = new Completer<Object>();
        final futureGet1 = cache.getAsync(notCachedId, () => completer.future);

        // Remove the identifer from teh cache before the original get completes
        cache.remove(notCachedId);

        // Get the same identifier from the cache but with a new value;
        final futureGet2 = cache.getAsync(notCachedId, () async => value1);
        completer.complete(value2);
        expect(await futureGet2, isNot(same(await futureGet1)));
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

      test(
          'should return false when identifer has been removed before get '
          'completes', () async {
        final completer = new Completer<Object>();
        cache.getAsync(notCachedId, () => completer.future);
        expect(cache.containsKey(notCachedId), isTrue);
        cache.remove(notCachedId);
        expect(cache.containsKey(notCachedId), isFalse);
      });

      test('should throw when disposed', () async {
        await cache.dispose();
        expect(
            () => cache.get(cachedId, () => notCachedValue), throwsStateError);
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
        cache..remove(cachedId)..remove(cachedId);
      });

      test(
          'should dispatch one didRemove event when identifier is removed '
          'synchronously', () {
        cache.didRemove.listen(expectAsync1((CacheContext context) {
          expect(context.id, cachedId);
          expect(context.value, cachedValue);
        }, count: 1));
        cache..remove(cachedId)..remove(cachedId);
      });

      test('should not dispatch didUpdate event when identifier is not cached',
          () async {
        cache.didUpdate.listen(expectAsync1((CacheContext _) {}, count: 0));
        await cache.remove(notCachedId);
      });

      test('should call onDidRemove when value was cached', () async {
        var stubCachingStrategy = new MockCachingStrategy();
        var childCache = new Cache(stubCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.remove(cachedId);
        verify(stubCachingStrategy.onDidRemove(cachedId, cachedValue));
      });

      test('should call onWillRemove when value was cached', () async {
        var stubCachingStrategy = new MockCachingStrategy();
        var childCache = new Cache(stubCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.remove(cachedId);
        verify(stubCachingStrategy.onWillRemove(cachedId));
      });

      test('should not call onDidRemove when identifer is not cached',
          () async {
        var stubCachingStrategy = new MockCachingStrategy();
        var childCache = new Cache(stubCachingStrategy);
        await childCache.remove(cachedId);
        verifyNever(stubCachingStrategy.onDidRemove(typed(any), typed(any)));
      });

      test('should not call onWillRemove when identifer is not cached',
          () async {
        var stubCachingStrategy = new MockCachingStrategy();
        var childCache = new Cache(stubCachingStrategy);
        await childCache.remove(cachedId);
        verifyNever(stubCachingStrategy.onWillRemove(typed(any)));
      });

      test('should remove after pending get if called synchronously', () {
        expect(cache.didUpdate.map((context) => context.id),
            emitsInOrder([notCachedId, notCachedId]));
        expect(cache.didUpdate.map((context) => context.value),
            emitsInOrder([notCachedValue, null]));

        cache.get(notCachedId, () => notCachedValue);
        cache.remove(notCachedId);
      });

      test('should remove after pending getAsync if called synchronously', () {
        expect(cache.didUpdate.map((context) => context.id),
            emitsInOrder([notCachedId, notCachedId]));
        expect(cache.didUpdate.map((context) => context.value),
            emitsInOrder([notCachedValue, null]));

        cache.getAsync(notCachedId, () async {
          await new Future.delayed(new Duration(milliseconds: 100));
          return notCachedValue;
        });
        cache.remove(notCachedId);
      });

      test('should complete if pending get factory completes with an error',
          () {
        var error = new StateError('Async factory error');
        var value = cache.get(notCachedId, () => throw error);
        expect(cache.remove(notCachedId), completes);
        expect(value, throwsA(same(error)));
      });

      test(
          'should complete if pending getAsync factory completes with an error',
          () {
        var error = new StateError('Async factory error');
        var value = cache.getAsync(notCachedId, () async => throw error);
        expect(cache.remove(notCachedId), completes);
        expect(value, throwsA(same(error)));
      });

      test('should throw when disposed', () async {
        await cache.dispose();
        expect(() => cache.remove(cachedId), throwsStateError);
      });
    });

    group('release', () {
      test('should dispatch one didRelease event when identifier is released',
          () async {
        cache.didRelease.listen(expectAsync1((CacheContext context) {
          expect(context.id, cachedId);
          expect(context.value, cachedValue);
        }, count: 1));
        await cache.release(cachedId);
      });

      test('should call onDidRelease when value was cached', () async {
        var stubCachingStrategy = new MockCachingStrategy();
        var childCache = new Cache(stubCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.release(cachedId);
        verify(stubCachingStrategy.onDidRelease(
            cachedId, cachedValue, childCache.remove));
      });

      test('should call onWillRelease when value was cached', () async {
        var stubCachingStrategy = new MockCachingStrategy();
        var childCache = new Cache(stubCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.release(cachedId);
        verify(stubCachingStrategy.onWillRelease(cachedId));
      });

      test('should not call onDidRelease when identifer is not cached',
          () async {
        var stubCachingStrategy = new MockCachingStrategy();
        var childCache = new Cache(stubCachingStrategy);
        await childCache.release(cachedId);
        verifyNever(stubCachingStrategy.onDidRelease(
            typed(any), typed(any), typed(any)));
      });

      test('should not call onWillRemove when identifer is not cached',
          () async {
        var stubCachingStrategy = new MockCachingStrategy();
        var childCache = new Cache(stubCachingStrategy);
        await childCache.release(cachedId);
        verifyNever(stubCachingStrategy.onWillRelease(typed(any)));
      });

      test('should complete if pending get factory completes with an error',
          () {
        var error = new StateError('Async factory error');
        var value = cache.get(notCachedId, () => throw error);
        expect(cache.release(notCachedId), completes);
        expect(value, throwsA(same(error)));
      });

      test(
          'should complete if pending getAsync factory completes with an error',
          () {
        var error = new StateError('Async factory error');
        var value = cache.getAsync(notCachedId, () async => throw error);
        expect(cache.release(notCachedId), completes);
        expect(value, throwsA(same(error)));
      });

      test('should throw when disposed', () async {
        await cache.dispose();
        expect(() => cache.release(cachedId), throwsStateError);
      });
    });
  });
}

class MockCachingStrategy extends Mock
    implements CachingStrategy<String, Object> {
  MockCachingStrategy() {
    when(this.onDidGet(typed(any), typed(any)))
        .thenReturn(new Future.value(null));
    when(this.onDidRelease(typed(any), typed(any), typed(any)))
        .thenReturn(new Future.value(null));
    when(this.onDidRemove(typed(any), typed(any)))
        .thenReturn(new Future.value(null));
  }
}
