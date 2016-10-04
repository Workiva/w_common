/// Generic callback function type that expects a certain return type.
/// This is useful, for example, when you want a simple callback function
/// in a single location and creating a separate typedef seems heavy handed.
/// Instead you can use this type:
///
///     class MyClass {
///       Func<Model> modelGetter;
///
///       MyClass(Func<Model> this.modelGetter);
///
///       onLoad() async {
///         Model model = modelGetter();
///       }
///     }
typedef T Func<T>();
