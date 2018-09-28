import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:w_common/src/common/cache/cache.dart';
import 'package:w_common/src/common/cache/least_recently_used_strategy.dart';

void main() {
  group('Cache', () {
    Cache<String, Object> cache;
    const cachedId = '1';
    final cachedValue = new Object();
    const notCachedId = '2';
    final notCachedValue = new Object();

    setUp(() async {
      cache = new Cache(new MockCachingStrategy());
      await cache.get(cachedId, () => cachedValue);
    });

    group('get', () {
      test('should return cached value when identifier is cached', () async {
        final value = await cache.get(cachedId, () => notCachedValue);
        expect(value, same(cachedValue));
      });

      test(
          'should return same value when called successively '
          'synchronously', () async {
        final cachedValues = <Future<Object>>[
          cache.get(notCachedId, () => notCachedValue),
          cache.get(notCachedId, () => new Object())
        ];
        final completedValues = await Future.wait(cachedValues);
        expect(completedValues[0], same(notCachedValue));
        expect(completedValues[1], same(notCachedValue));
      });

      test('should return factory value when identifier is not cached',
          () async {
        final value = await cache.get(notCachedId, () => notCachedValue);
        expect(value, same(notCachedValue));
      });

      test('should return error thrown by factory function', () {
        final error = new StateError('Factory Error');
        final value = cache.get(notCachedId, () => throw error);
        expect(value, throwsA(same(error)));
      });

      test('should return error thrown by async factory function', () {
        final error = new StateError('Async Factory Error');
        final value = cache.getAsync(notCachedId, () async => throw error);
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
        cache.didUpdate.listen(expectAsync1((context) {}, count: 0));
        await cache.get(cachedId, () => new Object());
      });

      test('should dispatch didUpdate event on uncached get', () async {
        cache.didUpdate.listen(expectAsync1((context) {
          expect(context.id, notCachedId);
          expect(context.value, notCachedValue);
        }));
        await cache.get(notCachedId, () => notCachedValue);
      });

      test('should call onDidGet when value is not cached', () async {
        final mockCachingStrategy = new MockCachingStrategy();
        final childCache = new Cache(mockCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);

        verify(mockCachingStrategy.onDidGet(cachedId, cachedValue));
      });

      test('should call onDidGet when value is cached', () async {
        final mockCachingStrategy = new MockCachingStrategy();
        final childCache = new Cache(mockCachingStrategy);
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
        cache.didRemove.listen(expectAsync1((context) {
          expect(context.id, notCachedId);
          expect(context.value, value2);
        }));
        // Get a un-cached value that completes in the future
        final completer = new Completer<Object>();
        final futureGet1 = cache.getAsync(notCachedId, () => completer.future);

        // Remove the identifier from the cache before the original get completes
        // ignore: unawaited_futures
        cache.remove(notCachedId);

        // Get the same identifier from the cache but with a new value;
        final futureGet2 = cache.getAsync(notCachedId, () async => value1);
        completer.complete(value2);
        expect(await futureGet2, isNot(same(await futureGet1)));
      });
    });

    group('remove', () {
      test('should dispatch one didUpdate event when identifier is removed',
          () async {
        cache.didUpdate.listen(expectAsync1((context) {
          expect(context.id, cachedId);
          expect(context.value, isNull);
        }, count: 1));
        await cache.remove(cachedId);
        await cache.remove(cachedId);
      });

      test(
          'should dispatch one didUpdate event when identifier is removed '
          'synchronously', () {
        cache.didUpdate.listen(expectAsync1((context) {
          expect(context.id, cachedId);
          expect(context.value, isNull);
        }, count: 1));
        cache..remove(cachedId)..remove(cachedId);
      });

      test(
          'should dispatch one didRemove event when identifier is removed '
          'synchronously', () {
        cache.didRemove.listen(expectAsync1((context) {
          expect(context.id, cachedId);
          expect(context.value, cachedValue);
        }, count: 1));
        cache..remove(cachedId)..remove(cachedId);
      });

      test('should not dispatch didUpdate event when identifier is not cached',
          () async {
        cache.didUpdate.listen(expectAsync1((_) {}, count: 0));
        await cache.remove(notCachedId);
      });

      test('should call onDidRemove when value was cached', () async {
        final stubCachingStrategy = new MockCachingStrategy();
        final childCache = new Cache(stubCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.remove(cachedId);
        verify(stubCachingStrategy.onDidRemove(cachedId, cachedValue));
      });

      test('should call onWillRemove when value was cached', () async {
        final stubCachingStrategy = new MockCachingStrategy();
        final childCache = new Cache(stubCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.remove(cachedId);
        verify(stubCachingStrategy.onWillRemove(cachedId));
      });

      test('should not call onDidRemove when identifer is not cached',
          () async {
        final stubCachingStrategy = new MockCachingStrategy();
        final childCache = new Cache(stubCachingStrategy);
        await childCache.remove(cachedId);
        verifyNever(stubCachingStrategy.onDidRemove(any, any));
      });

      test('should not call onWillRemove when identifer is not cached',
          () async {
        final stubCachingStrategy = new MockCachingStrategy();
        final childCache = new Cache(stubCachingStrategy);
        await childCache.remove(cachedId);
        verifyNever(stubCachingStrategy.onWillRemove(any));
      });

      test('should remove after pending get if called synchronously', () {
        expect(cache.didUpdate.map((context) => context.id),
            emitsInOrder([notCachedId, notCachedId]));
        expect(cache.didUpdate.map((context) => context.value),
            emitsInOrder([notCachedValue, null]));

        cache
          ..get(notCachedId, () => notCachedValue)
          ..remove(notCachedId);
      });

      test('should remove after pending getAsync if called synchronously', () {
        expect(cache.didUpdate.map((context) => context.id),
            emitsInOrder([notCachedId, notCachedId]));
        expect(cache.didUpdate.map((context) => context.value),
            emitsInOrder([notCachedValue, null]));

        cache
          ..getAsync(notCachedId, () async {
            await new Future.delayed(const Duration(milliseconds: 100));
            return notCachedValue;
          })
          ..remove(notCachedId);
      });

      test('should complete if pending get factory completes with an error',
          () {
        final error = new StateError('Async factory error');
        final value = cache.get(notCachedId, () => throw error);
        expect(cache.remove(notCachedId), completes);
        expect(value, throwsA(same(error)));
      });

      test(
          'should complete if pending getAsync factory completes with an error',
          () {
        final error = new StateError('Async factory error');
        final value = cache.getAsync(notCachedId, () async => throw error);
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
        cache.didRelease.listen(expectAsync1((context) {
          expect(context.id, cachedId);
          expect(context.value, cachedValue);
        }, count: 1));
        await cache.release(cachedId);
      });

      test('should call onDidRelease when value was cached', () async {
        final stubCachingStrategy = new MockCachingStrategy();
        final childCache = new Cache(stubCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.release(cachedId);
        verify(stubCachingStrategy.onDidRelease(
            cachedId, cachedValue, childCache.remove));
      });

      test('should call onWillRelease when value was cached', () async {
        final stubCachingStrategy = new MockCachingStrategy();
        final childCache = new Cache(stubCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.release(cachedId);
        verify(stubCachingStrategy.onWillRelease(cachedId));
      });

      test('should not call onDidRelease when identifer is not cached',
          () async {
        final stubCachingStrategy = new MockCachingStrategy();
        final childCache = new Cache(stubCachingStrategy);
        await childCache.release(cachedId);
        verifyNever(stubCachingStrategy.onDidRelease(any, any, any));
      });

      test('should not call onWillRemove when identifer is not cached',
          () async {
        final stubCachingStrategy = new MockCachingStrategy();
        final childCache = new Cache(stubCachingStrategy);
        await childCache.release(cachedId);
        verifyNever(stubCachingStrategy.onWillRelease(any));
      });

      test('should complete if pending get factory completes with an error',
          () {
        final error = new StateError('Async factory error');
        final value = cache.get(notCachedId, () => throw error);
        expect(cache.release(notCachedId), completes);
        expect(value, throwsA(same(error)));
      });

      test(
          'should complete if pending getAsync factory completes with an error',
          () {
        final error = new StateError('Async factory error');
        final value = cache.getAsync(notCachedId, () async => throw error);
        expect(cache.release(notCachedId), completes);
        expect(value, throwsA(same(error)));
      });

      test('should throw when disposed', () async {
        await cache.dispose();
        expect(() => cache.release(cachedId), throwsStateError);
      });
    });

    group('releasedKeys', () {
      test('should provide access to released keys', () {
        cache.didRemove.listen(expectAsync1((context) {},
            count: 0, reason: 'Ensure that cached item is not removed'));

        expect(cache.releasedKeys, isNot(contains(cachedId)));
        cache.release(cachedId);
        expect(cache.releasedKeys, contains(cachedId));
      });

      test('should provide access to released keys when release is awaited',
          () async {
        cache.didRemove.listen(expectAsync1((context) {},
            count: 0, reason: 'Ensure that cached item is not removed'));

        expect(cache.releasedKeys, isNot(contains(cachedId)));
        await cache.release(cachedId);
        expect(cache.releasedKeys, contains(cachedId));
      });
    });

    group('liveKeys', () {
      test('should not provide access to released keys', () {
        cache.didRemove.listen(expectAsync1((context) {},
            count: 0, reason: 'Ensure that cached item is not removed'));

        expect(cache.liveKeys, contains(cachedId));
        cache.release(cachedId);
        expect(cache.liveKeys.contains(cachedId), isFalse);
      });

      test('should not provide access to released keys when release is awaited',
          () async {
        cache.didRemove.listen(expectAsync1((context) {},
            count: 0, reason: 'Ensure that cached item is not removed'));

        expect(cache.liveKeys, contains(cachedId));
        await cache.release(cachedId);
        expect(cache.liveKeys.contains(cachedId), isFalse);
      });
    });

    group('liveValues', () {
      test('should not provide access to released values', () async {
        cache.didRemove.listen(expectAsync1((context) {},
            count: 0, reason: 'Ensure that cached item is not removed'));

        expect(await cache.liveValues, contains(cachedValue));
        // ignore: unawaited_futures
        cache.release(cachedId);
        expect(await cache.liveValues, isNot(contains(cachedValue)));
      });

      test(
          'should not provide access to released values when release is awaited',
          () async {
        cache.didRemove.listen(expectAsync1((context) {},
            count: 0, reason: 'Ensure that cached item is not removed'));

        expect(await cache.liveValues, contains(cachedValue));
        await cache.release(cachedId);
        expect(await cache.liveValues, isNot(contains(cachedValue)));
      });
    });

    group('applyToItem', () {
      group('when item is in the cache', () {
        test('should run callback', () async {
          var callbackRan = false;
          await cache.applyToItem(cachedId, (value) async {
            callbackRan = true;
            expect(await value, cachedValue);
          });

          expect(callbackRan, isTrue);
        });

        test('should return true', () async {
          expect(await cache.applyToItem(cachedId, (_) {}), isTrue);
        });
      });

      group('when item is not in the cache', () {
        test('should not run callback', () {
          var callbackRan = false;
          cache.applyToItem(notCachedId, (_) {
            callbackRan = true;
          });

          expect(callbackRan, isFalse);
        });

        test('should return false', () async {
          expect(await cache.applyToItem(notCachedId, (_) {}), isFalse);
        });
      });

      group('when item is released but not yet removed from the cache', () {
        setUp(() {
          cache.didRemove.listen(expectAsync1((context) {},
              count: 0, reason: 'Ensure that cached item is not removed'));
        });

        test('should not run callback', () {
          var callbackRan = false;
          cache
            ..release(cachedId)
            ..applyToItem(cachedId, (_) {
              callbackRan = true;
            });

          expect(callbackRan, isFalse);
        });

        test('should return true', () async {
          expect(await cache.applyToItem(cachedId, (_) {}), isTrue);
        });
      });

      group(
          'should not add event to didRemove stream until callback has completed',
          () {
        setUp(() async {
          cache = new Cache<String, Object>(
              new LeastRecentlyUsedStrategy<String, Object>(0));
          await cache.get(cachedId, () => cachedValue);
        });

        test('when callback completes normally', () {
          var callbackCompleted = false;

          cache.didRemove.listen(expectAsync1((context) {
            expect(context.id, cachedId);
            expect(callbackCompleted, isTrue);
          }));

          cache
            ..applyToItem(cachedId, (_) async {
              await new Future.delayed(const Duration(seconds: 1));
              callbackCompleted = true;
            })
            ..release(cachedId);
        });

        test('when callback completes with an error', () {
          var callbackCompleted = false;

          cache.didRemove.listen(expectAsync1((context) {
            expect(context.id, cachedId);
            expect(callbackCompleted, isTrue);
          }));

          runZoned(() {
            cache.applyToItem(cachedId, (_) async {
              await new Future.delayed(const Duration(seconds: 1));
              callbackCompleted = true;
              throw new Error();
            });
          },
              onError: expectAsync1((_) {},
                  reason: 'error should be thrown in callback'));

          cache.release(cachedId);
        });
      });

      test(
          'should return future that completes with same error as the '
          'future returned from callback', () async {
        final error = new Error();
        await cache.applyToItem(cachedId, (_) async {
          await new Future.delayed(const Duration(seconds: 1));
          throw error;
        }).catchError((e) {
          expect(e, error);
        });
      });

      test(
          'should not add futures to applyToItemCallbacks for synchronous '
          'callbacks', () {
        cache.applyToItem(cachedId, (_) {});
        expect(cache.applyToItemCallBacks, isEmpty);
      });

      test(
          'should remove futures added to applyToItemCallbacks after async '
          'callback completes with error', () async {
        try {
          final applyToItemFuture = cache.applyToItem(cachedId, (_) async {
            throw new Error();
          });
          expect(cache.applyToItemCallBacks, isNotEmpty);
          await applyToItemFuture;
          // ignore: avoid_catches_without_on_clauses
        } catch (_) {}

        expect(cache.applyToItemCallBacks, isEmpty);
      });

      test(
          'should remove futures added to applyToItemCallbacks after async '
          'callback completes', () async {
        final applyToItemFuture =
            cache.applyToItem(cachedId, (_) => new Future(() {}));

        expect(cache.applyToItemCallBacks, isNotEmpty);
        await applyToItemFuture;
        expect(cache.applyToItemCallBacks, isEmpty);
      });

      test('should throw when disposed', () async {
        await cache.dispose();
        expect(() => cache.applyToItem(cachedId, (_) {}), throwsStateError);
      });
    });
  });
}

class MockCachingStrategy extends Mock
    implements CachingStrategy<String, Object> {
  MockCachingStrategy() {
    when(onDidGet(any, any)).thenAnswer((_) => new Future.value(null));
    when(onDidRelease(any, any, any)).thenAnswer((_) => new Future.value(null));
    when(onDidRemove(any, any)).thenAnswer((_) => new Future.value(null));
  }
}
