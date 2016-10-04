@TestOn('vm')
library test.generated_runner_test;

import './unit/disposable_test.dart' as unit_disposable_test;
import './unit/func_test.dart' as unit_func_test;
import 'package:test/test.dart';

void main() {
  unit_disposable_test.main();
  unit_func_test.main();
}