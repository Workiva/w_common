library tool.dev;

import 'dart:async';

import 'package:dart_dev/dart_dev.dart' show dev, config;

Future<Null> main(List<String> args) async {
  config.analyze
    ..strong = true
    ..fatalWarnings = true
    ..hints = false
    ..entryPoints = ['lib', 'test', 'example'];

  config.format.paths = ['lib', 'test', 'example'];

  config.test
    ..deleteConflictingOutputs = true
    ..platforms = ['vm', 'chrome']
    ..unitTests = ['test/'];

  await dev(args);
}
