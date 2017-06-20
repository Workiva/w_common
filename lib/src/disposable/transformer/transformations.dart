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

import 'package:analyzer/analyzer.dart';
import 'package:transformer_utils/transformer_utils.dart';

const String _generatedPrefix = r'_$';
const String _publicGeneratedPrefix = r'$';

/// Transforms a class that has been annotated with @AutoNullFieldsOnDispose by
/// inserting a method that nulls-out or clears as many fields on the class as
/// possible. The onDispose() implementation will either be inserted or
/// augmented in order to call this method as the very last step.
void transformClassToAutoNullFieldsOnDispose(
    ClassDeclaration classDecl, TransformedSourceFile transformedFile) {
  final sourceFile = transformedFile.sourceFile;

  // Discover all fields on the class that can either be nulled out or cleared.
  var clearableFieldNames = <String>[];
  var nullableFieldNames = <String>[];
  for (var member in classDecl.members) {
    if (member is FieldDeclaration) {
      if (member.isStatic) continue;
      for (var variable in member.fields.variables) {
        if (variable.isFinal) {
          if (member.fields.type?.name?.name == 'List' ||
              member.fields.type?.name?.name == 'Map' ||
              member.fields.type?.name?.name == 'Set') {
            clearableFieldNames.add(variable.name.name);
          }
        } else {
          nullableFieldNames.add(variable.name.name);
        }
      }
    }
  }

  if (clearableFieldNames.isEmpty && nullableFieldNames.isEmpty) return;

  // This is the name of the method that we will generate to null out and clear
  // all fields that we can. It is namespaced by the class name to avoid
  // conflict with super classes that may also use @AutoNullFieldsOnDispose.
  final nullOutFieldsMethodName =
      '${_generatedPrefix}${classDecl.name.name}NullOutFields';

  // Find the offset for the right bracket of the class definition. The
  // implementation of the method that nulls out the fields will be inserted
  // immediately before it on the same line so line numbers are unaffected.
  final rightClassBracketOffset = classDecl.rightBracket.offset;

  // Buffer for the implementation that we'll have to squeeze onto the last line
  // of the class definition.
  final endOfClassBuffer = new StringBuffer();

  // Find the existing `onDispose()` method if it exists in this class.
  MethodDeclaration onDisposeHandler = classDecl.members.firstWhere(
      (member) =>
          member is MethodDeclaration && member.name.name == 'onDispose',
      orElse: () => null);
  if (onDisposeHandler == null) {
    // Generate an `onDispose()` method.
    endOfClassBuffer
      ..write('@override Future<Null> onDispose() async { ')
      ..write('await super.onDispose(); ')
      ..write('$nullOutFieldsMethodName(); ')
      ..write('} ');
  } else {
    // Determine where to augment the existing `onDispose()` based on the type
    // of function body.
    if (onDisposeHandler.body is BlockFunctionBody) {
      // For a block function, the call to null out fields will be inserted
      // immediately before the right bracket on the same line.
      BlockFunctionBody body = onDisposeHandler.body;
      transformedFile.insert(
        sourceFile.location(body.block.rightBracket.offset),
        '$nullOutFieldsMethodName(); ',
      );
    } else if (onDisposeHandler.body is EmptyFunctionBody) {
      // For an empty function, the body needs to be replaced with a block body
      // implementation, but on one line.
      EmptyFunctionBody body = onDisposeHandler.body;
      transformedFile.replace(
        sourceFile.span(
          onDisposeHandler.parameters.rightParenthesis.end,
          body.semicolon.end,
        ),
        ' async { await super.onDispose(); $nullOutFieldsMethodName(); }',
      );
    } else if (onDisposeHandler.body is ExpressionFunctionBody) {
      // For an expression function (fat-arrow), the body needs to be changed
      // to a block body implementation so the expression can be augmented.
      ExpressionFunctionBody body = onDisposeHandler.body;

      // Step 1: insert the `async` keyword if not present
      if (body.keyword == null) {
        transformedFile.insert(
          sourceFile.location(body.functionDefinition.offset),
          'async ',
        );
      }

      // Step 2: replace the => with a {
      transformedFile.replace(
        sourceFile.span(
          body.functionDefinition.offset,
          body.functionDefinition.end,
        ),
        '{',
      );

      // Step 3: augment the expression. This requires inserting an `await`
      // before the original expression to retain the original behavior (since
      // whatever was being returned would have been awaited) and then inserting
      // the call to null out the fields.
      transformedFile.insert(
        sourceFile.location(body.expression.offset),
        'await ',
      );
      transformedFile.insert(
        sourceFile.location(body.expression.end),
        '; $nullOutFieldsMethodName(); ',
      );

      // Step 4: replace the ; with a }
      transformedFile.replace(
        sourceFile.span(
          body.semicolon.offset,
          body.semicolon.end,
        ),
        '}',
      );
    }
  }

  // Generate the method to null-out and clear all fields.
  endOfClassBuffer.write('void $nullOutFieldsMethodName() { ');
  for (var fieldName in clearableFieldNames) {
    endOfClassBuffer.write('try { ${fieldName}?.clear(); } catch (_) {} ');
  }
  for (var fieldName in nullableFieldNames) {
    endOfClassBuffer.write('${fieldName} = null; ');
  }
  endOfClassBuffer.write('} ');

  // Insert the generated implementation onto the last line of the class def.
  transformedFile.insert(
    sourceFile.location(rightClassBracketOffset),
    endOfClassBuffer.toString(),
  );
}

/// Transforms a compilation unit (a library file) to ensure that `dart:async`
/// is imported.
void transformLibraryToImportDartAsync(
    CompilationUnit unit, TransformedSourceFile transformedFile) {
  final hasDartAsyncImport = unit.directives.any((directive) =>
      directive is ImportDirective &&
      directive.uri.stringValue == 'dart:async');
  if (hasDartAsyncImport) return;

  // If this file is a part (meaning the imports are defined in a separate,
  // parent file), then nothing can be done.
  final isPartOf =
      unit.directives.any((directive) => directive is PartOfDirective);
  if (isPartOf) return;

  // We know there must be at least one import because either Disposable or
  // something that extends Disposable must be imported.
  final firstImport = unit.directives.firstWhere(
      (directive) => directive is ImportDirective,
      orElse: () => null);

  final sourceFile = transformedFile.sourceFile;
  transformedFile.insert(
    sourceFile.location(firstImport.offset),
    "import 'dart:async';",
  );
}
