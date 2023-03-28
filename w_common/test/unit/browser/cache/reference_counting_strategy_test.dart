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

import 'package:test/test.dart';
import 'package:w_common/src/common/cache/cache.dart';
import 'package:w_common/src/common/cache/reference_counting_strategy.dart';

void main() {
  group('ReferenceCountingStrategy', () {
    late Cache<String, Object?> cache;
    late ReferenceCountingStrategy<String, Object> referenceCountingStrategy;
    const String cachedId = '1';
    final Object cachedValue = Object();
    const String notCachedId = '2';

    setUp(() async {
      referenceCountingStrategy = ReferenceCountingStrategy();
      cache = Cache(referenceCountingStrategy);
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
        cache.didUpdate.listen(
            expectAsync1((CacheContext<dynamic, dynamic> _) {}, count: 0));
        await cache.get(cachedId, () => cachedValue);
        expect(referenceCountingStrategy.referenceCount(cachedId), 2);
        await cache.release(cachedId);
      });

      test(
          'should remove identifier from cache when last reference '
          'is released', () async {
        cache.didUpdate
            .listen(expectAsync1((CacheContext<dynamic, dynamic> context) {
          expect(context.id, cachedId);
          expect(context.value, null);
        }));
        await cache.release(cachedId);
      });

      test(
          'should remove identifier from cache when last reference '
          'is released', () async {
        cache.didUpdate
            .listen(expectAsync1((CacheContext<dynamic, dynamic> context) {
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
