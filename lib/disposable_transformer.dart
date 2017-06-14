// Copyright 2016 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:analyzer/analyzer.dart';
import 'package:barback/barback.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:transformer_utils/transformer_utils.dart';
import 'package:w_common/src/disposable/transformer/annotations.dart';
import 'package:w_common/src/disposable/transformer/transformations.dart';
import 'package:w_common/src/disposable/transformer/util.dart';

export 'package:w_common/src/disposable/transformer/annotations.dart';

/// A transformer that modifies `.dart` files, aiding in the management of
/// disposable classes. Currently the only supported functionality is:
///
/// - Auto nulling-out of fields upon disposal for classes annotated with
///   `@AutoNullFieldsOnDispose`
class DisposableTransformer extends Transformer implements LazyTransformer {
  final BarbackSettings _settings;

  DisposableTransformer.asPlugin(this._settings);

  /// Declare the assets this transformer uses. Only dart assets will be
  /// transformed.
  @override
  String get allowedExtensions => '.dart';

  @override
  void declareOutputs(DeclaringTransform transform) {
    transform.declareOutput(transform.primaryId);
    transform.consumePrimary();

    if (_settings.mode == BarbackMode.DEBUG) {
      transform.declareOutput(transform.primaryId
          .addExtension('.disposable_transformer_diff.html'));
    }
  }

  /// Converts [id] to a "package:" URI.
  ///
  /// This will return a schemeless URI if [id] doesn't represent a library in
  /// `lib/`.
  static Uri idToPackageUri(AssetId id) {
    if (!id.path.startsWith('lib/')) {
      return new Uri(path: id.path);
    }

    return new Uri(
        scheme: 'package',
        path: p.url.join(id.package, id.path.replaceFirst('lib/', '')));
  }

  @override
  Future apply(Transform transform) async {
    var primaryInputContents = await transform.primaryInput.readAsString();

    SourceFile sourceFile = new SourceFile(primaryInputContents,
        url: idToPackageUri(transform.primaryInput.id));
    TransformedSourceFile transformedFile =
        new TransformedSourceFile(sourceFile);
    TransformLogger logger = new JetBrainsFriendlyLogger(transform.logger);

    // Only parse the file if it might contain the annotation.
    if (mightContainAnnotation(AutoNullFieldsOnDispose, primaryInputContents)) {
      // Parse the source file on its own and use the resultant AST to perform
      // the transformations.
      var unit = parseCompilationUnit(
        primaryInputContents,
        suppressErrors: true,
        name: transform.primaryInput.id.path,
        parseFunctionBodies: true,
      );

      // Ensure that dart:async is imported.
      transformLibraryToImportDartAsync(unit, transformedFile);

      // Find all members annotated with @AutoNullFieldsOnDispose.
      var annotationName = getName(AutoNullFieldsOnDispose);
      var autoNullMembers = unit.declarations.where((decl) => decl.metadata
          .any((annotation) => annotation.name.name == annotationName));

      // Apply the transformation to each class (or log if used incorrectly).
      for (var decl in autoNullMembers) {
        if (decl is! ClassDeclaration) {
          logger.error('`@$annotationName` can only be used on classes.',
              span: getSpan(sourceFile, decl));
        } else {
          transformClassToAutoNullFieldsOnDispose(decl, transformedFile);
        }
      }
    }

    if (transformedFile.isModified) {
      // Output the transformed source.
      transform.addOutput(new Asset.fromString(
          transform.primaryInput.id, transformedFile.getTransformedText()));

      if (_settings.mode == BarbackMode.DEBUG) {
        transform.addOutput(new Asset.fromString(
            transform.primaryInput.id
                .addExtension('.disposable_transformer_diff.html'),
            transformedFile.getHtmlDiff()));
      }
    } else {
      // Output the unmodified input.
      transform.addOutput(transform.primaryInput);
    }
  }
}
