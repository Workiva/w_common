import 'dart:async';
import 'dart:html';

import 'package:logging/logging.dart';
import 'package:w_common/disposable.dart';

class TreeNode extends Disposable {
  @override
  String get disposableTypeName => 'TreeNode';

  TreeNode(int depth, int childCount) {
    manageStreamController(StreamController.broadcast());
    listenToStream(document.onDoubleClick, _onDoubleClick);

    if (depth > 0) {
      for (int i = 0; i < childCount; i++) {
        manageDisposable(TreeNode(depth - 1, childCount));
      }
    }
  }

  void _onDoubleClick(Event _) {
    print('document double clicked');
  }
}

void main() {
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
  Logger.root.level = Level.INFO;

  Disposable.enableDebugMode();

  ButtonElement createButton = querySelector('#create-button') as ButtonElement;
  ButtonElement disposeButton =
      querySelector('#dispose-button') as ButtonElement;
  InputElement? childCountField =
      querySelector('#child-count-field') as InputElement?;
  InputElement? treeDepthField =
      querySelector('#tree-depth-field') as InputElement?;

  TreeNode? treeRoot;

  createButton.onClick.listen((_) {
    if (treeRoot != null) {
      window.alert('Dispose before creating a new tree');
    }

    int childCount = int.parse(childCountField!.value!);
    int treeDepth = int.parse(treeDepthField!.value!);

    treeRoot = TreeNode(treeDepth, childCount);
    print('Disposable tree size: ${treeRoot!.disposalTreeSize}');
  });

  disposeButton.onClick.listen((_) {
    treeRoot?.dispose().then((_) {
      print('Disposable tree size: ${treeRoot!.disposalTreeSize}');
      treeRoot = null;
    });
  });
}
