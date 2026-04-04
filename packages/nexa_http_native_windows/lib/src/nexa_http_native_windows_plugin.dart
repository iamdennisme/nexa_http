import 'dart:ffi';

import 'package:nexa_http_native_runtime_internal/nexa_http_native_runtime_internal.dart';

final class NexaHttpNativeWindowsPlugin {
  NexaHttpNativeWindowsPlugin._();

  static void registerWith() {
    registerNexaHttpNativeRuntime(const _NexaHttpNativeWindowsRuntime());
  }
}

final class _NexaHttpNativeWindowsRuntime implements NexaHttpNativeRuntime {
  const _NexaHttpNativeWindowsRuntime();

  static const _libraryFileName = 'nexa_http_native.dll';

  @override
  DynamicLibrary open() {
    return DynamicLibrary.open(_libraryFileName);
  }
}
