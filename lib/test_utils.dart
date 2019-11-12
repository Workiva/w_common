import 'dart:mirrors';

import 'package:w_common/disposable.dart';

/// A helper to assert that the `disposableTypeName` getter has been,
/// and remains, correctly overridden for a given [Disposable] subclass.
///
/// Example usage might be to call this from a test:
///
/// ```
/// expect(
///   verifyDisposableTypeName(myObject, makeAssertion: false),
///   new Symbol('MyObject'),
/// );
/// ```
///
/// By default, it will assert that the `disposableTypeName` matches the
/// simple class name. It will also return the [Symbol] that represents
/// the class name.
Symbol verifyDisposableTypeName(Disposable object,
    {bool makeAssertion = true}) {
  final type = reflect(object).type.simpleName;
  if (makeAssertion == true) {
    assert(type == new Symbol(object.disposableTypeName));
  }
  return type;
}
