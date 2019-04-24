import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:async/async.dart';
import 'package:dart2_constant/convert.dart' as convert;
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:package_resolver/package_resolver.dart';
import 'package:package_config/packages_file.dart' as pkg;
import 'package:path/path.dart' as path;
import 'package:sass/sass.dart' as sass;
import 'package:source_maps/source_maps.dart';
import 'package:watcher/watcher.dart';

const String outputStyleArg = 'outputStyle';
const List<String> outputStyleDefaultValue = const ['compressed'];
const String expandedOutputStyleFileExtensionArg =
    'expandedOutputStyleFileExtension';
const String expandedOutputStyleFileExtensionDefaultValue = '.css';
const String compressedOutputStyleFileExtensionArg =
    'compressedOutputStyleFileExtension';
const String compressedOutputStyleFileExtensionDefaultValue = '.css';
const String sourceDirArg = 'sourceDir';
const String watchDirsArg = 'watchDirs';
const String sourceDirDefaultValue = 'lib/sass/';
const String outputDirArg = 'outputDir';
const String outputDirDefaultValue = sourceDirDefaultValue;
const String watchFlag = 'watch';
const String checkFlag = 'check';
const String helpFlag = 'help';

const Map<String, sass.OutputStyle> outputStyleArgToOutputStyleValue = const {
  'compressed': sass.OutputStyle.compressed,
  'expanded': sass.OutputStyle.expanded,
};

Future<Null> main(List<String> args) async {
  final parser = new ArgParser()
    ..addMultiOption(outputStyleArg,
        abbr: 's',
        help: 'The output style used to format the compiled CSS.',
        defaultsTo: outputStyleDefaultValue,
        splitCommas: true)
    ..addOption(expandedOutputStyleFileExtensionArg,
        help:
            'The file extension that will be used for the CSS compiled using \n`expanded` outputStyle.',
        defaultsTo: expandedOutputStyleFileExtensionDefaultValue)
    ..addOption(compressedOutputStyleFileExtensionArg,
        help:
            'The file extension that will be used for the CSS compiled using \n`compressed` outputStyle unless more than one `--$outputStyleArg` \nis defined. \nWhen more than one outputStyle is used, the extension for \ncompressed CSS will be `.min.css` no matter what.',
        defaultsTo: compressedOutputStyleFileExtensionDefaultValue)
    ..addOption(sourceDirArg,
        help:
            'The directory where the `.scss` files that you want to compile live. \n(defaults to $sourceDirDefaultValue, or the value of `--$outputDirArg`, if specified.)')
    ..addOption(outputDirArg,
        help:
            'The directory where the compiled CSS should go. \n(defaults to $outputDirDefaultValue, or the value of `--$sourceDirArg`, if specified.)')
    ..addMultiOption(watchDirsArg,
        splitCommas: true,
        defaultsTo: const <String>[],
        help:
            'Directories that should be watched in addition to `sourceDir`. \nOnly valid with --watch.')
    ..addFlag(watchFlag,
        negatable: false,
        help: 'Watch stylesheets and recompile when they change.')
    ..addFlag(checkFlag,
        abbr: 'c',
        negatable: false,
        help:
            'When set to true, no `.css` outputs will be written to disk, \nand a non-zero exit code will be returned if `sass.compile()` \nproduces results that differ from those found in the committed \n`.css` files. \nIntended only for use as a CI safeguard.')
    ..addFlag(helpFlag,
        abbr: 'h',
        negatable: false,
        help: 'Prints usage instructions to the terminal.');

  List<String> unparsedArgs;
  List<String> outputStylesValue;
  String expandedOutputStyleFileExtensionValue;
  String compressedOutputStyleFileExtensionValue;
  String sourceDirValue;
  String outputDirValue;
  List<String> watchDirsValue;
  bool watchValue;
  bool checkValue;
  bool helpValue;
  try {
    final results = parser.parse(args);
    unparsedArgs = results.rest;
    outputStylesValue = results[outputStyleArg];
    expandedOutputStyleFileExtensionValue =
        results[expandedOutputStyleFileExtensionArg];
    compressedOutputStyleFileExtensionValue =
        // Have to use something different for the compressed output if both expanded and compressed are being used.
        outputStylesValue.length > 1
            ? '.min.css'
            : results[compressedOutputStyleFileExtensionArg];
    sourceDirValue =
        results[sourceDirArg] ?? results[outputDirArg] ?? sourceDirDefaultValue;
    outputDirValue =
        results[outputDirArg] ?? results[sourceDirArg] ?? outputDirDefaultValue;
    watchDirsValue = [sourceDirValue]..addAll(results[watchDirsArg]);
    watchValue = results[watchFlag];
    checkValue = results[checkFlag];
    helpValue = results[helpFlag];
  } on FormatException {
    print(parser.usage);
    exitCode = 1;
    rethrow;
  }

  if (helpValue) {
    print(parser.usage);
    exitCode = 0;
    return new Future(() {});
  }

  await initialize(
    sourceDir: sourceDirValue,
    outputDir: outputDirValue,
    compressedOutputStyleFileExtension: compressedOutputStyleFileExtensionValue,
    expandedOutputStyleFileExtension: expandedOutputStyleFileExtensionValue,
    unparsedArgs: unparsedArgs,
    outputStyles: outputStylesValue,
    watchDirs: watchDirsValue,
    watch: watchValue,
    check: checkValue,
  );
}

