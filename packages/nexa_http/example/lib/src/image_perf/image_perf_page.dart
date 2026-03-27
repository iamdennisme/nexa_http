import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import 'image_cache_transport_registry.dart';
import 'image_perf_metrics.dart';
import 'image_perf_result_payload.dart';

final class ImagePerfPage extends StatefulWidget {
  const ImagePerfPage({
    required this.baseUrl,
    this.initialMode = ImageTransportMode.defaultHttp,
    this.autorunScenario,
    this.imageCount = 24,
    super.key,
  });

  final String baseUrl;
  final ImageTransportMode initialMode;
  final ImagePerfScenario? autorunScenario;
  final int imageCount;

  @override
  State<ImagePerfPage> createState() => _ImagePerfPageState();
}

enum ImagePerfScenario { image, autoScroll }

class _ImagePerfPageState extends State<ImagePerfPage> {
  static const _firstScreenTarget = 8;

  final ImageCacheTransportRegistry _registry = ImageCacheTransportRegistry();
  final ScrollController _scrollController = ScrollController();
  final Stopwatch _sessionStopwatch = Stopwatch();
  final List<ImageRequestSample> _requestSamples = <ImageRequestSample>[];
  final List<FramePerfSample> _frameSamples = <FramePerfSample>[];
  final Set<int> _resolvedFirstScreenTiles = <int>{};

