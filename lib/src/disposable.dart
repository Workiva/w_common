import 'dart:async';

abstract class Disposable {
  Completer<Null> _didDispose = new Completer<Null>();

  Future<Null> get didDispose => _didDispose.future;

  bool get isDisposed => _didDispose.isCompleted;

  Future<Null> dispose() {
    return onDispose().then((_) {
      _didDispose.complete();
      return null;
    });
  }

  Future<Null> onDispose();
}
