import 'dart:isolate';

import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/starter.dart';
import 'package:disposable_analyzer_plugin/src/plugin.dart';

void main(List<String> args, SendPort sendPort) {
  ServerPluginStarter(DisposableAnalysisPlugin(PhysicalResourceProvider.INSTANCE)).start(sendPort);
}
