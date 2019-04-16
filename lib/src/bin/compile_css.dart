import 'dart:io';

import 'package:args/args.dart';
import 'package:dart2_constant/convert.dart' as convert;
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:package_resolver/package_resolver.dart';
import 'package:package_config/packages_file.dart' as pkg;
import 'package:path/path.dart' as path;
import 'package:sass/sass.dart' as sass;
import 'package:source_maps/source_maps.dart';

const String outputStyleArg = 'outputStyle';
const List<String> outputStyleDefaultValue = const ['compressed'];
const String expandedOutputStyleFileExtensionArg =
    'expandedOutputStyleFileExtension';
const String expandedOutputStyleFileExtensionDefaultValue = '.css';
const String compressedOutputStyleFileExtensionArg =
    'compressedOutputStyleFileExtension';
const String compressedOutputStyleFileExtensionDefaultValue = '.css';
const String sourceDirArg = 'sourceDir';
const String sourceDirDefaultValue = 'lib/sass/';
const String outputDirArg = 'outputDir';
const String outputDirDefaultValue = sourceDirDefaultValue;
const String checkFlag = 'check';
const String helpFlag = 'help';

const Map<String, sass.OutputStyle> outputStyleArgToOutputStyleValue = const {
  'compressed': sass.OutputStyle.compressed,
  'expanded': sass.OutputStyle.expanded,
};

void main(List<String> args) {
  final parser = new ArgParser()
    ..addMultiOption(outputStyleArg,
        help: 'The output style used to format the compiled CSS.',
        defaultsTo: outputStyleDefaultValue,
        splitCommas: true)
    ..addOption(expandedOutputStyleFileExtensionArg,
        help:
            'The file extension that will be used for the CSS compiled using `expanded` outputStyle.',
        defaultsTo: expandedOutputStyleFileExtensionDefaultValue)
    ..addOption(compressedOutputStyleFileExtensionArg,
        help:
            'The file extension that will be used for the CSS compiled using `compressed` outputStyle unless more than one `--$outputStyleArg` is defined. When more than one outputStyle is used, the extension for compressed CSS will be `.min.css` no matter what.',
        defaultsTo: compressedOutputStyleFileExtensionDefaultValue)
    ..addOption(sourceDirArg,
        help:
            'The directory where the `.scss` files that you want to compile live. Defaults to $sourceDirDefaultValue, or the value of `--$outputDirArg`, if specified.')
    ..addOption(outputDirArg,
        help:
            'The directory where the compiled CSS should go. Defaults to $outputDirDefaultValue, or the value of `--$sourceDirArg`, if specified.')
    ..addFlag(checkFlag,
        abbr: 'c',
        defaultsTo: false,
        negatable: false,
        help:
            'When set to true, no `.css` outputs will be written to disk, and a non-zero exit code will be returned if `sass.compile()` produces results that differ from those found in the committed `.css` files. Intended only for use as a CI safeguard.')
    ..addFlag(helpFlag,
        abbr: 'h',
        defaultsTo: false,
        negatable: false,
        help: 'Prints usage instructions to the terminal.');

  List<String> unparsedArgs;
  List<String> outputStylesValue;
  String expandedOutputStyleFileExtensionValue;
  String compressedOutputStyleFileExtensionValue;
  String sourceDirValue;
  String outputDirValue;
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
    return;
  }

  exitCode = compileCss(
    sourceDir: sourceDirValue,
    outputDir: outputDirValue,
    compressedOutputStyleFileExtension: compressedOutputStyleFileExtensionValue,
    expandedOutputStyleFileExtension: expandedOutputStyleFileExtensionValue,
    unparsedArgs: unparsedArgs,
    outputStyles: outputStylesValue,
    check: checkValue,
  );
}

int compileCss({
  @required String sourceDir,
  @required String outputDir,
  @required String compressedOutputStyleFileExtension,
  String expandedOutputStyleFileExtension =
      expandedOutputStyleFileExtensionDefaultValue,
  List<String> unparsedArgs,
  List<String> outputStyles = outputStyleDefaultValue,
  bool check = false,
}) {
  int exitCode = 0;
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
        .where((file) => !path.basename(file.path).startsWith('_'))
        .map((file) => path.relative(file.path))
        .toList();
  }

  if (exitCode != 0) return exitCode;

  for (var style in outputStyles) {
    final outputStyle = outputStyleArgToOutputStyleValue[style];
    final outputStyleMsg =
        outputStyle == sass.OutputStyle.compressed ? 'minified .css' : '.css';
    print(
        '\nReady to compile ${compileTargets.length} .scss files to $outputStyleMsg ...');

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

  taskTimer.stop();
  if (!check) {
    print(
        '\n[SUCCESS] Compiled ${compileTargets.length * outputStyles.length} CSS files in ${taskTimer.elapsed.inSeconds} seconds.');
  }

  return exitCode;
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

SyncPackageResolver _packageResolver;
SyncPackageResolver _getPackageResolver() {
  if (_packageResolver != null) return _packageResolver;

  const root = './';
  final packagesFile = new File('$root.packages');

  if (!packagesFile.existsSync()) {
    throw new StateError(
        'The "$root.packages" does not exist. You must run `pub get` before running `compile_css`.');
  }

  final config = pkg.parse(
      packagesFile.readAsStringSync().codeUnits, new Uri.directory(root));
  return _packageResolver = new SyncPackageResolver.config(config);
}
