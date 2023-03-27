import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:async/async.dart';
import 'package:colorize/colorize.dart';
import 'package:file/local.dart';
import 'package:glob/glob.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as path;
import 'package:sass/sass.dart' as sass;
import 'package:watcher/watcher.dart';

Stopwatch taskTimer = Stopwatch();

final Colorize errorMessageHeading = Colorize().apply(Styles.RED, '[ERROR]');
final Colorize failureMessageHeading =
    Colorize().apply(Styles.YELLOW, '[FAILURE]');
final Colorize successMessageHeading =
    Colorize().apply(Styles.GREEN, '[SUCCESS]');

const String outputStyleArg = 'outputStyle';
const List<String> outputStyleDefaultValue = ['compressed'];
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

const Map<String, sass.OutputStyle> outputStyleArgToOutputStyleValue = {
  'compressed': sass.OutputStyle.compressed,
  'expanded': sass.OutputStyle.expanded,
};

/// The CLI options for `pub run w_common_tools compile_sass`.
final ArgParser sassCliArgs = ArgParser()
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

class SassCompilationOptions {
  final List<String> unparsedArgs;
  final String expandedOutputStyleFileExtension;
  final List<String> outputStyles;
  final bool watch;
  final bool check;

  SassCompilationOptions({
    required this.unparsedArgs,
    required String outputDir,
    String? sourceDir,
    String? compressedOutputStyleFileExtension,
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

      compileTargets = Glob('$_sourceDir/**.scss', recursive: true)
          .listFileSystemSync(const LocalFileSystem())
          .where((file) => !isSassPartial(file.path))
          .map((file) => path.relative(file.path))
          .toList();
    }

    _watchDirs = [_sourceDir]..addAll(watchDirs);

    if (!_sourceDir.endsWith('/')) {
      _sourceDir = '$_sourceDir/';
    }

    _outputDir = outputDir;
    if (!_outputDir.endsWith('/')) {
      _outputDir = '$_outputDir/';
    }
  }

  List<String> get watchDirs => _watchDirs;
  late List<String> _watchDirs;

  String get sourceDir => _sourceDir;
  late String _sourceDir;

  String get outputDir => _outputDir;
  late String _outputDir;

  String get compressedOutputStyleFileExtension =>
      _compressedOutputStyleFileExtension;
  late String _compressedOutputStyleFileExtension;

  late List<String> compileTargets;

  int _validateCompileTargets() {
    var exitCode = 0;
    String? srcRootDirName;
    for (var target in compileTargets) {
      if (!File(target).existsSync()) {
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

Future<void> main(List<String> args) async {
  taskTimer = Stopwatch();

  List<String> outputStylesValue;
  bool helpValue;

  SassCompilationOptions options;

  try {
    final results = sassCliArgs.parse(args);
    outputStylesValue = results[outputStyleArg];
    helpValue = results[helpFlag];

    options = SassCompilationOptions(
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
    print(sassCliArgs.usage);
    exitCode = 1;
    rethrow;
  }

  if (helpValue) {
    print(sassCliArgs.usage);
    exitCode = 0;
    return Future(() {});
  }

  if (exitCode != 0) {
    return Future(() {});
  }

  await compileSass(options);

  if (exitCode != 0 || !options.watch) {
    return Future(() {});
  }

  await watch(options);
}

Future<void> watch(SassCompilationOptions options) async {
  var watchers = <FileWatcher>[];
  for (var target in options.compileTargets) {
    watchers.add(FileWatcher(target));
  }

  for (var watchDir in options.watchDirs) {
    final sassFilesToWatch = Glob('$watchDir/**.scss', recursive: true)
        .listFileSystemSync(const LocalFileSystem())
        .where((file) => isSassPartial(file.path))
        .map((file) => path.relative(file.path))
        .toList();

    for (var sassFileToWatch in sassFilesToWatch) {
      watchers.add(FileWatcher(sassFileToWatch));
    }
    print('\nWatching for changes in ${watchers.length} .scss files ...');
  }

  final watcherEvents = StreamGroup<WatchEvent>();
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

Future<void> compileSass(SassCompilationOptions options,
    {List<String>? compileTargets, bool printReadyMessage = true}) async {
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
        final singleCompileTimer = Stopwatch()..start();
        final outputSubDir = target.substring(
            options.sourceDir.length, target.indexOf(path.basename(target)));
        var outputDir = options.outputDir;
        if (outputSubDir.isNotEmpty) {
          outputDir = path.join(outputDir, outputSubDir);
        }

        var cssPath = path.setExtension(
            path.join(outputDir, path.basename(target)),
            outputStyleArgToOutputStyleFileExtension[style]!);
        final compileResult = sass.compileToResult(
          target,
          style: outputStyle,
          color: true,
          sourceMap: true,
          packageConfig: await _packageConfig,
        );

        var cssSrc = compileResult.css;
        var sourceMap = compileResult.sourceMap!;
        if (options.sourceDir != options.outputDir) {
          final relativePathOutToSassDir =
              path.dirname(path.relative(target, from: cssPath));
          sourceMap.sourceRoot = relativePathOutToSassDir;
        }

        cssSrc =
            '$cssSrc\n\n/*# sourceMappingURL=${'${path.basename(cssPath)}.map'} */';
        final cssTarget = File(cssPath);
        if (!cssTarget.existsSync()) {
          cssTarget.createSync(recursive: true);
        }

        if (options.check) {
          final cssSrcTempFile = File('$cssPath.tmp');
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
          final sourceMapTarget = File('${cssTarget.path}.map');

          if (!sourceMapTarget.existsSync()) {
            sourceMapTarget.createSync(recursive: true);
          }
          sourceMapTarget.writeAsStringSync(json.encode(sourceMap.toJson()));

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

PackageConfig? _cachedPackageConfig;
Future<PackageConfig?> get _packageConfig async {
  var dir = Directory.current;
  _cachedPackageConfig ??= await findPackageConfig(dir);
  if (_cachedPackageConfig == null) {
    throw StateError('Package configuration for ${dir.absolute} not found. '
        'You must run `pub get` before running `compile_sass`.');
  }
  return _cachedPackageConfig;
}
