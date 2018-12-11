// @JS()
library idle_task_queue;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:meta/meta.dart';

const Duration _immediately = const Duration();

/// A handler which will be called during idle time.
typedef void IdleTaskHandler<T>(T input);

@immutable
class _IdleTask<T> {
  final IdleTaskHandler<T> handler;
  final T input;
  final Completer<Null> completer = new Completer<Null>();

  _IdleTask(this.handler, this.input);
}

/// Adds the task to a queue which will be called during idle time.
///
/// Returns the `Future` which will complete when the task has run.
///
/// May complete with an error if the task throws when called.
Future<Null> enqueueIdleTask<T>(IdleTaskHandler<T> handler, T input) {
  // For unsupported browsers when the polyfill is not available,
  // we still want the task to be called eventually.
  if (!_doesBrowserSupportIdleCallback) {
    return new Future.delayed(_immediately).then((_) async {
      handler(input);
    });
  }

  final task = new _IdleTask<T>(handler, input);
  _taskQueue.add(task);

  // Start running the queue if it has not been started.
  // If there is a task, the queue is already running and doesn't
  // need to be started again.
  if (_currentTask == null) {
    _currentTask = window.requestIdleCallback(
      allowInterop(_runQueue),
      <String, dynamic>{'timeout': 1000},
    );
  }

  return task.completer.future;
}

void _runQueue(IdleDeadline deadline) {
  while (!deadline.didTimeout &&
      deadline.timeRemaining() > 0 &&
      _taskQueue.isNotEmpty) {
    final task = _taskQueue.removeAt(0);
    try {
      task.handler(task.input);
      task.completer.complete();
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
      allowInterop(_runQueue),
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
