import 'dart:ffi';
import 'dart:io';

import 'package:nexa_http_runtime/nexa_http_runtime.dart';

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
  DynamicLibrary open() {
    final explicitPath = Platform.environment[_environmentVariable];
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      return DynamicLibrary.open(explicitPath.trim());
    }

    return DynamicLibrary.open('libnexa_http_native.so');
  }
}
