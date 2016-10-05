@TestOn('browser')
library user_analytics.common_test;

import 'package:test/test.dart';

import 'dart:convert' show JSON;
import 'package:w_common/w_common.dart';

class ExampleSerializable extends JsonSerializable {
  Map _context = new Map();

  set context(Map newContext) {
    _context = newContext;
  }

  Map get context => _context;

  @override
  Map<String, dynamic> toJson() {
    Map<String, dynamic> fieldMap = {};
    fieldMap['context'] = _context;
    return fieldMap;
  }
}

class NotSerializableToString {
  String name = 'NotSerializableToString';
}

void main() {
  group('JsonSerializable : verify that', () {
    test('example object can be properly serialized', () async {
      ExampleSerializable testSerializable = new ExampleSerializable();
      testSerializable.context['child'] = 'childName';

      expect(
          JSON.encode(testSerializable), '{"context":{"child":"childName"}}');
    });
  });
}
