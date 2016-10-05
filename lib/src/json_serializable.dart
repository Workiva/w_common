/// Abstract class that identifies other classes being serializable as json.
/// Implementing this class will enable a class to be serialized using the
/// JSON.encode method.
abstract class JsonSerializable {
  /// Returns a map representing the serialized class.
  ///
  ///   @override
  ///   Map<String, dynamic> toJson() {
  ///     Map<String, dynamic> fieldMap = {};
  ///     fieldMap['context'] = _context;
  ///     return fieldMap;
  ///   }
  Map<String, dynamic> toJson();
}
