// Copyright 2016 Workiva Inc.
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

import 'dart:async';

import 'package:test/test.dart';
import 'package:w_common/w_common.dart';

void main() {
  group('InvalidationMixin', () {
    InvalidThing thing;

    setUp(() {
      thing = new InvalidThing();
    });

    tearDown(() {
      thing.dispose();
    });

    group('invalidate', () {
      test('marks the thing as invalid', () {
        Future onValidation = thing.invalidate();

        expect(thing.invalid, isTrue);

        // ignore: unawaited_futures
        onValidation.then(expectAsync1((ValidationStatus status) {
          expect(status, equals(ValidationStatus.cancelled));
        }, count: 1));

        thing.cancelInvalidation();

        expect(thing.invalid, isFalse);
      });

      test('calls validate, eventually', () async {
        Future onValidation = thing.invalidate();

        // ignore: unawaited_futures
        onValidation.then(expectAsync1((ValidationStatus status) {
          expect(status, equals(ValidationStatus.complete));
        }, count: 1));

        thing.onValidate.listen(expectAsync1((_) {}, count: 1));
      });
    });
  });
}

class InvalidThing extends InvalidationMixin {
  StreamController _onValidate = new StreamController.broadcast();
  Stream get onValidate => _onValidate.stream;

  @override
  void validate() {
    _onValidate.add(null);
  }

  void dispose() {
    _onValidate.close();
  }
}
