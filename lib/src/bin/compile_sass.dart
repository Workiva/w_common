import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:async/async.dart';
import 'package:colorize/colorize.dart';
import 'package:dart2_constant/convert.dart' as convert;
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:package_resolver/package_resolver.dart';
import 'package:package_config/packages_file.dart' as pkg;
import 'package:path/path.dart' as path;
import 'package:sass/sass.dart' as sass;
import 'package:source_maps/source_maps.dart';
import 'package:watcher/watcher.dart';

Stopwatch taskTimer;

final Colorize errorMessageHeading =
    new Colorize().apply(Styles.RED, '[ERROR]');
final Colorize failureMessageHeading =
    new Colorize().apply(Styles.YELLOW, '[FAILURE]');
final Colorize successMessageHeading =
    new Colorize().apply(Styles.GREEN, '[SUCCESS]');

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

class SassCompilationOptions {
  final List<String> unparsedArgs;
  final String outputDir;
  final String expandedOutputStyleFileExtension;
  final List<String> outputStyles;
  final bool watch;
  final bool check;

  SassCompilationOptions({
    @required this.unparsedArgs,
    @required this.outputDir,
    String sourceDir,
    String compressedOutputStyleFileExtension,
    this.expandedOutputStyleFileExtension =
        expandedOutputStyleFileExtensionDefaultValue,
    this.outputStyles = outputStyleDefaultValue,
    List<String> watchDirs = const <String>[],
    this.watch = false,
    this.check = false,
  }) {
    // Have to use something different for the compressed output if both expanded and compressed are being used.
    _compressedOutputStyleFileExtension =
        outputStyles.length > 1 && compressedOutputStyleFileExtension == null
            ? '.min.css'
            : compressedOutputStyleFileExtension ??
                compressedOutputStyleFileExtensionDefaultValue;
    print(
        '_compressedOutputStyleFileExtension: $_compressedOutputStyleFileExtension');

    if (outputStyles.length > 1 &&
        this.compressedOutputStyleFileExtension ==
            expandedOutputStyleFileExtension) {
      print(
          '$errorMessageHeading when using more than one output style, `--$expandedOutputStyleFileExtensionArg` ($expandedOutputStyleFileExtension) \n'
          'and `--$compressedOutputStyleFileExtensionArg` ($_compressedOutputStyleFileExtension) cannot match.');
      exitCode = 1;
      return;
    }

    if (unparsedArgs != null && unparsedArgs.isNotEmpty) {
      compileTargets = unparsedArgs.map(path.relative).toList();
      exitCode = _validateCompileTargets();
      if (exitCode == 0 && sourceDir != null) {
        _sourceDir = path.split(compileTargets.first).first;
      } else {
        _sourceDir = sourceDir ?? sourceDirDefaultValue;
      }
    } else {
      _sourceDir = sourceDir ?? sourceDirDefaultValue;

      compileTargets = new Glob('$_sourceDir/**.scss', recursive: true)
          .listSync()
          .where((file) => !isSassPartial(file.path))
          .map((file) => path.relative(file.path))
          .toList();
    }

    _watchDirs = [_sourceDir]..addAll(watchDirs);
  }

  List<String> get watchDirs => _watchDirs;
  List<String> _watchDirs;

  String get sourceDir => _sourceDir;
  String _sourceDir;

  String get compressedOutputStyleFileExtension =>
      _compressedOutputStyleFileExtension;
  String _compressedOutputStyleFileExtension;

  List<String> compileTargets;

