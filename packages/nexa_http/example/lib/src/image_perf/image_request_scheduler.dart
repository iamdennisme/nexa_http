import 'dart:async';
import 'dart:collection';

enum ImageRequestPriority { high, medium, low }

final class ImageRequestScheduler {
  ImageRequestScheduler({
    required this.maxConcurrentRequests,
    required this.maxLowPriorityConcurrency,
  })  : assert(maxConcurrentRequests > 0),
        assert(maxLowPriorityConcurrency > 0),
        assert(maxLowPriorityConcurrency <= maxConcurrentRequests);

  final int maxConcurrentRequests;
  final int maxLowPriorityConcurrency;

  final Queue<_ScheduledImageRequest<dynamic>> _highPriorityQueue =
      Queue<_ScheduledImageRequest<dynamic>>();
  final Queue<_ScheduledImageRequest<dynamic>> _mediumPriorityQueue =
      Queue<_ScheduledImageRequest<dynamic>>();
  final Queue<_ScheduledImageRequest<dynamic>> _lowPriorityQueue =
      Queue<_ScheduledImageRequest<dynamic>>();

  int _activeRequestCount = 0;
  int _activeLowPriorityCount = 0;
  bool _isDraining = false;

  Future<T> schedule<T>({
    required ImageRequestPriority priority,
    required Future<T> Function() task,
  }) {
    final completer = Completer<T>();
    _queueFor(priority).add(
      _ScheduledImageRequest<T>(
        priority: priority,
        task: task,
        completer: completer,
      ),
    );
    _drain();
    return completer.future;
  }

  void _drain() {
    if (_isDraining) {
      return;
    }

    _isDraining = true;
    try {
      while (_activeRequestCount < maxConcurrentRequests) {
        final request = _dequeueNext();
        if (request == null) {
          return;
        }
        _start(request);
      }
    } finally {
      _isDraining = false;
    }
  }

  Queue<_ScheduledImageRequest<dynamic>> _queueFor(
    ImageRequestPriority priority,
  ) {
    return switch (priority) {
      ImageRequestPriority.high => _highPriorityQueue,
      ImageRequestPriority.medium => _mediumPriorityQueue,
      ImageRequestPriority.low => _lowPriorityQueue,
    };
  }

  _ScheduledImageRequest<dynamic>? _dequeueNext() {
    if (_highPriorityQueue.isNotEmpty) {
      return _highPriorityQueue.removeFirst();
    }
    if (_mediumPriorityQueue.isNotEmpty) {
      return _mediumPriorityQueue.removeFirst();
    }
    if (_lowPriorityQueue.isEmpty ||
        _activeLowPriorityCount >= maxLowPriorityConcurrency) {
      return null;
    }
    return _lowPriorityQueue.removeFirst();
  }

  void _start(_ScheduledImageRequest<dynamic> request) {
    _activeRequestCount += 1;
    if (request.priority == ImageRequestPriority.low) {
      _activeLowPriorityCount += 1;
    }

    unawaited(
      request.run().whenComplete(() {
        _activeRequestCount -= 1;
        if (request.priority == ImageRequestPriority.low) {
          _activeLowPriorityCount -= 1;
        }
        _drain();
      }),
    );
  }
}

final class _ScheduledImageRequest<T> {
  const _ScheduledImageRequest({
    required this.priority,
    required this.task,
    required this.completer,
  });

  final ImageRequestPriority priority;
  final Future<T> Function() task;
  final Completer<T> completer;

  Future<void> run() async {
    try {
      completer.complete(await task());
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  }
}
