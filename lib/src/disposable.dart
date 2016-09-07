import 'dart:async';

abstract class Disposable {
  Completer<Null> _willDispose = new Completer<Null>();
  Completer<Null> _didDispose = new Completer<Null>();

  List<StreamSubscription> _subscriptions = [];
  List<Disposable> _disposables = [];

  /// A [Future] that will complete when this object is about to be disposed.
  Future<Null> get willDispose => _willDispose.future;

  /// A [Future] that will complete when this object has been disposed.
  Future<Null> get didDispose => _didDispose.future;

  /// Whether this object has been disposed.
  bool get wasDisposed => _didDispose.isCompleted;

  /// Dispose of the object, cleaning up to prevent memory leaks.
  Future<Null> dispose() {
    if (wasDisposed) {
      return new Future(() {});
    }

    _willDispose.complete();

    _disposables.forEach((disposable) => disposable.dispose());
    _subscriptions.forEach((sub) => sub.cancel());

    return onDispose().then((_) {
      _didDispose.complete();
      return null;
    });
  }

  /// Automatically another object when this object is disposed.
  void manageDisposable(Disposable object) {
    _disposables.add(object);
  }

  /// Automatically cancel a stream subscription when this object is disposed.
  void manageSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Callback to allow arbitrary cleanup on dispose.
  Future<Null> onDispose() {
    return new Future(() {});
  }
}
