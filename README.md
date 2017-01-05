# w_common

A collection of helpful utilities for use in Dart projects. Right now, it
includes the following:

  * A `Cache` implementation that maintains references to an object instance by
  an identifier. Specializations of this class allow invariants to be
  maintained:
    * A `ReferenceCache` maintains a count for each access for a given identifier.
    When the final reference is released, the item is removed from the cache.
  * A `Disposable` interface / mixin to assist with cleaning up streams and
  other data structures that won't necessarily be garbage collected without some
  manual intervention.
  * A simple typedef that can be parameterized to represent a zero-arity
  callback that returns a particular type.
  * An `InvalidationMixin` mixin used to mark a class as requiring validation.
  * A `JsonSerializable` interface to indicate that something can be serialized
  to JSON.

We expect this list to grow as we identify small pieces of code that are useful
across a wide variety of Dart projects, especially in cases where there is
value in projects sharing a single implementation.

