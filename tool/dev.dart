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
