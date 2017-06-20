@TestOn('vm')
import 'dart:async';

import 'package:barback/barback.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:w_common/disposable_transformer.dart';

import 'transformer_test_utils.dart';

void main() {
  group('DisposableTransformer', () {
    DisposableTransformer transformer;

    void setUpTransformer({BarbackMode mode: BarbackMode.RELEASE}) {
      final settings = new BarbackSettings({}, mode);
      transformer = new DisposableTransformer.asPlugin(settings);
    }

    tearDown(() {
      transformer = null;
    });

    test('allowedExtensions', () {
      setUpTransformer();
      expect(transformer.allowedExtensions, equals('.dart'));
    });

    group('declareOutputs()', () {
      test('mode=debug', () {
        setUpTransformer(mode: BarbackMode.DEBUG);

        final transform = new MockDeclaringTransform();

        final primaryId = new AssetId('pkg', 'path/file.dart');
        when(transform.primaryId).thenReturn(primaryId);

        transformer.declareOutputs(transform);
        expect(transform.declaredOutputs.length, equals(2));

        final dartFile = transform.declaredOutputs[0];
        expect(dartFile.package, equals('pkg'));
        expect(dartFile.path, equals('path/file.dart'));

        final htmlDiffFile = transform.declaredOutputs[1];
        expect(htmlDiffFile.package, equals('pkg'));
        expect(htmlDiffFile.path,
            equals('path/file.dart.disposable_transformer_diff.html'));
      });

      test('mode=release', () {
        setUpTransformer();

        final transform = new MockDeclaringTransform();

        final primaryId = new AssetId('pkg', 'path/file.dart');
        when(transform.primaryId).thenReturn(primaryId);

        transformer.declareOutputs(transform);
        expect(transform.declaredOutputs.length, equals(1));

        final dartFile = transform.declaredOutputs[0];
        expect(dartFile.package, equals('pkg'));
        expect(dartFile.path, equals('path/file.dart'));
      });
    });

    group('apply()', () {
      test('no-op on file without @AutoNullFieldsOnDispose() annotation',
          () async {
        setUpTransformer();

        final mockAsset = createMockAsset(
            'lib/src/irrelevant_file.dart',
            '''
          class IrrelevantClass {}
          IrrelevantClass irrelevantFactory() => new IrrelevantClass();
        ''');

        final transform = new MockTransform(mockAsset);
        await transformer.apply(transform);

        expect(transform.outputs.length, equals(1));

        final output = transform.outputs[0];
        expect(output.id.package, equals('pkg'));
        expect(output.id.path, equals('lib/src/irrelevant_file.dart'));

        expect(await output.readAsString(),
            equals(await mockAsset.readAsString()));
      });

      test('should transform file to import dart:async if missing', () async {
        setUpTransformer();

        final mockAsset = createMockAsset(
            'lib/src/file_to_transform.dart',
            '''
          import 'package:w_common/disposable.dart';

          @AutoNullFieldsOnDispose()
          class DisposableExample extends Disposable {
            String field = 'field';

            void foo() {
              print(field);
            }
          }
        ''');

        final transform = new MockTransform(mockAsset);
        await transformer.apply(transform);

        expect(transform.outputs.length, equals(1));

        final output = transform.outputs[0];
        expect(output.id.package, equals('pkg'));
        expect(output.id.path, equals('lib/src/file_to_transform.dart'));

        final contents = await output.readAsString();
        expect(contents, contains("import 'dart:async';"));

        verifyTransformedSourceIsValid(contents);
      });

      test('should transform a properly annotated class', () async {
        setUpTransformer();

        final mockAsset = createMockAsset(
            'lib/src/file_to_transform.dart',
            '''
          import 'dart:async';

          import 'package:w_common/disposable.dart';

          @AutoNullFieldsOnDispose()
          class DisposableExample extends Disposable {
            String field = 'field';

            void foo() {
              print(field);
            }
          }
        ''');

        final transform = new MockTransform(mockAsset);
        await transformer.apply(transform);

        expect(transform.outputs.length, equals(1));

        final output = transform.outputs[0];
        expect(output.id.package, equals('pkg'));
        expect(output.id.path, equals('lib/src/file_to_transform.dart'));

        final contents = await output.readAsString();
        expect(contents, contains('Future<Null> onDispose() async {'));
        expect(contents, contains('field = null;'));

        verifyTransformedSourceIsValid(contents);
      });

      test('should transform multiple classes', () async {
        setUpTransformer();

        final mockAsset = createMockAsset(
            'lib/src/file_to_transform.dart',
            '''
          import 'dart:async';

          import 'package:w_common/disposable.dart';

          @AutoNullFieldsOnDispose()
          class DisposableExample1 extends Disposable {
            String field1 = 'field1';

            void foo() {
              print(field1);
            }
          }

          @AutoNullFieldsOnDispose()
          class DisposableExample2 extends Disposable {
            String field2 = 'field2';

            void foo() {
              print(field2);
            }
          }
        ''');

        final transform = new MockTransform(mockAsset);
        await transformer.apply(transform);

        expect(transform.outputs.length, equals(1));

        final output = transform.outputs[0];
        expect(output.id.package, equals('pkg'));
        expect(output.id.path, equals('lib/src/file_to_transform.dart'));

        final contents = await output.readAsString();
        expect(contents, contains('Future<Null> onDispose() async {'));
        expect(contents, contains('field1 = null;'));
        expect(contents, contains('field2 = null;'));

        verifyTransformedSourceIsValid(contents);
      });

      test('should output a .diff.html file if mode=debug', () async {
        setUpTransformer(mode: BarbackMode.DEBUG);

        final mockAsset = createMockAsset(
            'lib/src/file_to_transform.dart',
            '''
          import 'dart:async';

          import 'package:w_common/disposable.dart';

          @AutoNullFieldsOnDispose()
          class DisposableExample extends Disposable {
            String field = 'field';

            void foo() {
              print(field);
            }
          }
        ''');

        final transform = new MockTransform(mockAsset);
        await transformer.apply(transform);

        expect(transform.outputs.length, equals(2));

        final output = transform.outputs[0];
        expect(output.id.package, equals('pkg'));
        expect(output.id.path, equals('lib/src/file_to_transform.dart'));

        final diff = transform.outputs[1];
        expect(diff.id.package, equals('pkg'));
        expect(
            diff.id.path,
            equals(
                'lib/src/file_to_transform.dart.disposable_transformer_diff.html'));
      });
    });
  });
}

MockAsset createMockAsset(String inputFilePath, String inputFileContents) {
  final assetId = new AssetId('pkg', inputFilePath);
  final asset = new MockAsset();
  when(asset.id).thenReturn(assetId);
  when(asset.readAsString())
      .thenAnswer((_) => new Future(() => inputFileContents));
  return asset;
}

class MockAsset extends Mock implements Asset {}

class MockDeclaringTransform extends Mock implements DeclaringTransform {
  final List<AssetId> declaredOutputs = <AssetId>[];

  @override
  void declareOutput(AssetId assetId) {
    declaredOutputs.add(assetId);
  }
}

class MockTransform extends Mock implements Transform {
  final List<Asset> outputs = <Asset>[];

  @override
  final Asset primaryInput;

  MockTransform(this.primaryInput);

  @override
  void addOutput(Asset output) {
    outputs.add(output);
  }
}
