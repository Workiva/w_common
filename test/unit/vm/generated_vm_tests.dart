@TestOn('vm')
library test.unit.vm.generated_vm_tests;

import './disposable_test.dart' as disposable_test;
import './func_test.dart' as func_test;
import './json_serializable_test.dart' as json_serializable_test;
import 'package:test/test.dart';

void main() {
  disposable_test.main();
  func_test.main();
  json_serializable_test.main();
}