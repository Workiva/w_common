import 'dart:html';

import 'package:w_common/src/disposable/disposable_vm.dart' as disposable_vm;

class Disposable extends disposable_vm.Disposable {
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

    var disposable = new disposable_vm.InternalDisposable(() {
      eventTarget.removeEventListener(event, callback, useCapture);
    });

    disposable_vm.addInternalDisposable(this, disposable);
  }
}
