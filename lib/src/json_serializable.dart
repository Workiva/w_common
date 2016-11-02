// Copyright 2016 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// Abstract class that identifies other classes being serializable as json.
///
/// Implementing this class will enable a class to be serialized using the
/// JSON.encode method.
abstract class JsonSerializable {
  /// Returns a map representing the serialized class
  /// or deserialized a map into a class
  ///
  ///   @override
  ///   Map<String, dynamic> toJson() {
  ///     Map<String, dynamic> fieldMap = {};
  ///     fieldMap['context'] = _context;
  ///     return fieldMap;
  ///   }
  ///
  ///   @override
  ///   void fromJson(Map<String, dynamic> json) {
  ///     _context = json['context'];
  ///   }

  Map<String, dynamic> toJson();
  void fromJson(Map<String, dynamic> json);
}
