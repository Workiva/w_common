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

import 'dart:html';

import 'package:w_common/src/common/disposable.dart' as disposable_common;

class Disposable extends disposable_common.Disposable {
  /// Adds an event listener to the document object and removes the event
  /// listener upon disposal.
  ///
  /// If using this method, you cannot manually use the `removeEventListener`
  /// method on the document singleton to remove the listener. At this point
  /// the only way to remove the listener is to use the [dispose] method.
  void subscribeToDocumentEvent(String event, EventListener callback,
      {bool useCapture, EventTarget documentObject}) {
    if (documentObject == null) {
      documentObject = document;
    }
    _subscribeToEvent(documentObject, event, callback, useCapture);
  }

  /// Adds an event listener to the element object and removes the event
  /// listener upon disposal.
  ///
  /// If using this method, you cannot manually use the `removeEventListener`
  /// method on the element to remove the listener. At this point the only way
  /// to remove the listener is to use the [dispose] method.
  void subscribeToDomElementEvent(
      Element element, String event, EventListener callback,
      {bool useCapture}) {
    _subscribeToEvent(element, event, callback, useCapture);
  }

  /// Adds an event listener to the window object and removes the event
  /// listener upon disposal.
  ///
  /// If using this method, you cannot manually use the `removeEventListener`
  /// method on the window singleton to remove the listener. At this point
  /// the only way to remove the listener is to use the [dispose] method.
  void subscribeToWindowEvent(String event, EventListener callback,
      {bool useCapture, EventTarget windowObject}) {
    if (windowObject == null) {
      windowObject = window;
    }
    _subscribeToEvent(windowObject, event, callback, useCapture);
  }

  void _subscribeToEvent(EventTarget eventTarget, String event,
      EventListener callback, bool useCapture) {
    eventTarget.addEventListener(event, callback, useCapture);

    var disposable = new disposable_common.InternalDisposable(() {
      eventTarget.removeEventListener(event, callback, useCapture);
    });

    disposable_common.addInternalDisposable(this, disposable);
  }
}
