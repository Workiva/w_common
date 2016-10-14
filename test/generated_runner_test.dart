@TestOn('vm')
library test.generated_runner_test;

import './unit/disposable_test.dart' as unit_disposable_test;
import './unit/json_serializable_test.dart' as unit_json_serializable_test;
import 'package:test/test.dart';

void main() {
  unit_disposable_test.main();
  unit_json_serializable_test.main();
}
