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

import 'package:mockito/mockito.dart';
import 'package:w_common/disposable_browser.dart';

import '../stubs.dart';

class BrowserDisposable extends Object with Disposable, StubDisposable {
  @override
  String get disposableTypeName => 'BrowserDisposable';
}

class MockEventTarget extends Mock implements EventTarget {}