@TestOn('vm')
import 'package:test/test.dart';
import 'package:w_common/checked_mode.dart';

void main() {
  test('Checked mode is enabled', () {
    expect(assertCheckedModeEnabled, returnsNormally);
  });
}