  ImageTransportMode _mode = ImageTransportMode.defaultHttp;
  int _runId = 0;
  Duration? _firstScreenElapsed;
  bool _isSessionActive = false;
  bool _isBusy = false;
  bool _captureFrameTimings = false;
  int? _rssBeforeBytes;
  int? _rssAfterBytes;
  int _rssPeakBytes = 0;
  Timer? _rssSampler;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    SchedulerBinding.instance.addTimingsCallback(_handleFrameTimings);
    final autorunScenario = widget.autorunScenario;
    if (autorunScenario != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_runAutorunScenario(autorunScenario));
      });
    }
  }

  @override
  void dispose() {
    _rssSampler?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_handleFrameTimings);
    _scrollController.dispose();
    unawaited(_registry.dispose());
    super.dispose();
  }

  Future<void> _runImageScenario() async {
    await _startSession();
  }

  Future<void> _runAutoScrollScenario() async {
    debugPrintSynchronously(
      'image_perf autorun: start autoScroll mode=$_mode imageCount=${widget.imageCount}',
    );
    await _startSession();
    if (!mounted) {
      return;
    }

    setState(() {
      _captureFrameTimings = true;
      _isBusy = true;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final hasClients = await _waitForScrollController();
      if (!hasClients) {
        debugPrintSynchronously(
          'image_perf autorun: scroll controller never attached',
        );
        return;
      }
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) {
        return;
      }
      if (widget.imageCount <= 24) {
        final scrollSeconds = 2;
        await _scrollController.animateTo(
          maxExtent,
          duration: Duration(seconds: scrollSeconds),
          curve: Curves.linear,
        );
        await _scrollController.animateTo(
          0,
          duration: Duration(seconds: scrollSeconds),
          curve: Curves.linear,
        );
      } else {
        final viewport = _scrollController.position.viewportDimension;
        final step = (viewport * 0.35).clamp(120.0, maxExtent);
        for (var offset = step; offset < maxExtent; offset += step) {
          await _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
          );
          await Future<void>.delayed(const Duration(milliseconds: 220));
        }
        await _scrollController.animateTo(
          maxExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
        await Future<void>.delayed(const Duration(milliseconds: 320));

        for (var offset = maxExtent - step; offset > 0; offset -= step) {
          await _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
          );
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
      debugPrintSynchronously(
        'image_perf autorun: finished autoScroll requests=${_requestSamples.length}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _captureFrameTimings = false;
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _startSession() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    await _registry.clearCaches();
    await _registry.dispose();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _registry.activate(_mode, onSample: _recordRequestSample);

    _sessionStopwatch
      ..reset()
      ..start();
    _startRssSampling();

    if (!mounted) {
      return;
    }

    setState(() {
      _runId += 1;
      _firstScreenElapsed = null;
      _requestSamples.clear();
      _frameSamples.clear();
      _resolvedFirstScreenTiles.clear();
      _captureFrameTimings = false;
      _isSessionActive = true;
      _isBusy = false;
    });
  }

  Future<void> _clearCaches() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });
    try {
      await _registry.clearCaches();
      await _registry.dispose();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!mounted) {
        return;
      }
      setState(() {
        _requestSamples.clear();
        _frameSamples.clear();
        _resolvedFirstScreenTiles.clear();
        _firstScreenElapsed = null;
        _isSessionActive = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _recordRequestSample(ImageRequestSample sample) {
    if (!mounted) {
      return;
    }
    setState(() {
      _requestSamples.add(sample);
    });
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    if (!_captureFrameTimings || !mounted) {
      return;
    }

    setState(() {
      for (final timing in timings) {
        _frameSamples.add(
          FramePerfSample(
            totalSpan: timing.totalSpan,
            buildDuration: timing.buildDuration,
            rasterDuration: timing.rasterDuration,
          ),
        );
      }
    });
  }

  void _handleTileResolved(int index) {
    if (index >= _firstScreenTarget ||
        _firstScreenElapsed != null ||
        !_resolvedFirstScreenTiles.add(index)) {
      return;
    }

    if (_resolvedFirstScreenTiles.length == _firstScreenTarget) {
      setState(() {
        _firstScreenElapsed = _sessionStopwatch.elapsed;
      });
    }
  }

  String _imageUrlForIndex(int index) {
    return Uri.parse(widget.baseUrl)
        .replace(
          path: '/image',
          queryParameters: <String, String>{
            'id': 'poster-$index',
            'run': '$_runId',
          },
        )
        .toString();
  }

  Future<void> _runAutorunScenario(ImagePerfScenario scenario) async {
    debugPrintSynchronously(
      'image_perf autorun: begin scenario=${scenario.name} mode=$_mode imageCount=${widget.imageCount}',
    );
    switch (scenario) {
      case ImagePerfScenario.image:
        await _runImageScenario();
        await Future<void>.delayed(const Duration(seconds: 2));
        break;
      case ImagePerfScenario.autoScroll:
        await _runAutoScrollScenario();
        break;
    }

    await _waitForSettledSamples();
    debugPrintSynchronously(
      'image_perf autorun: settled requests=${_requestSamples.length} successes=${_requestSamples.where((sample) => sample.succeeded).length}',
    );

    if (!mounted) {
      return;
    }

    _stopRssSampling();
    _rssAfterBytes = ProcessInfo.currentRss;
    final metrics = ImagePerfMetrics.fromSamples(
      firstScreenElapsed: _firstScreenElapsed,
      samples: _requestSamples,
      frameSamples: _frameSamples,
    );
    final resultJson = jsonEncode(
      buildImagePerfResultPayload(
        scenarioName: scenario.name,
        transportName: _mode.name,
        baseUrl: widget.baseUrl,
        imageCount: widget.imageCount,
        metrics: metrics,
        samples: _requestSamples,
        rssBeforeBytes: _rssBeforeBytes,
        rssAfterBytes: _rssAfterBytes,
        rssPeakBytes: _rssPeakBytes,
      ),
    );
    stdout.writeln(resultJson);
    debugPrintSynchronously(resultJson);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    exit(0);
  }

  Future<void> _waitForSettledSamples() async {
    final deadlineSeconds = widget.imageCount <= 24
        ? 8
        : ((widget.imageCount / 3).ceil()).clamp(12, 25);
    final deadline = Duration(seconds: deadlineSeconds);
    final stopwatch = Stopwatch()..start();
    while (mounted &&
        stopwatch.elapsed < deadline &&
        _requestSamples.length < widget.imageCount) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<bool> _waitForScrollController() async {
    const deadline = Duration(seconds: 5);
    final stopwatch = Stopwatch()..start();
    while (mounted && stopwatch.elapsed < deadline) {
      if (_scrollController.hasClients) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return _scrollController.hasClients;
  }

  void _startRssSampling() {
    _rssSampler?.cancel();
    _rssBeforeBytes = ProcessInfo.currentRss;
    _rssPeakBytes = _rssBeforeBytes ?? 0;
    _rssSampler = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final current = ProcessInfo.currentRss;
      if (current > _rssPeakBytes) {
        _rssPeakBytes = current;
      }
    });
  }

  void _stopRssSampling() {
    _rssSampler?.cancel();
    _rssSampler = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final metrics = ImagePerfMetrics.fromSamples(
      firstScreenElapsed: _firstScreenElapsed,
      samples: _requestSamples,
      frameSamples: _frameSamples,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Image performance',
          style: theme.textTheme.navLargeTitleTextStyle,
        ),
        const SizedBox(height: 12),
        Text(
          'Compare the default image transport against a nexa_http-backed '
          'cache pipeline using the local fixture server.',
          style: theme.textTheme.textStyle.copyWith(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 16),
        Text('Transport', style: theme.textTheme.navTitleTextStyle),
        const SizedBox(height: 8),
        CupertinoSlidingSegmentedControl<ImageTransportMode>(
          groupValue: _mode,
          children: const <ImageTransportMode, Widget>{
            ImageTransportMode.defaultHttp: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('Default'),
            ),
            ImageTransportMode.rustNet: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('nexa_http'),
            ),
          },
          onValueChanged: (value) {
            if (_isBusy || value == null) {
              return;
            }
            setState(() {
              _mode = value;
            });
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            CupertinoButton.filled(
              onPressed: _isBusy ? null : _runImageScenario,
              child: const Text('Run image test'),
            ),
            CupertinoButton(
              onPressed: _isBusy ? null : _runAutoScrollScenario,
              child: const Text('Auto scroll'),
            ),
            CupertinoButton(
              onPressed: _isBusy ? null : _clearCaches,
              child: const Text('Clear caches'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _PerfCard(
          title: 'Metrics',
          content: metrics.requestCount == 0
              ? 'No samples collected yet.'
              : [
                  'transport: ${_mode.name}',
                  'first_screen_ms: ${metrics.firstScreenElapsed?.inMilliseconds ?? '-'}',
                  'requests: ${metrics.requestCount}',
                  'success: ${metrics.successCount}',
                  'failure: ${metrics.failureCount}',
                  'avg_latency_ms: ${metrics.averageLatency.inMilliseconds}',
                  'p95_latency_ms: ${metrics.p95Latency.inMilliseconds}',
                  'bytes: ${metrics.totalBytes}',
                  'throughput_mib_s: ${metrics.throughputMiBPerSecond.toStringAsFixed(2)}',
                  'slow_frames: ${metrics.slowFrameCount}',
                  'max_raster_ms: ${metrics.maxRasterDuration.inMilliseconds}',
                ].join('\n'),
        ),
        const SizedBox(height: 16),
        _PerfCard(
          title: 'Preview Grid',
          content: _isSessionActive
              ? 'Run #$_runId loading ${widget.imageCount} fixture images from ${widget.baseUrl}'
              : 'Press "Run image test" to load fixture images.',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 480,
          child: _isSessionActive
              ? GridView.builder(
                  controller: _scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: widget.imageCount,
                  itemBuilder: (context, index) {
                    return _ImageTile(
                      index: index,
                      url: _imageUrlForIndex(index),
                      onResolved: _handleTileResolved,
                    );
                  },
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: CupertinoColors.secondarySystemBackground
                        .resolveFrom(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: CupertinoColors.separator.resolveFrom(context),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Waiting to start',
                      style: theme.textTheme.textStyle.copyWith(
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

final class _PerfCard extends StatelessWidget {
  const _PerfCard({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.navTitleTextStyle),
            const SizedBox(height: 12),
            Text(
              content,
              style: theme.textTheme.textStyle.copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ImageTile extends StatefulWidget {
  const _ImageTile({
    required this.index,
    required this.url,
    required this.onResolved,
  });

  final int index;
  final String url;
  final ValueChanged<int> onResolved;

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  bool _didReportResolved = false;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image(
              image: CachedNetworkImageProvider(
                widget.url,
                headers: const <String, String>{'accept': 'image/png'},
              ),
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if ((wasSynchronouslyLoaded || frame != null) &&
                    !_didReportResolved) {
                  _didReportResolved = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      widget.onResolved(widget.index);
                    }
                  });
                }
                return child;
              },
              errorBuilder: (context, error, stackTrace) {
                return ColoredBox(
                  color: CupertinoColors.systemRed.resolveFrom(context),
                  child: Center(
                    child: Text(
                      'ERR',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .navTitleTextStyle
                          .copyWith(color: CupertinoColors.white),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    '#${widget.index}',
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .tabLabelTextStyle
                        .copyWith(color: CupertinoColors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
