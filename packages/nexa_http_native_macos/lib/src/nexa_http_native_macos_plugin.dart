import 'dart:ffi';
import 'dart:io';

import 'package:nexa_http_runtime/nexa_http_runtime.dart';

final class NexaHttpNativeMacosPlugin {
  NexaHttpNativeMacosPlugin._();

  static void registerWith() {
    registerNexaHttpNativeRuntime(const _NexaHttpNativeMacosRuntime());
  }
}

final class _NexaHttpNativeMacosRuntime implements NexaHttpNativeRuntime {
  const _NexaHttpNativeMacosRuntime();

  static const _environmentVariable = 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH';
  static const _libraryFileName = 'libnexa_http_native.dylib';

  @override
  DynamicLibrary open() {
    final explicitPath = Platform.environment[_environmentVariable];
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      return DynamicLibrary.open(explicitPath.trim());
    }
    return DynamicLibrary.open(_libraryFileName);
  }
}
