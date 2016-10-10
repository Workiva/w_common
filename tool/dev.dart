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

import 'package:dart_dev/dart_dev.dart'
    show dev, config, TestRunnerConfig, Environment;

main(List<String> args) async {
  // https://github.com/Workiva/dart_dev

  config.analyze.entryPoints = ['lib/', 'lib/src', 'test/unit/', 'tool/'];

  config.format
    ..directories = [
      'lib/',
      'test/',
      'tool/',
    ]
    ..exclude = ['test/generated_runner_test.dart'];

  config.genTestRunner.configs = [
    new TestRunnerConfig(
        directory: 'test',
        env: Environment.vm,
        filename: 'generated_runner_test')
  ];

  config.test
    ..platforms = ['vm']
    ..unitTests = ['test/generated_runner_test.dart'];

  await dev(args);
}
