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
@TestOn('browser')

import 'package:dart2_constant/convert.dart' as convert;
import 'package:test/test.dart';
import 'package:w_common/json_serializable.dart';

class ExampleSerializable extends JsonSerializable {
  Map context = new Map();

  @override
  Map<String, dynamic> toJson() {
    Map<String, dynamic> fieldMap = {};
    fieldMap['context'] = context;
    return fieldMap;
  }
}

void main() {
  group('JsonSerializable : verify that', () {
    test('example object can be properly serialized', () async {
      ExampleSerializable testSerializable = new ExampleSerializable();
      testSerializable.context['child'] = 'childName';
      expect(convert.json.encode(testSerializable),
          '{"context":{"child":"childName"}}');
    });
  });
}
