import 'dart:async';

abstract class Disposable {
  Completer<Null> _didDispose = new Completer<Null>();
  List<StreamSubscription> _subscriptions = [];
  List<Disposable> _disposables = [];

  /// A [Future] that will complete when this object is disposed.
  Future<Null> get didDispose => _didDispose.future;

  /// Whether this object has been disposed.
  bool get isDisposed => _didDispose.isCompleted;

  /// Dispose of the object, cleaning up to prevent memory leaks.
  Future<Null> dispose() {
    if (isDisposed) {
      return new Future(() {});
    }

    _subscriptions.forEach((sub) => sub.cancel);
    _disposables.forEach((disposable) => disposable.dispose());

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
