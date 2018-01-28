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

import 'dart:async';

import 'package:w_common/src/common/disposable/disposable_base.dart';
import 'package:w_common/src/common/disposable/disposer.dart';

/// Used to invoke, and remove references to, a [Disposer] before disposal
/// of the parent object.
class ManagedDisposer implements DisposableBase {
  Disposer _disposer;
  final Completer<Null> _didDispose = new Completer<Null>();
  bool _isDisposing = false;

  ManagedDisposer(this._disposer);

  /// A [Future] that will complete when this object has been disposed.
  Future<Null> get didDispose => _didDispose.future;

  /// Whether this object has been disposed.
  bool get isDisposed => _didDispose.isCompleted;

  /// Whether this object has been disposed or is disposing.
  ///
  /// This will become `true` as soon as the [dispose] method is called
  /// and will remain `true` forever. This is intended as a convenience
  /// and `object.isDisposedOrDisposing` will always be the same as
  /// `object.isDisposed || object.isDisposing`.
  bool get isDisposedOrDisposing => isDisposed || isDisposing;

  /// Whether this object is in the process of being disposed.
  ///
  /// This will become `true` as soon as the [dispose] method is called
  /// and will become `false` once the [didDispose] future completes.
  bool get isDisposing => _isDisposing;

  /// Dispose of the object, cleaning up to prevent memory leaks.
  @override
  Future<Null> dispose() {
    if (isDisposedOrDisposing) {
      return didDispose;
    }
    _isDisposing = true;

    var disposeFuture = _disposer != null
        ? (_disposer() ?? new Future.value())
        : new Future.value();
    _disposer = null;

    return disposeFuture.then((_) {
      _disposer = null;
      _didDispose.complete();
      _isDisposing = false;
    });
  }
}

