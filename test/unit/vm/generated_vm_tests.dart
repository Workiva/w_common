@TestOn('vm')
library test.unit.vm.generated_vm_tests;

import './cache/cache_test.dart' as cache_cache_test;
import './cache/reference_cache_test.dart' as cache_reference_cache_test;
import './disposable_test.dart' as disposable_test;
import './func_test.dart' as func_test;
import 'package:test/test.dart';

void main() {
  cache_cache_test.main();
  cache_reference_cache_test.main();
  disposable_test.main();
  func_test.main();
}