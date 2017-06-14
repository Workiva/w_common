@TestOn('vm')
import 'package:analyzer/analyzer.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';
import 'package:transformer_utils/transformer_utils.dart';

import 'package:w_common/src/disposable/transformer/transformations.dart';

import 'transformer_test_utils.dart';

void main() {
  group('transformAutoNullClass()', () {
    SourceFile sourceFile;
    TransformedSourceFile transformedFile;

    void setUpAndTransform(String source) {
      sourceFile = new SourceFile(source);
      transformedFile = new TransformedSourceFile(sourceFile);

      final unit = parseCompilationUnit(source);
      final classDecl =
          unit.declarations.firstWhere((decl) => decl is ClassDeclaration);

      transformClassToAutoNullFieldsOnDispose(classDecl, transformedFile);
    }

    tearDown(() {
      preservedLineNumbersTest(sourceFile, transformedFile);
      verifyTransformedSourceIsValid(transformedFile.getTransformedText());
    });

    test('no fields', () {
      setUpAndTransform('''
        class Test {
          bool get t => true;
          void method() {}
        }
      ''');
      expect(transformedFile.isModified, isFalse);
    });

    test('implements onDispose() if missing', () {
      setUpAndTransform('''
        class Test {
          var field = 'field';
        }
      ''');
      expect(
          transformedFile.getTransformedText(),
          contains('@override Future<Null> onDispose() async { '
              'await super.onDispose(); _\$TestNullOutFields(); }'));
    });

    group('augments onDispose() if present', () {
      test('empty body', () {
        setUpAndTransform('''
          class Test {
            var field = 'field';

            @override
            Future<Null> onDispose();
          }
        ''');
        expect(
            transformedFile.getTransformedText(),
            contains(
                'Future<Null> onDispose() async { await super.onDispose(); _\$TestNullOutFields(); }'));
      });

      test('block body', () {
        setUpAndTransform('''
          class Test {
            var field = 'field';

            @override
            Future<Null> onDispose() async {
              await super.onDispose();
              print('dispose');
            }
          }
        ''');
        expect(transformedFile.getTransformedText(),
            contains('_\$TestNullOutFields(); }'));
      });

      test('expression body (without async keyword)', () {
        setUpAndTransform('''
          class Test {
            var field = 'field';

            @override
            Future<Null> onDispose() => _onDispose();

            Future<Null> _onDispose() async {
              super.onDispose();
              print('dispose');
            }
          }
        ''');
        expect(
            transformedFile.getTransformedText(),
            contains(
                'Future<Null> onDispose() async { await _onDispose(); _\$TestNullOutFields(); }'));
      });

      test('expression body (with async keyword)', () {
        setUpAndTransform('''
          class Test {
            var field = 'field';

            @override
            Future<Null> onDispose() async => _onDispose();

            Future<Null> _onDispose() async {
              super.onDispose();
              print('dispose');
            }
          }
        ''');
        expect(
            transformedFile.getTransformedText(),
            contains(
                'Future<Null> onDispose() async { await _onDispose(); _\$TestNullOutFields(); }'));
      });
    });

    test('final fields', () {
      setUpAndTransform('''
        class Test {
          final field = 'field';
          final String typedField = 'typedField';
          final _private = 'private';
        }
      ''');
      expect(transformedFile.isModified, isFalse);
    });

    test('static fields', () {
      setUpAndTransform('''
        class Test {
          static const field = 'field';
          static const String typedField = 'typedField';
          static const _private = 'private';
        }
      ''');
      expect(transformedFile.isModified, isFalse);
    });

    test('nullable fields', () {
      setUpAndTransform('''
        class Test {
          var field = 'field';
          String typedField = 'typedField';
          var _private = 'private';
        }
      ''');
      expect(transformedFile.isModified, isTrue);

      expect(
          transformedFile.getTransformedText(),
          allOf([
            contains('field = null;'),
            contains('typedField = null;'),
            contains('_private = null;'),
          ]));

      expect(
          transformedFile.getTransformedText(),
          contains('@override Future<Null> onDispose() async { '
              'await super.onDispose(); _\$TestNullOutFields(); }'));
    });

    test('clearable fields', () {
      setUpAndTransform('''
        class Test {
          final untypedList = ['item'];
          final List<String> typedList = ['item'];
          final untypedMap = {'key': 'value'};
          final Map<String, String> typedMap = {'key': 'value'};
          final untypedSet = new Set();
          final Set<String> typedSet = new Set();
        }
      ''');
      expect(transformedFile.isModified, isTrue);

      expect(
          transformedFile.getTransformedText(),
          allOf([
            contains('try { typedList?.clear(); } catch (_) {}'),
            contains('try { typedMap?.clear(); } catch (_) {}'),
            contains('try { typedSet?.clear(); } catch (_) {}'),
          ]));
    });

    test('all field types', () {
      setUpAndTransform('''
        class Test {
          static const staticField = 'staticField';
          var field = 'field';
          final finalField = 'finalField';
          String typedField = 'typedField';
          final List<String> typedList = ['item'];
          final Map<String, String> typedMap = {'key': 'value'};
          final Set<String> typedSet = new Set();
          var _private = 'private';
        }
      ''');
      expect(transformedFile.isModified, isTrue);

      expect(
          transformedFile.getTransformedText(),
          allOf([
            contains('field = null;'),
            contains('typedField = null;'),
            contains('_private = null;'),
            contains('try { typedList?.clear(); } catch (_) {}'),
            contains('try { typedMap?.clear(); } catch (_) {}'),
            contains('try { typedSet?.clear(); } catch (_) {}'),
          ]));
    });
  });

  group('transformLibraryToImportDartAsync()', () {
    SourceFile sourceFile;
    TransformedSourceFile transformedFile;

    void setUpAndTransform(String source) {
      sourceFile = new SourceFile(source);
      transformedFile = new TransformedSourceFile(sourceFile);

      final unit = parseCompilationUnit(source);
      transformLibraryToImportDartAsync(unit, transformedFile);
    }

    tearDown(() {
      preservedLineNumbersTest(sourceFile, transformedFile);
      verifyTransformedSourceIsValid(transformedFile.getTransformedText());
    });

    test('should do nothing if dart:async is already imported', () {
      setUpAndTransform('''
        import 'dart:async';
      ''');
      expect(transformedFile.isModified, isFalse);
    });

    test('should import dart:async if missing', () {
      setUpAndTransform('''
        library some_library;

        import 'dart:html';
        import 'package:w_common/w_common.dart';

        part 'src/part.dart';
      ''');
      expect(transformedFile.isModified, isTrue);
      expect(transformedFile.getTransformedText(),
          contains("import 'dart:async';"));
    });
  });
}
