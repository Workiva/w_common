// @JS()
library idle_task_queue;

import 'dart:async';
import 'dart:html';
import 'dart:js';

// import 'package:js/js.dart';
import 'package:meta/meta.dart';

// / This calls the [requestIdleCallback] API directly.
///
/// Note that `requestIdleCallbackPolyfill.js` or another polyfill like it must
/// be included in order to use this API in browsers such as IE 11 or Edge which
/// do not support it.
///
/// Most tasks could be added using [enqueueIdleTask] instead.
// @JS()
// external int requestIdleCallback(IdleRequestCallback callback, [Map options]);

/// A handler which will be called during idle time.
typedef void IdleTaskHandler<T>(T input);

@immutable
class _IdleTask<T> {
  final IdleTaskHandler<T> handler;
  final T input;

  _IdleTask(this.handler, this.input);
}

/// Adds the task to a queue which will be called during idle time.
void enqueueIdleTask<T>(IdleTaskHandler<T> handler, T input) {
  // For unsupported browsers when the polyfill is not available,
  // we still want the task to be called eventually.
  if (!_doesBrowserSupportIdleCallback) {
    new Future.delayed(const Duration()).then((_) => handler(input));
    return;
  }

  _taskQueue.add(new _IdleTask<T>(handler, input));

  // Start running the queue if it has not been started.
  // If there is a task, the queue is already running and doesn't
  // need to be started again.
  if (_currentTask == null) {
    _currentTask = window.requestIdleCallback(
      allowInterop(_runQueue),
      <String, dynamic>{'timeout': 1000},
    );
  }
}

void _runQueue(IdleDeadline deadline) {
  while (!deadline.didTimeout &&
      deadline.timeRemaining() > 0 &&
      _taskQueue.isNotEmpty) {
    final task = _taskQueue.removeAt(0);
    task.handler(task.input);
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
