library w_common.invalidation_mixin;

import 'dart:html';

/// A mixin providing a simple validation lifecycle.
///
/// Call [invalidate] to mark class as needing to be validated.  Implement
/// [validate] to specify logic that should happen when the class is validated.
/// Validation is scheduled using [animationFrame] on [window].
abstract class InvalidationMixin {
  bool _invalid = false;

  /// A boolean reflection of the current validity.
  bool get invalid => _invalid;

  /// Mark this as invalid to be validated at a later time.
  ///
  /// Schedule a call to [validate] to occur at the next frame. Multiple calls
  /// to invalidate will not enqueue multiple validations.
  void invalidate() {
    if (_invalid) return;

    _invalid = true;

    window.animationFrame.then((_) {
      if (_invalid == true) {
        validate();
        _invalid = false;
      }
    });
  }

  /// Abstract method to be implemented as means of performing validation.
  void validate();

  /// Cancels the current validation attempt.
  void cancelInvalidation() {
    _invalid = false;
  }
}
