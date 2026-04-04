import 'dart:ffi';
import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

final class NexaHttpNativeIosPlugin {
  NexaHttpNativeIosPlugin._();

  static void registerWith() {
    registerNexaHttpNativeRuntime(const _NexaHttpNativeIosRuntime());
  }
}

final class _NexaHttpNativeIosRuntime implements NexaHttpNativeRuntime {
  const _NexaHttpNativeIosRuntime();

  static const _environmentVariable = 'NEXA_HTTP_NATIVE_IOS_LIB_PATH';

  @override
  DynamicLibrary open() {
    final explicitPath = Platform.environment[_environmentVariable];
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      return DynamicLibrary.open(explicitPath.trim());
    }

    return DynamicLibrary.process();
  }
}
