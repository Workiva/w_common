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
@TestOn('browser')

import 'dart:html';
import 'dart:js' as js;

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:w_common/src/browser/disposable_browser.dart';
import 'package:w_common/src/common/disposable.dart' show LeakFlag;

import '../disposable_common.dart';
import './browser_stubs.dart';

void main() {
  group('Browser Disposable', () {
    testCommonDisposable(() => BrowserDisposable());

    group('events on global singleton', () {
      late BrowserDisposable disposable;
      late String eventName;
      late bool useCapture;
      late EventListener callback;

      setUp(() {
        disposable = BrowserDisposable();
        callback = (_) {};
        eventName = 'event';
        useCapture = true;
      });

      test(
          'subscribeToDocumentEvent should remove same listener when thing is disposed',
          () async {
        var document = MockEventTarget();

        disposable.subscribeToDocumentEvent(eventName, callback,
            documentObject: document, useCapture: useCapture);
        verify(document.addEventListener(eventName, callback, useCapture));
        await disposable.dispose();
        verify(document.removeEventListener(eventName, callback, useCapture));
      });

      test(
          'subscribeToWindowEvent should remove same listener when thing is disposed',
          () async {
        var window = MockEventTarget();

        disposable.subscribeToWindowEvent(eventName, callback,
            windowObject: window, useCapture: useCapture);
        verify(window.addEventListener(eventName, callback, useCapture));
        await disposable.dispose();
        verify(window.removeEventListener(eventName, callback, useCapture));
      });
    });

    group('events on DOM element', () {
      late BrowserDisposable disposable;

      setUp(() {
        disposable = BrowserDisposable();
      });

      test(
          'subscribeToDomElementEvent should remove listener when thing is disposed',
          () async {
        var element = Element.div();
        var event = Event('event');
        var eventName = 'event';
        int numberOfEventCallbacks = 0;
        EventListener eventCallback = (_) {
          numberOfEventCallbacks++;
        };
        var shouldNotListenEvent = Event('shouldNotListenEvent');

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

    group('debug mode', () {
      test('should not add leak flag factory to window by default', () {
        expect(js.context.hasProperty(Disposable.leakFlagFactoryName), isFalse);
      });

      test('should add leak flag factory to window when enabled', () {
        Disposable.enableDebugMode();
        final LeakFlag leakFlag =
            js.context.callMethod(Disposable.leakFlagFactoryName, ['foo']);
        expect(leakFlag, isNotNull);
        expect(leakFlag.description, equals('foo'));
      });

      test('should remove leak flag factory from window when disabled', () {
        Disposable.enableDebugMode();
        expect(js.context.hasProperty(Disposable.leakFlagFactoryName), isTrue);

        Disposable.disableDebugMode();
        expect(js.context.hasProperty(Disposable.leakFlagFactoryName), isFalse);
      });
    });
  });
}
