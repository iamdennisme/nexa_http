import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http_example/src/image_perf/image_request_scheduler.dart';

void main() {
  test('dispatches visible requests before background requests', () async {
    final scheduler = ImageRequestScheduler(
      maxConcurrentRequests: 3,
      maxLowPriorityConcurrency: 1,
    );
    final starts = <String>[];
    final lowGate = Completer<void>();
    final highGate = Completer<void>();

    final lowA = scheduler.schedule<void>(
      priority: ImageRequestPriority.low,
      task: () async {
        starts.add('low-a');
        await lowGate.future;
      },
    );
    final lowB = scheduler.schedule<void>(
      priority: ImageRequestPriority.low,
      task: () async {
        starts.add('low-b');
      },
    );
    final high = scheduler.schedule<void>(
      priority: ImageRequestPriority.high,
      task: () async {
        starts.add('high');
        await highGate.future;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(starts.indexOf('high'), isNonNegative);
    expect(starts.indexOf('low-b'), greaterThan(starts.indexOf('high')));

    highGate.complete();
    lowGate.complete();
    await Future.wait<void>(<Future<void>>[lowA, lowB, high]);
  });

  test('enforces bounded low-priority concurrency', () async {
    const lowConcurrencyCap = 2;
    final scheduler = ImageRequestScheduler(
      maxConcurrentRequests: 6,
      maxLowPriorityConcurrency: lowConcurrencyCap,
    );
    final taskGates = List<Completer<void>>.generate(
      8,
      (_) => Completer<void>(),
    );
    var activeLow = 0;
    var peakLow = 0;

    final tasks = <Future<void>>[
      for (final gate in taskGates)
        scheduler.schedule<void>(
          priority: ImageRequestPriority.low,
          task: () async {
            activeLow += 1;
            if (activeLow > peakLow) {
              peakLow = activeLow;
            }
            await gate.future;
            activeLow -= 1;
          },
        ),
    ];

    await Future<void>.delayed(Duration.zero);
    expect(peakLow, lessThanOrEqualTo(lowConcurrencyCap));

    for (final gate in taskGates) {
      gate.complete();
    }
    await Future.wait<void>(tasks);
  });
}
