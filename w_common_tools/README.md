# w_common_tools
A collection of dev utilities that are not intended to be used in deployable artifacts.
  * A CSS compilation executable that can be run via 
    ```
    dart run w_common_tools:compile_sass
    ```
    from the root of your package that depends on w_common.
    * It can also be used as a watcher - great for when you're 
      doing a lot of work on `.scss` files and don't want to have to
      remember to keep re-running the script after each change.
      ```
      dart run w_common_tools:compile_sass --watch
      ```
    * Run 
      ```
      dart run w_common_tools:compile_sass -h
      ```
      for more usage details / instructions.

We expect this list to grow as we identify small pieces of code that are useful
across a wide variety of Dart projects, especially in cases where there is
value in projects sharing a single implementation.

