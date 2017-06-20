# w_common

A collection of helpful utilities for use in Dart projects. Right now, it
includes the following:

  * `Disposable` interface / mixin to assist with cleaning up streams and other
  data structures that won't necessarily be garbage collected without some
  manual intervention.
  * A simple typedef that can be parameterized to represent a zero-arity
  callback that returns a particular type.
  * `InvalidationMixin` mixin used to mark a class as requiring validation.
  * `JsonSerializable` interface to indicate that something can be serialized
  to JSON.

We expect this list to grow as we identify small pieces of code that are useful
across a wide variety of Dart projects, especially in cases where there is
value in projects sharing a single implementation.


### `DisposableTransformer`

To assist in memory management, this package provides a transformer that will
transform all classes annotated with `@AutoNullFieldsOnDispose()` such that they
automatically null-out or clear as many fields on the class as possible when
disposed. More specifically:

- Static fields are ignored
- Non-final fields are set to null
- Final fields that are of type `List`, `Set`, or `Map` are cleared
  - The call to `clear()` is guarded by a null-aware and wrapped in a try-catch
    to handle scenarios where the field is already null or where the value is
    read-only.
- Existing implementations of `onDispose()` are not overwritten – just
  augmented.


#### Usage

```yaml
transformers:
- w_common/disposable_transformer
```

#### Example

The source:

```dart
import 'package:w_common/disposable.dart';

@AutoNullFieldsOnDispose()
class Example extends Disposable {
  final finalField = 'finalField';
  var field = 'field';
  List<String> listField = ['listField'];
}
```

The transformed output:

> The actual transformed output will insert code as single lines and onto
> existing lines so as to not change line numbers for debugging/source maps.

```dart
import 'dart:async';

import 'package:w_common/disposable.dart';

@AutoNullFieldsOnDispose()
class Example extends Disposable {
  final finalField = 'finalField';
  var field = 'field';
  List<String> listField = ['listField'];

  @override
  Future<Null> onDispose() async {
    await super.onDispose();
    _$ExampleNullOutFields();
  }

  void _$ExampleNullOutFields() {
    field = null;
    try { listField?.clear(); } catch (_) {}
  }
}
```

#### Caveats

Since this transformer may insert an implementation of the `onDispose()` method
whose return type is `Future<Null>`, it needs to ensure that `dart:async` is
imported. The only situation where this isn't possible is when the file being
transformed is a part (meaning the imports are defined in the parent file).

In this scenario, the transformer does nothing and trusts that `dart:async` is
already imported in the parent file. This is likely since it is a very common
import, especially when dealing with `Disposable`s. **If, however, `dart:async`
is missing, it will be a runtime error because the `Future` type will be
unknown.**

To fix this, you will need to find the offending file, navigate to the parent of
that part, and add a `dart:async` import manually. You may also want to add an
"ignore" directive to silence the analyzer hint about it being an unused import:

```
// ignore: unused_import
import 'dart:async';
```