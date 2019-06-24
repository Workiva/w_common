@JS()
library web_compiler;

import 'package:js/js.dart';

@JS(r'$dartLoader')
external dynamic get _dartLoader;

// The compiler used to compile the Dart to JS, determined at runtime
// via a global window property that is only present when DDC is used.
// If false, DDC was used.
bool get isCompiledWithDart2Js => _dartLoader == null;