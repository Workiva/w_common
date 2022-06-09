# w_common

A collection of helpful utilities for use in Dart projects. Right now, it
includes the following:

  * `Disposable` interface / mixin to assist with cleaning up streams and other
  data structures that won't necessarily be garbage collected without some
  manual intervention.
  * A simple typedef that can be parameterized to represent a zero-arity
  callback that returns a particular type.
  * `InvalidationMixin` mixin used to mark a class as requiring validation.
  * `JsonSerializable` interface to indicate that something can be serialized
  to JSON.