import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:w_common/disposable.dart';

Logger errorLogger = new Logger('w_common.ErrorExample');

class RandomDisposableAdder extends Disposable {
  @override
  String get disposableTypeName => 'RandomDisposableAdder';

  void addRandomManager() {
    print('RandomDisposableAdder.addRandomManager');
    switch (new Random().nextInt(6)) {
      case 0:
        listenToStream(new Stream.empty(), (_) {});
        break;
      case 1:
        manageStreamController(new StreamController());
        break;
      case 2:
        manageCompleter(new Completer());
        break;
      case 3:
        manageAndReturnDisposable(new Disposable());
        break;
      case 4:
        manageAndReturnTypedDisposable(new Disposable());
        break;
      default:
        manageDisposable(new Disposable());
    }
  }
}

class MyManager extends RandomDisposableAdder {
  MyManager() {
    print('creating MyManager');
  }

  @override
  String get disposableTypeName => 'MyManager';

  @override
  Future<Null> onDispose() {
    print('MyManager.onDispose');
    return super.onDispose();
  }
}

class ErrorCreator extends RandomDisposableAdder {
  ErrorCreator() {
    print('creating ErrorCreator');
  }

  @override
  String get disposableTypeName => 'ErrorCreator';

  @override
  Future<Null> onWillDispose() {
    print('ErrorCreator.onWillDispose');
    addRandomManager();
    return super.onDispose();
  }

  @override
  Future<Null> onDispose() {
    print('ErrorCreator.onDispose');
    addRandomManager();
    return super.onDispose();
  }
}

void main() {
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  Disposable.enableDebugMode();

  MyManager myManager;

  ButtonElement createMyManagerButton = querySelector('#create-MyManager-button');
  ButtonElement disposeMyManagerButton = querySelector('#dispose-MyManager-button');
  ButtonElement posthumousMyManagerButton = querySelector('#posthumous-MyManager-button');

  createMyManagerButton.onClick.listen((_) {
    myManager = new MyManager();
  });

  disposeMyManagerButton.onClick.listen((_) {
    myManager?.dispose();
  });

  posthumousMyManagerButton.onClick.listen((_) {
    if (myManager == null) {
      print('You have not created myManager yet.');
    } else {
      try {
        myManager.addRandomManager();
      } catch (e) {
        errorLogger.severe(e);
      }
    }
  });

  ErrorCreator errorCreator;
  ButtonElement createErrorCreatorButton = querySelector('#create-ErrorCreator-button');
  ButtonElement disposeErrorCreatorButton = querySelector('#dispose-ErrorCreator-button');

  createErrorCreatorButton.onClick.listen((_) {
    errorCreator = new ErrorCreator();
  });

  disposeErrorCreatorButton.onClick.listen((_) async {
    if (errorCreator == null) {
      print('You have not created the error creator object yet');
    } else {
      try {
        await errorCreator.dispose();
      } catch (e) {
        errorLogger.severe(e);
      }
    }
  });
}
