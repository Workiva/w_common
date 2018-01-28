// Copyright 2017 Workiva Inc.
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
/// itself with a particular class when it is disposed.
abstract class LeakFlagger {
  /// Whether the leak flag for this object has been set.
  ///
  /// The flag should only be set in debug mode. If debug mode is
  /// on, the flag should be set at the end of the disposal process.
  /// At this point, the object is expected to be eligible for
  /// garbage collection.
  bool get isLeakFlagSet;

  /// Flag the object as having been disposed in a way that allows easier
  /// profiling.
  ///
  /// The leak flag is only set after disposal, so most instances found
  /// in a heap snapshot will indicate memory leaks.
  ///
  /// Consumers can search a heap snapshot for the `LeakFlag` class to
  /// see all instances of the flag.
  void flagLeak([String description]);
}
