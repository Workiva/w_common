import 'package:dart_dev/dart_dev.dart' show dev, config;

main(List<String> args) async {
  // https://github.com/Workiva/dart_dev

  config.analyze.entryPoints = ['lib/', 'lib/src', 'test/unit/', 'tool/'];

  config.format.directories = [
    'lib/',
    'test/',
    'tool/',
  ];

  config.test.platforms = ['vm'];

  config.test.unitTests = ['test/unit/'];

  await dev(args);
}
