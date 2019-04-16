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
  * A CSS compilation executable that can be run via 
    ```
    pub run w_common:compile_css
    ```
    from the root of your package that depends on w_common.
    * Run 
      ```
      pub run w_common:compile_css -h
      ```
      for more usage details / instructions.

We expect this list to grow as we identify small pieces of code that are useful
across a wide variety of Dart projects, especially in cases where there is
value in projects sharing a single implementation.

