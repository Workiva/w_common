import 'dart:async';
import 'dart:html';

import 'package:logging/logging.dart';
import 'package:w_common/disposable.dart';

int childCount;
int treeDepth;
StreamController controller;

ButtonElement createButton = querySelector('#create-button');
ButtonElement disposeButton = querySelector('#dispose-button');
InputElement childCountField = querySelector('#child-count-field');
InputElement treeDepthField = querySelector('#tree-depth-field');
TextAreaElement outputBox = querySelector('#output-box');

void addToOutput(String output) {
  outputBox.value += output + '\n';
}

Disposable createDisposableTree(int depth) {
  var child = new Disposable();

  for (int i = 0; i < childCount; i++) {
    child.manageStreamController(new StreamController());
    child.manageStreamSubscription(controller.stream.listen((_) {}));
  }

  if (depth == 0) {
    return child;
  }

  for (int i = 0; i < childCount; i++) {
    child.manageDisposable(createDisposableTree(depth - 1));
  }

  return child;
}

void main() {
  Logger.root.onRecord.listen((LogRecord rec) {
    addToOutput('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
  Logger.root.level = Level.INFO;

  Disposable.enableDebugMode();

  Disposable treeRoot;

  createButton.onClick.listen((_) {
    controller?.close();

    if (treeRoot != null) {
      window.alert('Dispose before creating a new tree');
    }

    childCount = int.parse(childCountField.value);
    treeDepth = int.parse(treeDepthField.value);
    controller = new StreamController.broadcast();

    treeRoot = createDisposableTree(treeDepth);
    addToOutput('Disposable tree size: ${treeRoot.disposalTreeSize}');
    outputBox.scrollTo(0, outputBox.scrollHeight);
  });

  disposeButton.onClick.listen((_) {
    treeRoot.dispose().then((_) {
      addToOutput('Disposable tree size: ${treeRoot.disposalTreeSize}');
      outputBox.scrollTo(0, outputBox.scrollHeight);
      treeRoot = null;
    });
  });
}
