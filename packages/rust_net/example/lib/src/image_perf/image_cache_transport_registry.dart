import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'instrumented_http_file_service.dart';
import 'rust_net_image_file_service.dart';

enum ImageTransportMode {
  defaultHttp,
  rustNet,
}

typedef ImageCacheManagerFactory = BaseCacheManager Function({
  ImageRequestSampleCallback? onSample,
});

final class ImageCacheTransportRegistry {
  ImageCacheTransportRegistry({
    ImageCacheManagerFactory? defaultFactory,
    ImageCacheManagerFactory? rustNetFactory,
  })  : _defaultFactory = defaultFactory ?? _createDefaultManager,
        _rustNetFactory = rustNetFactory ?? _createRustNetManager;

  final ImageCacheManagerFactory _defaultFactory;
  final ImageCacheManagerFactory _rustNetFactory;
  final List<BaseCacheManager> _knownManagers = <BaseCacheManager>[];

  BaseCacheManager activate(
    ImageTransportMode mode, {
    ImageRequestSampleCallback? onSample,
  }) {
    final manager = switch (mode) {
      ImageTransportMode.defaultHttp =>
        _defaultFactory(onSample: onSample),
      ImageTransportMode.rustNet => _rustNetFactory(onSample: onSample),
    };
    _knownManagers.add(manager);
    CachedNetworkImageProvider.defaultCacheManager = manager;
    return manager;
  }

  Future<void> clearCaches() async {
    final visited = <BaseCacheManager>{};
    final futures = <Future<void>>[];
    for (final manager in _knownManagers) {
      if (visited.add(manager)) {
        futures.add(manager.emptyCache());
      }
    }
    await Future.wait(futures);
  }

  Future<void> dispose() async {
    final visited = <BaseCacheManager>{};
    final futures = <Future<void>>[];
    for (final manager in _knownManagers) {
      if (visited.add(manager)) {
        futures.add(manager.dispose());
      }
    }
    _knownManagers.clear();
    await Future.wait(futures);
  }

  static BaseCacheManager _createDefaultManager({
    ImageRequestSampleCallback? onSample,
  }) {
    return _InstrumentedImageCacheManager(
      cacheKey: 'rustNetExampleDefaultImages',
      fileService: InstrumentedHttpFileService(onSample: onSample),
    );
  }

  static BaseCacheManager _createRustNetManager({
    ImageRequestSampleCallback? onSample,
  }) {
    return _InstrumentedImageCacheManager(
      cacheKey: 'rustNetExampleRustNetImages',
      fileService: RustNetImageFileService(onSample: onSample),
    );
  }
}

final class _InstrumentedImageCacheManager extends CacheManager
    with ImageCacheManager {
  _InstrumentedImageCacheManager({
    required String cacheKey,
    required FileService fileService,
  })  : _fileService = fileService,
        super(
          Config(
            cacheKey,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 400,
            fileService: fileService,
          ),
        );

  final FileService _fileService;

  @override
  Future<void> dispose() async {
    if (_fileService case final RustNetImageFileService rustNetFileService) {
      await rustNetFileService.close();
    }
    await super.dispose();
  }
}
