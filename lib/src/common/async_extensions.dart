import 'dart:async';

/// Extensions for [Completer]
extension CompleterExtensions<T> on Completer<T> {
  void completeIfNotCompleted([FutureOr<T> value]) {
    return complete(value);
  }

  void completeErrorIfNotCompleted(Object error, [StackTrace stackTrace]) {
    return completeError(error, stackTrace);
  }
}
