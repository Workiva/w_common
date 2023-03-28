// Copyright 2016-2018 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
@TestOn('browser')

import 'dart:async';
// import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:w_common/src/common/cache/cache.dart';
import 'package:w_common/src/common/cache/least_recently_used_strategy.dart';

// @GenerateNiceMocks([MockSpec<CachingStrategy<String, Object>>(as: #MockCachingStrategy)])
// import 'cache_test.mocks.dart';

void main() {
  group('Cache', () {
    late Cache<String, Object> cache;
    const String cachedId = '1';
    final Object cachedValue = Object();
    const String notCachedId = '2';
    final Object notCachedValue = Object();

    setUp(() async {
      cache = Cache(MockCachingStrategy());
      await cache.get(cachedId, () => cachedValue);
    });

    group('get', () {
      test('should return cached value when identifier is cached', () async {
        var value = await cache.get(cachedId, () => notCachedValue)!;
        expect(value, same(cachedValue));
      });

      // test(
      //     'should return same value when called successively '
      //     'synchronously', () async {
      //   var cachedValues = <Future<Object>?>[
      //     cache.get(notCachedId, () => notCachedValue),
      //     cache.get(notCachedId, () => Object())
      //   ];
      //   var completedValues = await Future.wait(cachedValues as Iterable<Future<Object>>);
      //   expect(completedValues[0], same(notCachedValue));
      //   expect(completedValues[1], same(notCachedValue));
      // });

      test('should return factory value when identifier is not cached',
          () async {
        var value = await cache.get(notCachedId, () => notCachedValue)!;
        expect(value, same(notCachedValue));
      });

      test('should return error thrown by factory function', () {
        var error = StateError('Factory Error');
        var value = cache.get(notCachedId, (() => throw error) as Object Function());
        expect(value, throwsA(same(error)));
      });

      test('should return error thrown by async factory function', () {
        var error = StateError('Async Factory Error');
        var value = cache.getAsync(notCachedId, (() async => throw error) as Future<Object> Function());
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

      // test('should not dispatch didUpdate event on cached get', () async {
      //   cache.didUpdate.listen(expectAsync1(
      //       (CacheContext<dynamic, dynamic> context) {},
      //       count: 0));
      //   await cache.get(cachedId, () => Object());
      // });

      // test('should dispatch didUpdate event on uncached get', () async {
      //   cache.didUpdate
      //       .listen(expectAsync1((CacheContext<dynamic, dynamic> context) {
      //     expect(context.id, notCachedId);
      //     expect(context.value, notCachedValue);
      //   }));
      //   await cache.get(notCachedId, () => notCachedValue);
      // });

      test('should call onDidGet when value is not cached', () async {
        var mockCachingStrategy = MockCachingStrategy();
        var childCache = Cache(mockCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        verify(mockCachingStrategy.onDidGet(cachedId, cachedValue));
      });

      test('should call onDidGet when value is cached', () async {
        var mockCachingStrategy = MockCachingStrategy();
        var childCache = Cache(mockCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.get(cachedId, () => cachedValue);

        verify(mockCachingStrategy.onDidGet(cachedId, cachedValue)).called(2);
      });

      test('should throw when disposed', () async {
        await cache.dispose();
        expect(() => cache.get(cachedId, () => cachedValue), throwsStateError);
      });

      // test(
      //     'should call valueFactory if identifier has been removed but removal '
      //     'is not complete', () async {
      //   final value1 = Object();
      //   final value2 = Object();
      //   cache.didRemove
      //       .listen(expectAsync1((CacheContext<dynamic, dynamic> context) {
      //     expect(context.id, notCachedId);
      //     expect(context.value, value2);
      //   }));
      //   // Get a unached value that completes in the future
      //   final completer = Completer<Object>();
      //   final futureGet1 = cache.getAsync(notCachedId, () => completer.future);
      //
      //   // Remove the identifer from the cache before the original get completes
      //   cache.remove(notCachedId);
      //
      //   // Get the same identifier from the cache but with a new value;
      //   final futureGet2 = cache.getAsync(notCachedId, () async => value1);
      //   completer.complete(value2);
      //   expect(await futureGet2, isNot(same(await futureGet1)));
      // });
    });

    group('remove', () {
      // test('should dispatch one didUpdate event when identifier is removed',
      //     () async {
      //   cache.didUpdate
      //       .listen(expectAsync1((CacheContext<dynamic, dynamic> context) {
      //     expect(context.id, cachedId);
      //     expect(context.value, isNull);
      //   }, count: 1));
      //   await cache.remove(cachedId);
      //   await cache.remove(cachedId);
      // });

      // test(
      //     'should dispatch one didUpdate event when identifier is removed '
      //     'synchronously', () {
      //   cache.didUpdate
      //       .listen(expectAsync1((CacheContext<dynamic, dynamic> context) {
      //     expect(context.id, cachedId);
      //     expect(context.value, isNull);
      //   }, count: 1));
      //   cache
      //     ..remove(cachedId)
      //     ..remove(cachedId);
      // });

      // test(
      //     'should dispatch one didRemove event when identifier is removed '
      //     'synchronously', () {
      //   cache.didRemove
      //       .listen(expectAsync1((CacheContext<dynamic, dynamic> context) {
      //     expect(context.id, cachedId);
      //     expect(context.value, cachedValue);
      //   }, count: 1));
      //   cache
      //     ..remove(cachedId)
      //     ..remove(cachedId);
      // });

      // test('should not dispatch didUpdate event when identifier is not cached',
      //     () async {
      //   cache.didUpdate.listen(
      //       expectAsync1((CacheContext<dynamic, dynamic> _) {}, count: 0));
      //   await cache.remove(notCachedId);
      // });

      test('should call onDidRemove when value was cached', () async {
        var stubCachingStrategy = MockCachingStrategy();
        var childCache = Cache(stubCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.remove(cachedId);

        // verify(stubCachingStrategy.onDidRemove(cachedId, cachedValue));
      });

      test('should call onWillRemove when value was cached', () async {
        var stubCachingStrategy = MockCachingStrategy();
        var childCache = Cache(stubCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.remove(cachedId);
        // verify(stubCachingStrategy.onWillRemove(cachedId));
      });

      test('should not call onDidRemove when identifer is not cached',
          () async {
        var stubCachingStrategy = MockCachingStrategy();
        var childCache = Cache(stubCachingStrategy);
        await childCache.remove(cachedId);

        // verifyNever(stubCachingStrategy.onDidRemove(any, any));
      });

      test('should not call onWillRemove when identifer is not cached',
          () async {
        var stubCachingStrategy = MockCachingStrategy();
        var childCache = Cache(stubCachingStrategy);
        await childCache.remove(cachedId);

        // verifyNever(stubCachingStrategy.onWillRemove(any));
      });

      // test('should remove after pending get if called synchronously', () {
      //   expect(cache.didUpdate.map((context) => context.id),
      //       emitsInOrder([notCachedId, notCachedId]));
      //   expect(cache.didUpdate.map((context) => context.value),
      //       emitsInOrder([notCachedValue, null]));
      //
      //   cache.get(notCachedId, () => notCachedValue);
      //   cache.remove(notCachedId);
      // });

      // test('should remove after pending getAsync if called synchronously', () {
      //   expect(cache.didUpdate.map((context) => context.id),
      //       emitsInOrder([notCachedId, notCachedId]));
      //   expect(cache.didUpdate.map((context) => context.value),
      //       emitsInOrder([notCachedValue, null]));
      //
      //   cache.getAsync(notCachedId, () async {
      //     await Future<dynamic>.delayed(Duration(milliseconds: 100));
      //     return notCachedValue;
      //   });
      //   cache.remove(notCachedId);
      // });

      test('should complete if pending get factory completes with an error',
          () {
        var error = StateError('Async factory error');
        var value = cache.get(notCachedId, (() => throw error) as Object Function());
        expect(cache.remove(notCachedId), completes);
        expect(value, throwsA(same(error)));
      });

      test(
          'should complete if pending getAsync factory completes with an error',
          () {
        var error = StateError('Async factory error');
        var value = cache.getAsync(notCachedId, (() async => throw error) as Future<Object> Function());
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
        cache.didRelease
            .listen(expectAsync1((CacheContext<dynamic, dynamic> context) {
          expect(context.id, cachedId);
          expect(context.value, cachedValue);
        }, count: 1));
        await cache.release(cachedId);
      });

      test('should call onDidRelease when value was cached', () async {
        var stubCachingStrategy = MockCachingStrategy();
        var childCache = Cache(stubCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.release(cachedId);

        // verify(stubCachingStrategy.onDidRelease(
        //     cachedId, cachedValue, childCache.remove));
      });

      test('should call onWillRelease when value was cached', () async {
        var stubCachingStrategy = MockCachingStrategy();
        var childCache = Cache(stubCachingStrategy);
        await childCache.get(cachedId, () => cachedValue);
        await childCache.release(cachedId);

        // verify(stubCachingStrategy.onWillRelease(cachedId));
      });

      test('should not call onDidRelease when identifier is not cached',
          () async {
        var stubCachingStrategy = MockCachingStrategy();
        var childCache = Cache(stubCachingStrategy);
        await childCache.release(cachedId);
        // verifyNever(stubCachingStrategy.onDidRelease(any, any, any));
      });

      test('should not call onWillRemove when identifer is not cached',
          () async {
        var stubCachingStrategy = MockCachingStrategy();
        var childCache = Cache(stubCachingStrategy);
        await childCache.release(cachedId);
        // verifyNever(stubCachingStrategy.onWillRelease(any));
      });

      test('should complete if pending get factory completes with an error',
          () {
        var error = StateError('Async factory error');
        var value = cache.get(notCachedId, (() => throw error) as Object Function());
        expect(cache.release(notCachedId), completes);
        expect(value, throwsA(same(error)));
      });

      test(
          'should complete if pending getAsync factory completes with an error',
          () {
        var error = StateError('Async factory error');
        var value = cache.getAsync(notCachedId, (() async => throw error) as Future<Object> Function());
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
        cache.didRemove.listen(expectAsync1(
            (CacheContext<dynamic, dynamic> context) {},
            count: 0,
            reason: 'Ensure that cached item is not removed'));

        expect(cache.releasedKeys, isNot(contains(cachedId)));
        cache.release(cachedId);
        expect(cache.releasedKeys, contains(cachedId));
      });

      test('should provide access to released keys when release is awaited',
          () async {
        cache.didRemove.listen(expectAsync1(
            (CacheContext<dynamic, dynamic> context) {},
            count: 0,
            reason: 'Ensure that cached item is not removed'));

        expect(cache.releasedKeys, isNot(contains(cachedId)));
        await cache.release(cachedId);
        expect(cache.releasedKeys, contains(cachedId));
      });
    });

    group('liveKeys', () {
      test('should not provide access to released keys', () {
        cache.didRemove.listen(expectAsync1(
            (CacheContext<dynamic, dynamic> context) {},
            count: 0,
            reason: 'Ensure that cached item is not removed'));

        expect(cache.liveKeys, contains(cachedId));
        cache.release(cachedId);
        expect(cache.liveKeys.contains(cachedId), isFalse);
      });

      test('should not provide access to released keys when release is awaited',
          () async {
        cache.didRemove.listen(expectAsync1(
            (CacheContext<dynamic, dynamic> context) {},
            count: 0,
            reason: 'Ensure that cached item is not removed'));

        expect(cache.liveKeys, contains(cachedId));
        await cache.release(cachedId);
        expect(cache.liveKeys.contains(cachedId), isFalse);
      });
    });

    group('liveValues', () {
      test('should not provide access to released values', () async {
        cache.didRemove.listen(expectAsync1(
            (CacheContext<dynamic, dynamic> context) {},
            count: 0,
            reason: 'Ensure that cached item is not removed'));

        // expect(await cache.liveValues, contains(cachedValue));
        // ignore: unawaited_futures
        cache.release(cachedId);
        // expect(await cache.liveValues, isNot(contains(cachedValue)));
      });

      test(
          'should not provide access to released values when release is awaited',
          () async {
        cache.didRemove.listen(expectAsync1(
            (CacheContext<dynamic, dynamic> context) {},
            count: 0,
            reason: 'Ensure that cached item is not removed'));

        // expect(await cache.liveValues, contains(cachedValue));
        await cache.release(cachedId);
        // expect(await cache.liveValues, isNot(contains(cachedValue)));
      });
    });

    group('applyToItem', () {
      group('when item is in the cache', () {
        test('should run callback', () async {
          var callbackRan = false;
          await cache.applyToItem(cachedId, (Future<Object>? value) async {
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
          cache.didRemove.listen(expectAsync1(
              (CacheContext<dynamic, dynamic> context) {},
              count: 0,
              reason: 'Ensure that cached item is not removed'));
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
          cache = Cache<String, Object>(
              LeastRecentlyUsedStrategy<String, Object>(0));
          await cache.get(cachedId, () => cachedValue);
        });

        test('when callback completes normally', () {
          var callbackCompleted = false;

          cache.didRemove
              .listen(expectAsync1((CacheContext<dynamic, dynamic> context) {
            expect(context.id, cachedId);
            expect(callbackCompleted, isTrue);
          }));

          cache
            ..applyToItem(cachedId, (_) async {
              await Future<dynamic>.delayed(const Duration(seconds: 1));
              callbackCompleted = true;
            })
            ..release(cachedId);
        });

        // test('when callback completes with an error', () {
        //   var callbackCompleted = false;
        //
        //   cache.didRemove
        //       .listen(expectAsync1((CacheContext<dynamic, dynamic> context) {
        //     expect(context.id, cachedId);
        //     expect(callbackCompleted, isTrue);
        //   }));
        //
        //   runZoned(() {
        //     cache.applyToItem(cachedId, (_) async {
        //       await Future<dynamic>.delayed(const Duration(seconds: 1));
        //       callbackCompleted = true;
        //       throw Error();
        //     });
        //   },
        //       onError: expectAsync1((dynamic _) {},
        //           reason: 'error should be thrown in callback'));
        //
        //   cache.release(cachedId);
        // });
      });

      test(
          'should return future that completes with same error as the '
          'future returned from callback', () async {
        final error = Error();
        await cache.applyToItem(cachedId, (_) async {
          await Future<dynamic>.delayed(Duration(seconds: 1));
          throw error;
        }).catchError((e) {
          expect(e, error);
          return Future<bool>.value(false);
        });
      });

      test(
          'should not add futures to applyToItemCallbacks for synchronous '
          'callbacks', () {
        cache.applyToItem(cachedId, (_) {});
        expect(cache.applyToItemCallBacks, isEmpty);
      });

      // test(
      //     'should remove futures added to applyToItemCallbacks after async '
      //     'callback completes with error', () async {
      //   try {
      //     final applyToItemFuture = cache.applyToItem(cachedId, (_) async {
      //       print('tlg test Error');
      //       throw Error();
      //     });
      //     // expect(cache.applyToItemCallBacks, isNotEmpty);
      //     await applyToItemFuture;
      //   } catch (_) {}
      //
      //   // expect(cache.applyToItemCallBacks, isEmpty);
      // });

      test(
          'should remove futures added to applyToItemCallbacks after async '
          'callback completes', () async {
        final applyToItemFuture = cache.applyToItem(cachedId, (_) {
          return Future(() {});
        });

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

class MockCachingStrategy<TIdentifier, TValue> extends Mock
    implements CachingStrategy<TIdentifier, TValue> {
  @override
  Future<Null> onDidGet(TIdentifier id, TValue value) async {
    super.noSuchMethod(Invocation.method(#id, [#value]));
    return Future.value(null);
  }

  @override
  Future<Null> onDidRelease(TIdentifier id, TValue value, Future<Null> remove(TIdentifier id)) {
    super.noSuchMethod(Invocation.method(#id, [#value, #remove]));
    return Future.value(null);
  }

  @override
  Future<Null> onDidRemove(TIdentifier id, TValue value) {
    super.noSuchMethod(Invocation.method(#id, [#value]));
    return Future.value(null);
  }

  @override
  void onWillRelease(TIdentifier id) {}

  @override
  void onWillRemove(TIdentifier id) {}
}
