import 'dart:ffi';
import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

final class NexaHttpNativeWindowsPlugin {
  NexaHttpNativeWindowsPlugin._();

  static void registerWith() {
    registerNexaHttpNativeRuntime(const _NexaHttpNativeWindowsRuntime());
  }
}

final class _NexaHttpNativeWindowsRuntime implements NexaHttpNativeRuntime {
  const _NexaHttpNativeWindowsRuntime();

  static const _environmentVariable = 'NEXA_HTTP_NATIVE_WINDOWS_LIB_PATH';
  static const _libraryFileName = 'nexa_http_native.dll';

  @override
  DynamicLibrary open() {
    final explicitPath = Platform.environment[_environmentVariable];
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      return DynamicLibrary.open(explicitPath.trim());
    }
    return DynamicLibrary.open(_libraryFileName);
  }
}
