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
import 'package:w_common/src/common/cache/cache.dart';
import 'package:w_common/src/common/cache/least_recently_used_strategy.dart';

void main() {
  group('MostRecentlyUsedStrategy', () {
    var expectedId = 'expectedId';
    var expectedValue = 'expectedValue';

    for (var i in Iterable<int>.generate(3)) {
      late Cache<String, Object> cache;

      setUp(() async {
        cache = Cache<String, Object>(LeastRecentlyUsedStrategy(i));

        // install expected item
        await cache.get(expectedId, () => expectedValue);

        // install i items into cache
        for (var j in Iterable<int>.generate(i)) {
          await cache.get('$j', () => j);
        }
      });

      test(
          'release should remove released item after $i additional releases '
          'when storing $i most recently used items', () async {
        cache.didRemove.listen(expectAsync1((context) {
          expect(context.id, expectedId);
          expect(context.value, expectedValue);
        }));

        // release expected item
        await cache.release(expectedId);

        // create i releases, after which expected item (and only expected
        // item) should be released
        for (var j in Iterable<int>.generate(i)) {
          await cache.release('$j');
        }
      });

      test(
          'release after a synchronous getAsync remove getAsync call should '
          'remove released item after $i additional releases when storing $i '
          'most recently used items', () async {
        cache.didRemove.listen(expectAsync1((context) {
          expect(context.id, expectedId);
          expect(context.value, expectedValue);
        }, count: 2));

        var firstGet = cache.getAsync(expectedId, () async => expectedValue);
        var remove = cache.remove(expectedId);
        var secondGet = cache.getAsync(expectedId, () async => expectedValue);

        // release expected item
        var release = cache.release(expectedId);

        await Future.wait([
          firstGet!.then((value) => value),
          remove,
          secondGet!.then((value) => value),
          release
        ]);

        // create i releases, after which expected item (and only expected
        // item) should be released
        for (var j in Iterable<int>.generate(i)) {
          await cache.release('$j');
        }
      });
    }
  });
}