  int _validateCompileTargets() {
    var exitCode = 0;
    String srcRootDirName;
    for (var target in compileTargets) {
      if (!new File(target).existsSync()) {
        print('$errorMessageHeading "$target" does not exist');
        exitCode = 1;
        break;
      } else {
        final targetRootDirName =
            '${path.rootPrefix(target)}${path.split(target).first}';

        if (srcRootDirName != null) {
          if (targetRootDirName != srcRootDirName) {
            print(
                '$errorMessageHeading All targets must share the same root directory. Expected "$target" to exist within "$srcRootDirName".');
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
}

Future<Null> main(List<String> args) async {
  taskTimer = new Stopwatch();
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
            'The file extension that will be used for the CSS compiled using \n`compressed` outputStyle.\n'
            '(defaults to $compressedOutputStyleFileExtensionDefaultValue, or .min.css\n'
            ' if `--$outputStyleArg` contains more than one style)')
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

  List<String> outputStylesValue;
  bool helpValue;

  SassCompilationOptions options;

  try {
    final results = parser.parse(args);
    outputStylesValue = results[outputStyleArg];
    helpValue = results[helpFlag];

    options = new SassCompilationOptions(
      unparsedArgs: results.rest,
      outputDir: results[outputDirArg] ??
          results[sourceDirArg] ??
          outputDirDefaultValue,
      sourceDir: results[sourceDirArg] ?? results[outputDirArg],
      compressedOutputStyleFileExtension:
          results[compressedOutputStyleFileExtensionArg],
      expandedOutputStyleFileExtension:
          results[expandedOutputStyleFileExtensionArg],
      outputStyles: outputStylesValue,
      watchDirs: results[watchDirsArg],
      watch: results[watchFlag],
      check: results[checkFlag],
    );
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

  if (exitCode != 0) return new Future(() {});

  compileSass(options);

  if (exitCode != 0 || !options.watch) return new Future(() {});

  await watch(options);
}

Future<Null> watch(SassCompilationOptions options) async {
  var watchers = <FileWatcher>[];
  for (var target in options.compileTargets) {
    watchers.add(new FileWatcher(target));
  }

  for (var watchDir in options.watchDirs) {
    final sassFilesToWatch = new Glob('$watchDir/**.scss', recursive: true)
        .listSync()
        .where((file) => isSassPartial(file.path))
        .map((file) => path.relative(file.path))
        .toList();

    for (var sassFileToWatch in sassFilesToWatch) {
      watchers.add(new FileWatcher(sassFileToWatch));
    }
    print('\nWatching for changes in ${watchers.length} .scss files ...');
  }

  final watcherEvents = new StreamGroup<WatchEvent>();
  watchers.map((watcher) => watcher.events).forEach(watcherEvents.add);

  watcherEvents.stream.listen((e) {
    exitCode = 0;
    String changeMessage = '${e.path} was';

    switch (e.type) {
      case ChangeType.MODIFY:
        changeMessage = '$changeMessage modified';

        if (isSassPartial(e.path)) {
          print(
              '\n$changeMessage... recompiling ${options.compileTargets.length} targets ...');
          compileSass(options, printReadyMessage: false);
        } else {
          print('\n$changeMessage... recompiling 1 target ...');
          compileSass(options,
              compileTargets: [e.path], printReadyMessage: false);
        }

        break;
      case ChangeType.REMOVE:
        changeMessage = '$changeMessage removed';

        if (!isSassPartial(e.path)) {
          options.compileTargets.removeWhere((target) => target == e.path);
        }

        print('\n$changeMessage... the watcher for it has been removed');

        break;
    }

    print('\nWatching for changes in ${watchers.length} .scss files ...');
  });

  await watcherEvents.close();
}

void compileSass(SassCompilationOptions options,
    {List<String> compileTargets, bool printReadyMessage = true}) {
  taskTimer.start();

  compileTargets ??= options.compileTargets;
  int failureCount = 0;

  for (var style in options.outputStyles) {
    final outputStyle = outputStyleArgToOutputStyleValue[style];
    final outputStyleMsg =
        outputStyle == sass.OutputStyle.compressed ? 'minified .css' : '.css';

    if (printReadyMessage) {
      print(
          '\nReady to compile ${compileTargets.length} .scss files to $outputStyleMsg ...');
    }

    final Map<String, String> outputStyleArgToOutputStyleFileExtension = {
      'compressed': options.compressedOutputStyleFileExtension,
      'expanded': options.expandedOutputStyleFileExtension,
    };

    for (var target in compileTargets) {
      try {
        final singleCompileTimer = new Stopwatch()..start();
        final outputSubDir = target.substring(
            options.sourceDir.length, target.indexOf(path.basename(target)));
        var outputDir = options.outputDir;
        if (outputSubDir.isNotEmpty) {
          outputDir = path.join(outputDir, outputSubDir);
        }

        SingleMapping sourceMap;
        var cssPath = path.setExtension(
            path.join(outputDir, path.basename(target)),
            outputStyleArgToOutputStyleFileExtension[style]);
        var cssSrc = sass.compile(target,
            style: outputStyle,
            color: true,
            packageResolver: _getPackageResolver(), sourceMap: (map) {
          if (options.sourceDir != options.outputDir) {
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

        if (options.check) {
          final cssSrcTempFile = new File('$cssPath.tmp');
          // Writing a temporary file since the string value read from the committed file does not seem to be equivalent to one that has not yet been written to a file.
          cssSrcTempFile.writeAsStringSync(cssSrc);

          if (!cssTarget.existsSync()) {
            exitCode = 1;
            print(
                '$errorMessageHeading ${cssTarget.path} was generated during the build, but has not been committed. Commit this file and push to rebuild.');
          } else if (cssSrcTempFile.readAsStringSync() !=
              cssTarget.readAsStringSync()) {
            exitCode = 1;
            print(
                '$errorMessageHeading ${cssTarget.path} is out of date, and needs to be committed / pushed.');
          } else {
            print('$successMessageHeading ${cssTarget.path} is up to date!');
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
              '  "$target" => "$cssPath" (${singleCompileTimer.elapsedMilliseconds}ms)');
          singleCompileTimer.reset();
        }
      } catch (e) {
        exitCode = 1;
        failureCount++;
        print('\n$errorMessageHeading Failed to compile $target: \n\n$e\n');
      }
    }
  }

  taskTimer.stop();
  if (!options.check) {
    final elapsedTime = taskTimer.elapsed;
    final durationString = elapsedTime.inSeconds > 0
        ? '${elapsedTime.inSeconds} seconds.'
        : '${elapsedTime.inMilliseconds} milliseconds.';

    if (exitCode == 0) {
      print(
          '\n$successMessageHeading Compiled ${compileTargets.length * options.outputStyles.length} CSS file(s) in $durationString');
    } else {
      print(
          '\n$failureMessageHeading $failureCount/${compileTargets.length} targets failed to compile');
    }
  }
  taskTimer.reset();
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
