import 'dart:async';

/// An implementation of StreamSubscription that provides a didCancel future.
class ManagedStreamSubscription<T> extends StreamSubscription<T> {
  final StreamSubscription<T> _subscription;

  Completer<Null> _didCancel = new Completer();

  ManagedStreamSubscription(Stream<T> stream, void onData(T))
      : _subscription = stream.listen(onData);

  @override
  Future<E> asFuture<E>([E futureValue]) => _subscription.asFuture(futureValue);

  @override
  Future<Null> cancel() async {
    await _subscription.cancel();
    if (!_didCancel.isCompleted) {
      _didCancel.complete(null);
    }
  }

  Future<Null> get didCancel => _didCancel.future;

  @override
  bool get isPaused => _subscription.isPaused;

  @override
  void onData(void handleData(_)) => _subscription.onData(handleData);

  @override
  void onDone(void handleDone()) => _subscription.onDone(handleDone);

  @override
  void onError(Function handleError) => _subscription.onError(handleError);

  @override
  void pause([Future resumeSignal]) => _subscription.pause(resumeSignal);

  @override
  void resume() => _subscription.resume();
}
