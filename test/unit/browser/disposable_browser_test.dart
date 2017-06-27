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

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

import './browser_stubs.dart';

void main() {
  group('Browser Disposable', () {
    DisposableThing thing;

    setUp(() {
      thing = new DisposableThing();
    });

    group('events on global singleton', () {
      String eventName;
      bool useCapture;
      EventListener callback;

      setUp(() {
        callback = (_) {};
        eventName = 'event';
        useCapture = true;
      });

      test(
          'subscribeToDocumentEvent should remove same listener when thing is disposed',
          () async {
        var document = new MockEventTarget();

        thing.subscribeToDocumentEvent(eventName, callback,
            documentObject: document, useCapture: useCapture);
        verify(document.addEventListener(eventName, callback, useCapture));
        await thing.dispose();
        verify(document.removeEventListener(eventName, callback, useCapture));
      });

      test(
          'subscribeToWindowEvent should remove same listener when thing is disposed',
          () async {
        var window = new MockEventTarget();

        thing.subscribeToWindowEvent(eventName, callback,
            windowObject: window, useCapture: useCapture);
        verify(window.addEventListener(eventName, callback, useCapture));
        await thing.dispose();
        verify(window.removeEventListener(eventName, callback, useCapture));
      });
    });

    test(
        'subscribeToDomElementEvent should remove listener when thing is disposed',
        () async {
      var element = new Element.div();
      var event = new Event('event');
      var eventName = 'event';
      int numberOfEventCallbacks = 0;
      EventListener eventCallback = (_) {
        numberOfEventCallbacks++;
      };
      var shouldNotListenEvent = new Event('shouldNotListenEvent');

      thing.subscribeToDomElementEvent(element, eventName, eventCallback);
      expect(numberOfEventCallbacks, equals(0));

      element.dispatchEvent(shouldNotListenEvent);
      expect(numberOfEventCallbacks, equals(0));

      element.dispatchEvent(event);
      expect(numberOfEventCallbacks, equals(1));

      await thing.dispose();

      element.dispatchEvent(event);
      expect(numberOfEventCallbacks, equals(1));

      thing.subscribeToDomElementEvent(element, eventName, eventCallback);
      expect(numberOfEventCallbacks, equals(1));

      element.dispatchEvent(event);
      expect(numberOfEventCallbacks, equals(2));

      element.dispatchEvent(event);
      expect(numberOfEventCallbacks, equals(3));

      element.dispatchEvent(shouldNotListenEvent);
      expect(numberOfEventCallbacks, equals(3));
    });
  });
}

class MockEventTarget extends Mock implements EventTarget {}
