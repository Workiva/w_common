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

import 'package:test/test.dart';
import 'package:w_common/func.dart';
import 'package:w_common/src/common/cache/cache.dart';
import 'package:w_common/src/common/cache/least_recently_used_strategy.dart';
import 'package:w_common/src/common/cache/reference_counting_strategy.dart';

typedef CachingStrategyFactory = CachingStrategy<String, Object> Function();

// A set of unit tests that should pass for all caching strategies
void main() {
  <String, CachingStrategyFactory>{
    'ReferenceCountingStrategy': () =>
        ReferenceCountingStrategy<String, Object>(),
    'MostRecentlyUsedStrategy keep = 0': () => LeastRecentlyUsedStrategy(0),
    'MostRecentlyUsedStrategy keep = 1': () => LeastRecentlyUsedStrategy(1),
    'MostRecentlyUsedStrategy keep = 2': () => LeastRecentlyUsedStrategy(2),
  }.forEach((name, strategyFactory) {
    group('$name', () {
      late Cache<String, Object> cache;
      late Func<Future<Object>> valueFactory;
      late int valueFactoryCalled;

      setUp(() {
        valueFactoryCalled = 0;
        valueFactory = () async {
          valueFactoryCalled++;
          return Object();
        };
        cache = Cache(strategyFactory());
      });

      test(
          'synchronous get release get should not unnecessarily '
          'remove item from cache', () async {
        var firstGetCall = cache.getAsync('id', valueFactory);
        var release = cache.release('id');
        var secondGetCall = cache.getAsync('id', valueFactory);

        await release;

        var thirdGetCall = cache.getAsync('id', valueFactory);

        expect(await firstGetCall, await secondGetCall);
        expect(await secondGetCall, await thirdGetCall);
        // This should be checked after gets and releases are awaited
        expect(valueFactoryCalled, 1);
      });

      test(
          'synchronous get release release get should not unnecessarily '
          'remove item from cache', () async {
        var firstGetCall = cache.getAsync('id', valueFactory);
        var releases = Future.wait([cache.release('id'), cache.release('id')]);
        var secondGetCall = cache.getAsync('id', valueFactory);

        await releases;

        var thirdGetCall = cache.getAsync('id', valueFactory);

        expect(await firstGetCall, await secondGetCall);
        expect(await secondGetCall, await thirdGetCall);
        // This should be checked after gets and releases are awaited
        expect(valueFactoryCalled, 1);
      });

      test(
          'synchronous get remove get should result in value factory being called twice',
          () async {
        var firstGetCall = cache.getAsync('id', valueFactory);
        var remove = cache.remove('id');
        var secondGetCall = cache.getAsync('id', valueFactory);

        await remove;

        var thirdGetCall = cache.getAsync('id', valueFactory);

        expect(await firstGetCall, isNot(await secondGetCall));
        expect(await firstGetCall, isNot(await thirdGetCall));
        // This should be checked after gets and releases are awaited
        expect(valueFactoryCalled, 2);
      });
    });
  });
}
