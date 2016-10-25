@TestOn('browser')
library test.unit.browser.generated_browser_tests;

import './invalidation_mixin_test.dart' as invalidation_mixin_test;
import './json_serializable_test.dart' as json_serializable_test;
import 'package:test/test.dart';

void main() {
  invalidation_mixin_test.main();
  json_serializable_test.main();
}