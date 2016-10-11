library w_common.invalidation_mixin;

import 'dart:async';
import 'dart:html';

/// A mixin providing a simple validation lifecycle.
///
/// Call [invalidate] to mark class as needing to be validated.  Implement
/// [validate] to specify logic that should happen when the class is validated.
/// Validation is scheduled using [animationFrame] on [window].
abstract class InvalidationMixin {
  /// A boolean reflection of the current validity.
  bool get invalid => _onValidate != null && !_onValidate.isCompleted;

  /// Used to complete or error the validation
  Completer _onValidate;

  /// Mark this as invalid to be validated at a later time.
  ///
  /// Schedule a call to [validate] to occur at the next frame. Multiple calls
  /// to invalidate will not enqueue multiple validations. The [Future] returned
  /// will complete when the class in validated and complete with an error if
  /// invalidation is cancelled.
  Future invalidate() {
    if (invalid) return _onValidate.future;

    _onValidate = new Completer();

    window.animationFrame.then((_) {
      if (invalid) {
        _onValidate.complete();

        validate();
      }
    });

    return _onValidate.future;
  }

  /// Abstract method to be implemented as means of performing validation.
  void validate();

  /// Cancels the current validation attempt.
  void cancelInvalidation() {
    _onValidate.completeError(new InvalidationCancelledException());
  }
}

class InvalidationCancelledException implements Exception {}
