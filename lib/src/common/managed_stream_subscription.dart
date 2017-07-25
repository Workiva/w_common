import 'dart:async';

/// An implementation of `StreamSubscription` that provides a [didCancel] future.
///
/// The [didCancel] future is used to provide an anchor point for removing
/// internal references to `StreamSubscriptions` if consumers manually cancel the
/// subscription. This class is not publicly exported.
class ManagedStreamSubscription<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _subscription;

  Completer<Null> _didCancel = new Completer();

  ManagedStreamSubscription(Stream<T> stream, void onData(T),
      {Function onError, void onDone(), bool cancelOnError})
      : _subscription = stream.listen(onData,
            onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Future<E> asFuture<E>([E futureValue]) => _subscription.asFuture(futureValue);

  @override
  Future<Null> cancel() {
    var result = _subscription.cancel();

    // StreamSubscription.cancel() will return null if no cleanup was necessary.
    // This behavior is described in the docs as "for historical reasons" so
    // this may change in the future.
    if (result == null) {
      if (!_didCancel.isCompleted) {
        _didCancel.complete();
      }
      return null;
    }

    return result.then((_) {
      if (!_didCancel.isCompleted) {
        _didCancel.complete();
      }
    });
  }

  Future<Null> get didCancel => _didCancel.future;

  @override
  bool get isPaused => _subscription.isPaused;

  @override
  void onData(void handleData(T _)) => _subscription.onData(handleData);

  @override
  void onDone(void handleDone()) => _subscription.onDone(handleDone);

  @override
  void onError(Function handleError) => _subscription.onError(handleError);

  @override
  void pause([Future resumeSignal]) => _subscription.pause(resumeSignal);

  @override
  void resume() => _subscription.resume();
}
