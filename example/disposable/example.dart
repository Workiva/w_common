import 'dart:async';
import 'dart:html';

import 'package:logging/logging.dart';
import 'package:w_common/disposable.dart';

class TreeNode extends Disposable {
  TreeNode(int depth, int childCount) {
    manageStreamController(new StreamController.broadcast());
    manageStreamSubscription(document.onDoubleClick.listen(_onDoubleClick));

    if (depth > 0) {
      for (int i = 0; i < childCount; i++) {
        manageDisposable(new TreeNode(depth - 1, childCount));
      }
    }
  }

  void _onDoubleClick(MouseEvent _) {
    print('document double clicked');
  }
}

void main() {
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
  Logger.root.level = Level.INFO;

  Disposable.enableDebugMode();

  ButtonElement createButton = querySelector('#create-button');
  ButtonElement disposeButton = querySelector('#dispose-button');
  InputElement childCountField = querySelector('#child-count-field');
  InputElement treeDepthField = querySelector('#tree-depth-field');

  TreeNode treeRoot;

  createButton.onClick.listen((_) {
    if (treeRoot != null) {
      window.alert('Dispose before creating a new tree');
    }

    int childCount = int.parse(childCountField.value);
    int treeDepth = int.parse(treeDepthField.value);

    treeRoot = new TreeNode(treeDepth, childCount);
    print('Disposable tree size: ${treeRoot.disposalTreeSize}');
  });

  disposeButton.onClick.listen((_) {
    treeRoot.dispose().then((_) {
      print('Disposable tree size: ${treeRoot.disposalTreeSize}');
      treeRoot = null;
    });
  });
}
