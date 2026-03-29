import 'dart:ffi';
import 'dart:io';

import 'package:nexa_http/nexa_http_native_runtime.dart';

final class NexaHttpNativeAndroidPlugin {
  NexaHttpNativeAndroidPlugin._();

  static void registerWith() {
    registerNexaHttpNativeRuntime(const _NexaHttpNativeAndroidRuntime());
  }
}

final class _NexaHttpNativeAndroidRuntime implements NexaHttpNativeRuntime {
  const _NexaHttpNativeAndroidRuntime();

  static const _environmentVariable = 'NEXA_HTTP_NATIVE_ANDROID_LIB_PATH';

  @override
  String? get binaryExecutionLibraryPath {
    final explicitPath = Platform.environment[_environmentVariable];
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      return explicitPath.trim();
    }
    return 'libnexa_http_native.so';
  }

  @override
  DynamicLibrary open() {
    final path = binaryExecutionLibraryPath;
    if (path != null && path.trim().isNotEmpty) {
      return DynamicLibrary.open(path);
    }

    return DynamicLibrary.open('libnexa_http_native.so');
  }
}
