import 'package:analyzer/analyzer.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';
import 'package:transformer_utils/transformer_utils.dart';

void preservedLineNumbersTest(
    SourceFile sourceFile, TransformedSourceFile transformedFile) {
  final source = sourceFile.getText(0);
  final numSourceLines = source.split('\n').length;
  final transformedSource = transformedFile.getTransformedText();
  final numTransformedLines = transformedSource.split('\n').length;
  expect(numSourceLines, equals(numTransformedLines));
}

void verifyTransformedSourceIsValid(String transformedSource) {
  expect(() {
    parseCompilationUnit(transformedSource);
  }, returnsNormally,
      reason:
          'transformed source should parse without errors:\n$transformedSource');
}
