import 'dart:async';

abstract class Disposable {
  Completer<Null> _didDispose = new Completer<Null>();

  List<Disposable> _disposables = [];
  List<StreamController> _streamControllers = [];
  List<StreamSubscription> _streamSubscriptions = [];

  /// A [Future] that will complete when this object has been disposed.
  Future<Null> get didDispose => _didDispose.future;

  /// Whether this object has been disposed.
  bool get isDisposed => _didDispose.isCompleted;

  /// Dispose of the object, cleaning up to prevent memory leaks.
  Future<Null> dispose() async {
    if (isDisposed) {
      return null;
    }

    List<Future> futures = []
      ..addAll(_disposables.map(_disposeDisposables))
      ..addAll(_streamControllers.map(_closeStreamControllers))
      ..addAll(_streamSubscriptions.map(_cancelStreamSubscriptions))
      ..add(onDispose());

    _disposables = [];
    _streamControllers = [];
    _streamSubscriptions = [];

    // We need to filter out nulls because a subscription cancel
    // method is allowed to return a plain old null value.
    return Future
        .wait(futures.where((future) => future != null))
        .then(_disposeCompleter);
  }

  /// Automatically dispose another object when this object is disposed.
  void manageDisposable(Disposable disposable) {
    _disposables.add(disposable);
  }

  /// Automatically cancel a stream controller when this object is disposed.
  void manageStreamController(StreamController controller) {
    _streamControllers.add(controller);
  }

  /// Automatically cancel a stream subscription when this object is disposed.
  void manageStreamSubscription(StreamSubscription subscription) {
    _streamSubscriptions.add(subscription);
  }

  /// Callback to allow arbitrary cleanup on dispose.
  Future<Null> onDispose() async {
    return null;
  }

  Future _disposeDisposables(Disposable disposable) => disposable.dispose();

  Null _disposeCompleter(List<dynamic> _) {
    _didDispose.complete();
    return null;
  }

  Future _closeStreamControllers(StreamController controller) =>
      controller.close();

  Future _cancelStreamSubscriptions(StreamSubscription subscription) =>
      subscription.cancel();
}
