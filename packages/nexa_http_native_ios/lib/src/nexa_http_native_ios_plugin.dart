import 'dart:ffi';
import 'dart:io';

import 'package:nexa_http/nexa_http_native_runtime.dart';

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
  String? get binaryExecutionLibraryPath {
    final explicitPath = Platform.environment[_environmentVariable];
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      return explicitPath.trim();
    }
    return null;
  }

  @override
  DynamicLibrary open() {
    final explicitPath = binaryExecutionLibraryPath;
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      return DynamicLibrary.open(explicitPath);
    }

    return DynamicLibrary.process();
  }
}
