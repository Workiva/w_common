import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:w_common/disposable.dart';

Logger errorLogger = Logger('w_common.ErrorExample');

class RandomDisposableAdder extends Disposable {
  @override
  String get disposableTypeName => 'RandomDisposableAdder';

  void addRandomManager() {
    print('RandomDisposableAdder.addRandomManager');
    switch (Random().nextInt(5)) {
      case 0:
        listenToStream(Stream<Null>.empty(), (dynamic _) {});
        break;
      case 1:
        manageStreamController(StreamController());
        break;
      case 2:
        manageCompleter(Completer<Null>());
        break;
      case 3:
        manageAndReturnTypedDisposable(Disposable());
        break;
      default:
        manageDisposable(Disposable());
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

  MyManager? myManager;

  ButtonElement createMyManagerButton =
      querySelector('#create-MyManager-button') as ButtonElement;
  ButtonElement disposeMyManagerButton =
      querySelector('#dispose-MyManager-button') as ButtonElement;
  ButtonElement posthumousMyManagerButton =
      querySelector('#posthumous-MyManager-button') as ButtonElement;

  createMyManagerButton.onClick.listen((_) {
    myManager = MyManager();
  });

  disposeMyManagerButton.onClick.listen((_) {
    myManager?.dispose();
  });

  posthumousMyManagerButton.onClick.listen((_) {
    if (myManager == null) {
      print('You have not created myManager yet.');
    } else {
      try {
        myManager!.addRandomManager();
      } catch (e) {
        errorLogger.severe(e);
      }
    }
  });

  ErrorCreator? errorCreator;
  ButtonElement createErrorCreatorButton =
      querySelector('#create-ErrorCreator-button') as ButtonElement;
  ButtonElement disposeErrorCreatorButton =
      querySelector('#dispose-ErrorCreator-button') as ButtonElement;

  createErrorCreatorButton.onClick.listen((_) {
    errorCreator = ErrorCreator();
  });

  disposeErrorCreatorButton.onClick.listen((_) async {
    if (errorCreator == null) {
      print('You have not created the error creator object yet');
    } else {
      try {
        await errorCreator!.dispose();
      } catch (e) {
        errorLogger.severe(e);
      }
    }
  });
}
