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
    ..platforms = ['vm', 'content-shell']
    ..unitTests = [
      'test/unit/vm/generated_vm_tests.dart',
      'test/unit/browser/generated_browser_tests.dart'
    ];

  await dev(args);
}
