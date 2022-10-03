import 'dart:async';

/// Extensions for [Completer]
extension CompleterExtensions<T> on Completer<T> {
  void completeIfNotCompleted([FutureOr<T>? value]) {
    if (!isCompleted) {
      complete(value);
    }
  }

  void completeErrorIfNotCompleted(Object error, [StackTrace? stackTrace]) {
    if (!isCompleted) {
      completeError(error, stackTrace);
    }
  }
}
