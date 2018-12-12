// @JS()
library idle_task_queue;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:meta/meta.dart';

/// A handler which will be called during idle time.
typedef FutureOr<R> IdleTaskHandler<R>();

@immutable
class _IdleTask<R> {
  final IdleTaskHandler<R> handler;
  final Completer<R> completer = new Completer<R>();

  _IdleTask(this.handler);
}

/// Adds the task to a queue which will be called during idle time.
///
/// Returns the `Future` which will complete when the task has run.
///
/// May complete with an error if the task throws when called.
Future<R> enqueueIdleTask<R>(IdleTaskHandler<R> handler) {
  // For unsupported browsers when the polyfill is not available,
  // we still want the task to be called eventually.
  if (!_doesBrowserSupportIdleCallback) {
    return new Future.delayed(Duration.ZERO).then((_) async {
      return handler();
    });
  }

  final task = new _IdleTask<R>(handler);
  _taskQueue.add(task);

  // Start running the queue if it has not been started.
  // If there is a task, the queue is already running and doesn't
  // need to be started again.
  if (_currentTask == null) {
    _currentTask = window.requestIdleCallback(
      _runQueue,
      <String, dynamic>{'timeout': 1000},
    );
  }

  return task.completer.future;
}

Future _runQueue(IdleDeadline deadline) async {
  while (!deadline.didTimeout &&
      deadline.timeRemaining() > 0 &&
      _taskQueue.isNotEmpty) {
    final task = _taskQueue.removeAt(0);
    try {
      final r = await task.handler();
      task.completer.complete(r);
    } catch (e, t) {
      // Listeners to the completer future might throw.
      if (!task.completer.isCompleted) {
        try {
          task.completer.completeError(e, t);
        } catch (_) {}
      }
    }
  }

  if (_taskQueue.isNotEmpty) {
    _currentTask = window.requestIdleCallback(
      _runQueue,
      <String, dynamic>{
        'timeout': 1000,
      },
    );
  } else {
    _currentTask = null;
  }
}

bool get _doesBrowserSupportIdleCallback =>
    context['requestIdleCallback'] != null;

final List<_IdleTask> _taskQueue = [];
int _currentTask;
