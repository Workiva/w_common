import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';

// ignore: prefer_generic_function_type_aliases, avoid_private_typedef_functions
typedef void _VisitVariableDeclaration(VariableDeclaration node);

// ignore: prefer_generic_function_type_aliases, avoid_private_typedef_functions
typedef bool _Predicate(AstNode node);

// ignore: prefer_generic_function_type_aliases
typedef _Predicate _PredicateBuilder(VariableDeclaration v);

const _name = 'manage_disposables';
const _desc = r'Close instances of `dart.core.Sink`.';
const _correction = r'Manage it.';

class ManageDisposables {

  ManageDisposables();

  AstVisitor get visitor => _Visitor(this);

  final _lints = <VariableDeclaration>[];
  List<AnalysisError> getErrors(ResolvedUnitResult result) => _lints.map((d) =>
      AnalysisError(
      AnalysisErrorSeverity.ERROR,
      AnalysisErrorType.STATIC_WARNING,
      result.locationFor(d),
      _getMessage(d),
      _name,
      correction: _correction,
      url: '',
      hasFix: false,
    )).toList();

  void reportLint(VariableDeclaration declaration) {
    _lints.add(declaration);
  }
}

class _Visitor extends SimpleAstVisitor {
  static _PredicateBuilder _isSinkReturn =
      (VariableDeclaration v) =>
      (n) =>
  n is ReturnStatement &&
      n.expression is SimpleIdentifier &&
      (n.expression as SimpleIdentifier).token.lexeme == v.name.token.lexeme;

  static _PredicateBuilder _hasConstructorFieldInitializers =
      (VariableDeclaration v) =>
      (n) =>
  n is ConstructorFieldInitializer &&
      n.fieldName.name == v.name.token.lexeme;

  static _PredicateBuilder _hasFieldFormalParemeter =
      (VariableDeclaration v) =>
      (n) =>
  n is FieldFormalParameter &&
      n.identifier.name == v.name.token.lexeme;

  static List<_PredicateBuilder> _variablePredicateBuiders = [_isSinkReturn];
  static List<_PredicateBuilder> _fieldPredicateBuiders =
  [_hasConstructorFieldInitializers, _hasFieldFormalParemeter];

  final ManageDisposables rule;

  _Visitor(this.rule);

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    final function = node.thisOrAncestorOfType<FunctionBody>();
    node.variables.variables.forEach(_buildVariableReporter(function, _variablePredicateBuiders));
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final classDecl = node.thisOrAncestorOfType<CompilationUnit>();
    node.fields.variables.forEach(_buildVariableReporter(classDecl, _fieldPredicateBuiders));
  }

  /// Builds a function that reports the variable node if the set of nodes
  /// inside the [container] node is empty for all the predicates resulting
  /// from building (predicates) with the provided [predicateBuilders] evaluated
  /// in the variable.
  _VisitVariableDeclaration _buildVariableReporter(AstNode container,
      List<_PredicateBuilder> predicateBuilders) =>
          (VariableDeclaration sink) {
        if (!_implementsDartCoreSink(sink.declaredElement.type)) {
          return;
        }

        List<AstNode> containerNodes = _traverseNodesInDFS(container);

        List<Iterable<AstNode>> validators = <Iterable<AstNode>>[];
        predicateBuilders.forEach((f) {
          validators.add(containerNodes.where(f(sink)));
        });

        validators.add(_findSinkAssignments(containerNodes, sink));
        validators.add(_findNodesClosingSink(containerNodes, sink));
        validators.add(_findCloseCallbackNodes(containerNodes, sink));
        // If any function is invoked with our sink, we suppress lints. This is
        // because it is not so uncommon to close the sink there. We might not
        // have access to the body of such function at analysis time, so trying
        // to infer if the close method is invoked there is not always possible.
        // TODO: Should there be another lint more relaxed that omits this step?
        validators.add(_findMethodInvocations(containerNodes, sink));

        // Read this as: validators.forAll((i) => i.isEmpty).
        if (!validators.any((i) => i.isNotEmpty)) {
          rule.reportLint(sink);
        }
      };
}

