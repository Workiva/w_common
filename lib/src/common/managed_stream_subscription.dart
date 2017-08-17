import 'dart:async';

/// An implementation of `StreamSubscription` that provides a [didCancel] future.
///
/// The [didCancel] future is used to provide an anchor point for removing
/// internal references to `StreamSubscriptions` if consumers manually cancel the
/// subscription. This class is not publicly exported.
///
/// There are three situations in which [didCancel] will be completed
class ManagedStreamSubscription<T> implements StreamSubscription<T> {
  final bool _cancelOnError;

  final StreamSubscription<T> _subscription;

  Completer<Null> _didCancel = new Completer();

  ManagedStreamSubscription(Stream<T> stream, void onData(T),
      {void onError(error, [stackTrace]), void onDone(), bool cancelOnError})
      : _cancelOnError = cancelOnError ?? false,
        _subscription = stream.listen(onData, cancelOnError: cancelOnError) {
    _wrapOnDone(onDone);
    _wrapOnError(onError);
  }

  Future<Null> get didCancel => _didCancel.future;

  @override
  bool get isPaused => _subscription.isPaused;

  // TODO: Should we complete when the resulting future completes?
  @override
  Future<E> asFuture<E>([E futureValue]) => _subscription.asFuture(futureValue);

  @override
  Future<Null> cancel() {
    var result = _subscription.cancel();

    // StreamSubscription.cancel() will return null if no cleanup was necessary.
    // This behavior is described in the docs as "for historical reasons" so
    // this may change in the future.
    if (result == null) {
      _complete();
      return null;
    }

    return result.then((_) {
      _complete();
    });
  }

  @override
  void onData(void handleData(T _)) => _subscription.onData(handleData);

  @override
  void onDone(void handleDone()) => _wrapOnDone(handleDone);

  @override
  void onError(Function handleError) => _wrapOnError(handleError);

  @override
  void pause([Future resumeSignal]) => _subscription.pause(resumeSignal);

  @override
  void resume() => _subscription.resume();

  void _complete() {
    if (!_didCancel.isCompleted) {
      _didCancel.complete();
    }
  }

  void _wrapOnDone(void handleDone()) {
    _subscription.onDone(() {
      if (handleDone != null) {
        handleDone();
      }

      _complete();
    });
  }

  void _wrapOnError(void handleError(error, [stackTrace])) {
    _subscription.onError((error, [stackTrace]) {
      if (handleError == null) {
        // By default unhandled stream errors are handled by their zone
        // error handler. In this case we *always* handle errors,
        // but the consumer may actually want the default behavior,
        // so in the case where the handler given to us by the consumer
        // is null (which is the default) we take the default action.
        Zone.current.handleUncaughtError(error, stackTrace);
      } else {
        handleError(error, stackTrace);
      }

      if (_cancelOnError) {
        _complete();
      }
    });
  }
}
