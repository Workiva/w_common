// Copyright 2021 Workiva Inc.
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
@TestOn('vm')
import 'dart:async';

import 'package:test/test.dart';
import 'package:w_common/async_extensions.dart';

void main() {
  group('CompleterExtensions', () {
    test('completeIfNotCompleted should not throw if already completed', () {
      final completer = Completer<int>();
      completer.complete(1);
      expect(() => completer.completeIfNotCompleted(2), returnsNormally);
    });

    test('completeIfNotCompleted should complete if not already completed', () {
      final completer = Completer<int>();
      completer.future.then(expectAsync1((int value) {
        expect(value, equals(1));
      }));
      completer.completeIfNotCompleted(1);
    });

    test('completeErrorIfNotCompleted should not throw if already completed',
        () {
      final completer = Completer<int>();
      completer.future.catchError((_) {
        return 0;
      }); // if we don't catch, the test will error
      completer.completeError(Error());
      expect(() => completer.completeErrorIfNotCompleted(Object()),
          returnsNormally);
    });

    test('completeErrorIfNotCompleted should complete if not already completed',
        () {
      final completer = Completer<int>();
      final errObj = Object();
      completer.future.catchError(expectAsync2((dynamic err, StackTrace st) {
        expect(err, equals(errObj));
        expect(st, isNotNull);
        return 0;
      }));
      completer.completeErrorIfNotCompleted(errObj, StackTrace.current);
    });
  });
}