Future<Null> initialize({
  @required String sourceDir,
  @required String outputDir,
  @required String compressedOutputStyleFileExtension,
  String expandedOutputStyleFileExtension =
      expandedOutputStyleFileExtensionDefaultValue,
  List<String> unparsedArgs,
  List<String> outputStyles = outputStyleDefaultValue,
  List<String> watchDirs,
  bool watch = false,
  bool check = false,
}) async {
  final taskTimer = new Stopwatch()..start();

  List<String> compileTargets;
  if (unparsedArgs != null && unparsedArgs.isNotEmpty) {
    compileTargets = unparsedArgs.map(path.relative).toList();
    exitCode = validateCompileTargets(compileTargets);
    if (exitCode == 0) {
      sourceDir = path.split(compileTargets.first).first;
    }
  } else {
    compileTargets = new Glob('$sourceDir/**.scss', recursive: true)
        .listSync()
        .where((file) => !isSassPartial(file.path))
        .map((file) => path.relative(file.path))
        .toList();
  }

  if (exitCode != 0) return new Future(() {});

  compileSass(
    compileTargets: compileTargets,
    sourceDir: sourceDir,
    outputDir: outputDir,
    compressedOutputStyleFileExtension: compressedOutputStyleFileExtension,
    expandedOutputStyleFileExtension: expandedOutputStyleFileExtension,
    outputStyles: outputStyles,
    check: check,
  );

  if (exitCode != 0) return new Future(() {});

  taskTimer.stop();
  if (!check) {
    print(
        '\n[SUCCESS] Compiled ${compileTargets.length * outputStyles.length} CSS files in ${taskTimer.elapsed.inSeconds} seconds.');
    taskTimer.reset();
  }

  if (!watch) return new Future(() {});

  void recompileSass(List<String> targets) {
    taskTimer.start();
    try {
      compileSass(
        compileTargets: targets,
        sourceDir: sourceDir,
        outputDir: outputDir,
        compressedOutputStyleFileExtension: compressedOutputStyleFileExtension,
        expandedOutputStyleFileExtension: expandedOutputStyleFileExtension,
        outputStyles: outputStyles,
        printReadyMessage: false,
      );
      taskTimer.stop();

      print(
          '\n[SUCCESS] Compiled ${targets.length * outputStyles.length} CSS files in ${taskTimer.elapsed.inSeconds} seconds.');
    } catch (e) {
      print(
          '\n[ERROR] Failed to compiled ${targets.length * outputStyles.length} CSS files: \n\n$e');
    }

    taskTimer.stop();
    taskTimer.reset();
  }

  var watchers = <FileWatcher>[];
  for (var target in compileTargets) {
    watchers.add(new FileWatcher(target));
  }

  for (var watchDir in watchDirs) {
    final sassFilesToWatch = new Glob('$watchDir/**.scss', recursive: true)
        .listSync()
        .where((file) => isSassPartial(file.path))
        .map((file) => path.relative(file.path))
        .toList();

    for (var sassFileToWatch in sassFilesToWatch) {
      watchers.add(new FileWatcher(sassFileToWatch));
    }
    print('\nWatching for changes in ${watchers.length} .scss files...');
  }

  final watcherEvents = new StreamGroup<WatchEvent>();
  watchers.map((watcher) => watcher.events).forEach(watcherEvents.add);

  watcherEvents.stream.listen((e) {
    String changeMessage = '${e.path} was';

    switch (e.type) {
      case ChangeType.MODIFY:
        changeMessage = '$changeMessage modified';

        if (isSassPartial(e.path)) {
          print(
              '\n$changeMessage... recompiling ${compileTargets.length} targets');
          recompileSass(compileTargets);
        } else {
          print('\n$changeMessage... recompiling 1 target');
          recompileSass([e.path]);
        }

        break;
      case ChangeType.REMOVE:
        changeMessage = '$changeMessage removed';

        if (!isSassPartial(e.path)) {
          compileTargets.removeWhere((target) => target == e.path);
        }

        print('\n$changeMessage... the watcher for it has been removed');

        break;
    }

    print('\nWatching for changes in ${watchers.length} .scss files...');
  });

  await watcherEvents.close();
}

