@JS()
library web_compiler;

import 'package:js/js.dart';
import 'package:meta/meta.dart';

@JS(r'$dartLoader')
external dynamic get _dartLoader;

/// Whether or not the Dart dev compiler (DDC), as opposed to the
/// production compiler (dart2js), was used to compile the app.
///
/// It is determined at runtime via a global window property that
/// is only present when DDC is used. It works with Dart 2 only.
///
/// Per the Dart team, the presence of this window property isn't
/// guaranteed forever, so proceed with caution and only use if you
/// absolutely must to work around compiler bugs.
@visibleForTesting
bool get isCompiledWithDdc => _dartLoader != null;
