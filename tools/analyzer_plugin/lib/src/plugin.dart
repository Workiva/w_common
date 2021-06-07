import 'dart:async';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
// ignore: implementation_imports
import 'package:analyzer/src/context/context_root.dart' as cr;
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/driver.dart';
// ignore: implementation_imports
import 'package:analyzer/src/context/builder.dart';

import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:disposable_analyzer_plugin/src/diagnostic/unmanaged.dart';



class DisposableAnalysisPlugin extends ServerPlugin {
  DisposableAnalysisPlugin(ResourceProvider provider) : super(provider);

  @override
  List<String> get fileGlobsToAnalyze => <String>['**/*.dart'];

  @override
  String get name => 'My fantastic plugin';

  @override
  String get version => '1.0.0';

  @override
  AnalysisDriverGeneric createAnalysisDriver(ContextRoot contextRoot) {
    final root = cr.ContextRoot(contextRoot.root, contextRoot.exclude, pathContext: resourceProvider.pathContext)
      ..optionsFilePath = contextRoot.optionsFile;
    final contextBuilder = ContextBuilder(resourceProvider, sdkManager, null)
      ..analysisDriverScheduler = analysisDriverScheduler
      ..byteStore = byteStore
      ..performanceLog = performanceLog
      ..fileContentOverlay = fileContentOverlay;
    final result = contextBuilder.buildDriver(root);
    runZoned(() {
      result.results.listen(getAllErrors);
    }, onError: (Object e, StackTrace stackTrace) {
      channel.sendNotification(PluginErrorParams(false, e.toString(), stackTrace.toString()).toNotification());
    });

    return result;
  }

  @override
  void sendNotificationsForSubscriptions(Map<String, List<AnalysisService>> subscriptions) {
    // TODO: implement sendNotificationsForSubscriptions
  }

  Future<List<AnalysisError>> getAllErrors(ResolvedUnitResult analysisResult) async {
    try {
      // If there is no relevant analysis result, notify the analyzer of no errors.
      if (analysisResult.unit == null || analysisResult.libraryElement == null) {
        channel.sendNotification(AnalysisErrorsParams(analysisResult.path, []).toNotification());
        return [];
      }

      final linter = ManageDisposables();
      analysisResult.unit.accept(linter.visitor);
      final errors = linter.getErrors(analysisResult);
      channel.sendNotification(AnalysisErrorsParams(analysisResult.path, errors).toNotification());
      return errors;
    } catch (e, stackTrace) {
      // Notify the analyzer that an exception happened.
      channel.sendNotification(PluginErrorParams(false, e.toString(), stackTrace.toString()).toNotification());
      return [];
    }
  }
}

//final error = AnalysisError(
//       code.errorSeverity,
//       code.type,
//       location,
//       _formatList(code.message, errorMessageArgs),
//       code.name,
//       correction: code.correction,
//       url: code.url,
//       hasFix: hasFix,
//     );

//static const hashCodeCode = DiagnosticCode(
//     'over_react_hash_code_as_key',
//     "Keys shouldn't be derived from hashCode since it is not unique."
//         " While 'hashCode' may seem like it is 'unique enough', 'hashCode' values by design"
//         " can collide with each other, and may collide often based on how they're implemented.",
//     AnalysisErrorSeverity.WARNING,
//     AnalysisErrorType.STATIC_WARNING,
//     correction: _sharedBadKeyUseInstead,
//   );

//const DiagnosticCode(
//     this.name,
//     this.message,
//     this.errorSeverity,
//     this.type, {
//     this.correction,
//     String url,
//   }) : url = url ?? '$analyzerPluginLintDocsUrl$name.html';