Iterable<AstNode> _findSinkAssignments(Iterable<AstNode> containerNodes,
    VariableDeclaration sink) =>
    containerNodes.where((n) {
      return n is AssignmentExpression &&
          ((n.leftHandSide is SimpleIdentifier &&
              // Assignment to sink as variable.
              (n.leftHandSide as SimpleIdentifier).token.lexeme ==
                  sink.name.token.lexeme) ||
              // Assignment to sink as setter.
              (n.leftHandSide is PropertyAccess &&
                  (n.leftHandSide as PropertyAccess)
                      .propertyName.token.lexeme == sink.name.token.lexeme))
          // Being assigned another reference.
          && n.rightHandSide is SimpleIdentifier;
    });

Iterable<AstNode> _findMethodInvocations(Iterable<AstNode> containerNodes,
    VariableDeclaration sink) {
  final prefixedIdentifiers = containerNodes.whereType<MethodInvocation>();
  return prefixedIdentifiers.where((n) =>
      n.argumentList.arguments.map((e) => e is SimpleIdentifier ? e.name : '')
          .contains(sink.name.token.lexeme));
}

Iterable<AstNode> _findCloseCallbackNodes(Iterable<AstNode> containerNodes,
    VariableDeclaration sink) {
  var prefixedIdentifiers = containerNodes.whereType<PrefixedIdentifier>();
  return prefixedIdentifiers.where((n) =>
  n.prefix.token.lexeme == sink.name.token.lexeme &&
      n.identifier.token.lexeme == 'close');
}

Iterable<AstNode> _findNodesClosingSink(Iterable<AstNode> classNodes,
    VariableDeclaration variable) =>
    classNodes.where(
            (n) =>
        n is MethodInvocation &&
            n.methodName.name == 'close' &&
            ((n.target is SimpleIdentifier &&
                (n.target as SimpleIdentifier).name == variable.name.name) ||
                (n.thisOrAncestorMatching((a) => a == variable) != null)));

bool _implementsDartCoreSink(DartType type) {
  final element = type.element as ClassElement;
  return !element.isSynthetic &&
      type is InterfaceType &&
      element.allSupertypes.any(_isDartCoreSink);
}

bool _isDartCoreSink(InterfaceType interface) {
  return interface.name == '_Disposable';// &&
      // interface.element.library.name == 'w_common.src.common.disposable'; // TODO: Is this the right name?
}

String _getMessage(VariableDeclaration sink) {
  final type = sink.declaredElement.type as ClassElement;

  if (!type.isSynthetic && type is InterfaceType)
      return 'dusty: ${type.allSupertypes.firstWhere((i) => i.name == '_Disposable').element.library.name}';
  
  return 'dusty: WHO KNOWS?';
}


/// Builds the list resulting from traversing the node in DFS and does not
/// include the node itself.
List<AstNode> _traverseNodesInDFS(AstNode node) {
  List<AstNode> nodes = [];
  node.childEntities
      .whereType<AstNode>()
      .forEach((c) {
    nodes.add(c);
    nodes.addAll(_traverseNodesInDFS(c));
  });
  return nodes;
}

class UnmanagedMessage {
  final VariableDeclaration declaration;
  final String message;

  UnmanagedMessage(this.declaration, this.message);
}

extension ResultLocation on ResolvedUnitResult {
  Location location({
    int offset,
    int end,
    int length,
    SourceRange range,
  }) {
    if (range != null) {
      offset = range.offset;
      length = range.length;
      end = range.end;
    } else {
      if (offset == null) {
        throw ArgumentError.notNull('offset or range');
      }
      if (end != null && length != null) {
        throw ArgumentError('Cannot specify both `end` and `length`.');
      } else if (length != null) {
        end = offset + length;
      } else if (end != null) {
        length = end - offset;
      } else {
        end = offset;
        length = 0;
      }
    }

    final info = lineInfo.getLocation(offset);
    return Location(path, offset, length, info.lineNumber, info.columnNumber);
  }

  Location locationFor(SyntacticEntity entity) {
    return location(offset: entity.offset, length: entity.length);
  }
}
