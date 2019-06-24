@JS()
library web_compiler;

import 'package:js/js.dart';

@JS(r'$dartLoader')
external dynamic get _dartLoader;

// The compiler used to compile the Dart to JS, determined at runtime
// via a global window property that is only present when DDC is used.
// If false, dart2js was used. Works with Dart 2 only.
// Per the Dart team, the presence of this window property isn't
// guaranteed forever, so proceed with caution and only use if you
// absolutely MUST to work around compiler bugs.
bool get isCompiledWithDdc => _dartLoader != null;
