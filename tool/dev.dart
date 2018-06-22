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

import 'dart:async';

import 'package:dart_dev/dart_dev.dart'
    show dev, config, TestRunnerConfig, Environment;

Future main(List<String> args) async {
  // https://github.com/Workiva/dart_dev

  config.analyze
    ..entryPoints = ['lib/', 'test/unit/', 'tool/']
    ..strong = true;

  config.format
    ..paths = [
      'example/',
      'lib/',
      'test/',
      'tool/',
    ]
    ..exclude = [
      'test/unit/vm/generated_vm_tests.dart',
      'test/unit/browser/generated_browser_tests.dart'
    ];

  config.genTestRunner.configs = [
    new TestRunnerConfig(
        directory: 'test/unit/vm',
        env: Environment.vm,
        filename: 'generated_vm_tests'),
    new TestRunnerConfig(
        directory: 'test/unit/browser',
        env: Environment.browser,
        filename: 'generated_browser_tests')
  ];

  config.test
    ..platforms = ['vm', 'dartium']
    ..unitTests = [
      'test/unit/vm/generated_vm_tests.dart',
      'test/unit/browser/generated_browser_tests.dart'
    ];

  await dev(args);
}
