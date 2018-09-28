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

import '../disposable_common.dart';
import './browser_stubs.dart';

void main() {
  group('Browser Disposable', () {
    testCommonDisposable(() => new BrowserDisposable());

    group('events on global singleton', () {
      BrowserDisposable disposable;
      String eventName;
      bool useCapture;
      EventListener callback;

      setUp(() {
        disposable = new BrowserDisposable();
        callback = (_) {};
        eventName = 'event';
        useCapture = true;
      });

      test(
          'subscribeToDocumentEvent should remove same listener when thing is disposed',
          () async {
        final document = new MockEventTarget();

        disposable.subscribeToDocumentEvent(eventName, callback,
            documentObject: document, useCapture: useCapture);
        verify(document.addEventListener(eventName, callback, useCapture));
        await disposable.dispose();
        verify(document.removeEventListener(eventName, callback, useCapture));
      });

      test(
          'subscribeToWindowEvent should remove same listener when thing is disposed',
          () async {
        final window = new MockEventTarget();

        disposable.subscribeToWindowEvent(eventName, callback,
            windowObject: window, useCapture: useCapture);
        verify(window.addEventListener(eventName, callback, useCapture));
        await disposable.dispose();
        verify(window.removeEventListener(eventName, callback, useCapture));
      });
    });

    group('events on DOM element', () {
      BrowserDisposable disposable;

      setUp(() {
        disposable = new BrowserDisposable();
      });

      test(
          'subscribeToDomElementEvent should remove listener when thing is disposed',
          () async {
        final element = new Element.div();
        final event = new Event('event');
        const eventName = 'event';
        var numberOfEventCallbacks = 0;
        dynamic eventCallback(_) => numberOfEventCallbacks++;
        final shouldNotListenEvent = new Event('shouldNotListenEvent');

        disposable.subscribeToDomElementEvent(
            element, eventName, eventCallback);
        expect(numberOfEventCallbacks, equals(0));

        element.dispatchEvent(shouldNotListenEvent);
        expect(numberOfEventCallbacks, equals(0));

        element.dispatchEvent(event);
        expect(numberOfEventCallbacks, equals(1));

        await disposable.dispose();
        numberOfEventCallbacks = 0;

        element.dispatchEvent(event);
        expect(numberOfEventCallbacks, equals(0));
      });
    });
  });
}
