import 'dart:async';

/// Allows the creation of managed objects, including helpers for common patterns.
///
/// There are three ways to consume this class, as a mixin, a base class,
/// and an interface. All should work fine but the first is the simplest
/// and most powerful. Using the class as an interface will require
/// significant effort.
///
/// In the case below, the class is used as a mixin. This provides both
/// default implementations and flexibility since it does not occupy
/// a spot in the class hierarchy.
///
/// Helper methods, such as [manageStreamSubscription] allow certain
/// cleanup to be automated. Managed subscriptions will be automatically
/// canceled when [dispose] is called on the object.
///
/// ```dart
/// class MyDisposable extends Object with Disposable {
///   StreamController _controller = new StreamController();
///
///   MyDisposable(Stream someStream) {
///     manageStreamSubscription(someStream.listen((_) => print('some stream')));
///     manageStreamController(_controller);
///   }
///
///   Future<Null> onDispose() {
///     // Other cleanup
///   }
/// }
/// ```
///
/// Implementing the [onDispose] method is entirely optional and is only
/// necessary if there is cleanup required that is not covered by one of
/// the helpers.
///
/// It is possible to schedule a callback to be called after the object
/// is disposed for purposes of further, external, cleanup or bookkeeping
/// (for example, you might want to remove any objects that are disposed
/// from a cache). To do this, use the [didDispose] future:
///
/// ```dart
/// var myDisposable = new MyDisposable();
/// myDisposable.didDispose.then((_) {
///   // External cleanup
/// });
/// ```
abstract class Disposable {
  Completer<Null> _didDispose = new Completer<Null>();
  List<Disposable> _disposables = [];
  bool _isDisposing = false;
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
    if (_isDisposing) {
      return didDispose;
    }
    _isDisposing = true;

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
        .then(_completeDisposeFuture);
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

  Future _cancelStreamSubscriptions(StreamSubscription subscription) =>
      subscription.cancel();

  Future _closeStreamControllers(StreamController controller) =>
      controller.close();

  Null _completeDisposeFuture(List<dynamic> _) {
    _didDispose.complete();
    return null;
  }

  Future _disposeDisposables(Disposable disposable) => disposable.dispose();
}
