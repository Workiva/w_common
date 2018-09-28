/// Lifecycle states of a Disposable instance.
enum DisposableState {
  /// The object has been created.
  initialized,

  /// The object has been instructed to dispose but it has not yet
  /// begun the process because it is waiting on managed futures to
  /// complete.
  awaitingDisposal,

  /// The object has begun disposal.
  disposing,

  /// The object has finished disposal.
  disposed,
}
