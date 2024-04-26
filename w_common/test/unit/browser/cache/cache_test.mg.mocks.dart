// Mocks generated by Mockito 5.4.0 from annotations
// in w_common/test/unit/browser/cache/cache_test.mg.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;

import 'package:mocktail/mocktail.dart' as _i1;
import 'package:w_common/src/common/cache/cache.dart' as _i2;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

/// A class which mocks [CachingStrategy].
///
/// See the documentation for Mockito's code generation for more information.
class MockCachingStrategy extends _i1.Mock
    implements _i2.CachingStrategy<String, Object> {
  @override
  _i3.Future<Null> onDidGet(
    String? id,
    Object? value,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #onDidGet,
          [
            id,
            value,
          ],
        ),
        returnValue: _i3.Future<Null>.value(),
        returnValueForMissingStub: _i3.Future<Null>.value(),
      ) as _i3.Future<Null>);
  @override
  _i3.Future<Null> onDidRelease(
    String? id,
    Object? value,
    _i3.Future<Null> Function(String)? remove,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #onDidRelease,
          [
            id,
            value,
            remove,
          ],
        ),
        returnValue: _i3.Future<Null>.value(),
        returnValueForMissingStub: _i3.Future<Null>.value(),
      ) as _i3.Future<Null>);
  @override
  _i3.Future<Null> onDidRemove(
    String? id,
    Object? value,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #onDidRemove,
          [
            id,
            value,
          ],
        ),
        returnValue: _i3.Future<Null>.value(),
        returnValueForMissingStub: _i3.Future<Null>.value(),
      ) as _i3.Future<Null>);
  @override
  void onWillGet(String? id) => super.noSuchMethod(
        Invocation.method(
          #onWillGet,
          [id],
        ),
        returnValueForMissingStub: null,
      );
  @override
  void onWillRelease(String? id) => super.noSuchMethod(
        Invocation.method(
          #onWillRelease,
          [id],
        ),
        returnValueForMissingStub: null,
      );
  @override
  void onWillRemove(String? id) => super.noSuchMethod(
        Invocation.method(
          #onWillRemove,
          [id],
        ),
        returnValueForMissingStub: null,
      );
}