void compileSass({
  @required List<String> compileTargets,
  @required String sourceDir,
  @required String outputDir,
  @required String compressedOutputStyleFileExtension,
  String expandedOutputStyleFileExtension =
      expandedOutputStyleFileExtensionDefaultValue,
  List<String> outputStyles = outputStyleDefaultValue,
  bool check = false,
  bool printReadyMessage = true,
}) {
  for (var style in outputStyles) {
    final outputStyle = outputStyleArgToOutputStyleValue[style];
    final outputStyleMsg =
        outputStyle == sass.OutputStyle.compressed ? 'minified .css' : '.css';

    if (printReadyMessage) {
      print(
          '\nReady to compile ${compileTargets.length} .scss files to $outputStyleMsg ...');
    }

    final Map<String, String> outputStyleArgToOutputStyleFileExtension = {
      'compressed': compressedOutputStyleFileExtension,
      'expanded': expandedOutputStyleFileExtension,
    };

    for (var target in compileTargets) {
      final singleCompileTimer = new Stopwatch()..start();

      SingleMapping sourceMap;
      var cssPath = path.setExtension(
          path.join(outputDir, path.basename(target)),
          outputStyleArgToOutputStyleFileExtension[style]);
      var cssSrc = sass.compile(target,
          style: outputStyle,
          color: true,
          packageResolver: _getPackageResolver(), sourceMap: (map) {
        if (sourceDir != outputDir) {
          final relativePathOutToSassDir =
              path.dirname(path.relative(target, from: cssPath));
          map.sourceRoot = relativePathOutToSassDir;
        }

        sourceMap = map;
      });

      cssSrc =
          '$cssSrc\n\n/*# sourceMappingURL=${'${path.basename(cssPath)}.map'} */';
      final cssTarget = new File(cssPath);
      if (!cssTarget.existsSync()) {
        cssTarget.createSync(recursive: true);
      }

      if (check) {
        final cssSrcTempFile = new File('$cssPath.tmp');
        // Writing a temporary file since the string value read from the committed file does not seem to be equivalent to one that has not yet been written to a file.
        cssSrcTempFile.writeAsStringSync(cssSrc);

        if (!cssTarget.existsSync()) {
          exitCode = 1;
          print(
              '[ERROR] ${cssTarget.path} was generated during the build, but has not been committed. Commit this file and push to rebuild.');
        } else if (cssSrcTempFile.readAsStringSync() !=
            cssTarget.readAsStringSync()) {
          exitCode = 1;
          print(
              '[ERROR] ${cssTarget.path} is out of date, and needs to be committed / pushed.');
        } else {
          print('[SUCCESS] ${cssTarget.path} is up to date!');
        }

        cssSrcTempFile.deleteSync();

        singleCompileTimer
          ..stop()
          ..reset();
      } else {
        cssTarget.writeAsStringSync(cssSrc);
        final sourceMapTarget = new File('${cssTarget.path}.map');

        if (!sourceMapTarget.existsSync()) {
          sourceMapTarget.createSync(recursive: true);
        }
        sourceMapTarget
            .writeAsStringSync(convert.json.encode(sourceMap.toJson()));

        singleCompileTimer.stop();
        print(
            '"$target" => "$cssPath" (${singleCompileTimer.elapsedMilliseconds}ms)');
        singleCompileTimer.reset();
      }
    }
  }
}

int validateCompileTargets(List<String> compileTargets) {
  var exitCode = 0;
  String srcRootDirName;
  for (var target in compileTargets) {
    if (!new File(target).existsSync()) {
      print('[ERROR]: "$target" does not exist');
      exitCode = 1;
      break;
    } else {
      final targetRootDirName =
          '${path.rootPrefix(target)}${path.split(target).first}';

      if (srcRootDirName != null) {
        if (targetRootDirName != srcRootDirName) {
          print(
              '[ERROR]: All targets must share the same root directory. Expected "$target" to exist within "$srcRootDirName".');
          exitCode = 1;
          break;
        }
      } else {
        srcRootDirName = targetRootDirName;
      }
    }
  }

  return exitCode;
}

bool isSassPartial(String filePath) => path.basename(filePath).startsWith('_');

SyncPackageResolver _packageResolver;
SyncPackageResolver _getPackageResolver() {
  if (_packageResolver != null) return _packageResolver;

  const root = './';
  final packagesFile = new File('$root.packages');

  if (!packagesFile.existsSync()) {
    throw new StateError(
        'The "$root.packages" does not exist. You must run `pub get` before running `compile_sass`.');
  }

  final config = pkg.parse(
      packagesFile.readAsStringSync().codeUnits, new Uri.directory(root));
  return _packageResolver = new SyncPackageResolver.config(config);
}
