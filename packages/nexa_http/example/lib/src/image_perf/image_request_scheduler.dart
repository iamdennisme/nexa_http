import 'dart:async';
import 'dart:collection';

enum ImageRequestPriority { high, medium, low }

/// Provisional test harness for Task 1 contract tests.
/// The production priority scheduler behavior is implemented in a follow-up task.
final class ImageRequestScheduler {
  ImageRequestScheduler({
    required this.maxConcurrentRequests,
    required this.maxLowPriorityConcurrency,
  }) : assert(maxConcurrentRequests > 0),
       assert(maxLowPriorityConcurrency >= 0);

  final int maxConcurrentRequests;
  final int maxLowPriorityConcurrency;

  final Queue<Future<void> Function()> _queue = Queue<Future<void> Function()>();
  int _active = 0;

  Future<T> schedule<T>({
    required ImageRequestPriority priority,
    required Future<T> Function() task,
  }) {
    final completer = Completer<T>();
    _queue.add(() async {
      try {
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    _drain();
    return completer.future;
  }

  void _drain() {
    while (_active < maxConcurrentRequests && _queue.isNotEmpty) {
      final run = _queue.removeFirst();
      _active += 1;
      unawaited(
        run().whenComplete(() {
          _active -= 1;
          _drain();
        }),
      );
    }
  }
}
