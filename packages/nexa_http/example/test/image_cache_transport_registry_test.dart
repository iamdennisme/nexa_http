import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_http_example/src/image_perf/image_cache_transport_registry.dart';

void main() {
  test('activates the nexa_http-backed cache manager', () {
    final defaultManager = _FakeCacheManager();
    final rustNetManager = _FakeCacheManager();
    final registry = ImageCacheTransportRegistry(
      defaultFactory: ({onSample}) => defaultManager,
      rustNetFactory: ({onSample}) => rustNetManager,
    );

    final active = registry.activate(ImageTransportMode.rustNet);

    expect(active, same(rustNetManager));
    expect(
      CachedNetworkImageProvider.defaultCacheManager,
      same(rustNetManager),
    );
  });

  test('clearCaches empties managers created for both transports', () async {
    final defaultManager = _FakeCacheManager();
    final rustNetManager = _FakeCacheManager();
    final registry = ImageCacheTransportRegistry(
      defaultFactory: ({onSample}) => defaultManager,
      rustNetFactory: ({onSample}) => rustNetManager,
    );

    registry.activate(ImageTransportMode.defaultHttp);
    registry.activate(ImageTransportMode.rustNet);

    await registry.clearCaches();

    expect(defaultManager.emptyCacheCallCount, 1);
    expect(rustNetManager.emptyCacheCallCount, 1);
  });

  test('dispose disposes managers created for both transports', () async {
    final defaultManager = _FakeCacheManager();
    final rustNetManager = _FakeCacheManager();
    final registry = ImageCacheTransportRegistry(
      defaultFactory: ({onSample}) => defaultManager,
      rustNetFactory: ({onSample}) => rustNetManager,
    );

    registry.activate(ImageTransportMode.defaultHttp);
    registry.activate(ImageTransportMode.rustNet);

    await registry.dispose();

    expect(defaultManager.disposeCallCount, 1);
    expect(rustNetManager.disposeCallCount, 1);
  });
}

class _FakeCacheManager extends Fake implements BaseCacheManager {
  int emptyCacheCallCount = 0;
  int disposeCallCount = 0;

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() async {
    disposeCallCount += 1;
  }

  @override
  Future<void> emptyCache() async {
    emptyCacheCallCount += 1;
  }

  @override
  Stream<FileInfo> getFile(
    String url, {
    String key = '',
    Map<String, String> headers = const <String, String>{},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FileInfo?> getFileFromMemory(String key) {
    throw UnimplementedError();
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Never> getSingleFile(
    String url, {
    String key = '',
    Map<String, String> headers = const <String, String>{},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Never> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Never> putFileStream(
    String url,
    Stream<List<int>> source, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeFile(String key) async {}
}
