import 'dart:ffi';
import 'dart:io';

import 'package:nexa_http_native_runtime_internal/nexa_http_native_runtime_internal.dart';
import 'package:path/path.dart' as p;

final class NexaHttpNativeMacosPlugin {
  NexaHttpNativeMacosPlugin._();

  static void registerWith() {
    registerNexaHttpNativeRuntime(const _NexaHttpNativeMacosRuntime());
  }
}

final class _NexaHttpNativeMacosRuntime implements NexaHttpNativeRuntime {
  const _NexaHttpNativeMacosRuntime();

  @override
  DynamicLibrary open() {
    return DynamicLibrary.open(_resolvedBundledLibraryPath());
  }
}

String _resolvedBundledLibraryPath() {
  return p.normalize(
    p.join(
      File(Platform.resolvedExecutable).parent.path,
      '..',
      'Frameworks',
      'nexa_http_native_macos.framework',
      'Versions',
      'A',
      'Resources',
      'nexa_http_native.bundle',
      'Contents',
      'Resources',
      'libnexa_http_native.dylib',
    ),
  );
}
