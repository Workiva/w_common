// Copyright 2016-2018 Workiva Inc.
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

/// An interface that allows a class to flag potential leaks by marking
/// itself with a particular class when it is logically ready to be
/// garbage collected.
abstract class LeakFlagger {
  /// Whether the leak flag for this object has been set.
  bool get isLeakFlagSet;

  /// Flag the object as ready for garbage collection in a way that
  /// allows easier profiling.
  ///
  /// The implementation of this method should create an instance of
  /// a chosen class (perhaps [LeakFlag]) and assign it to a private
  /// field on itself.
  ///
  /// Consumers can then search a heap snapshot for the class used
  /// as the flag, such as [LeakFlag]. Instances of this class,
  /// provided the GC has run, likely indicate memory leaks.
  void flagLeak([String description]);
}

/// A class used as a marker for potential memory leaks.
class LeakFlag {
  /// Flag description, intended to provide context around the flag
  /// for debugging purposes.
  final String description;

  LeakFlag(this.description);

  @override
  String toString() =>
      description == null ? 'LeakFlag' : 'LeakFlag: $description';
}
