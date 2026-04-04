import 'dart:ffi';

import 'package:nexa_http_native_runtime_internal/nexa_http_native_runtime_internal.dart';

final class NexaHttpNativeIosPlugin {
  NexaHttpNativeIosPlugin._();

  static void registerWith() {
    registerNexaHttpNativeRuntime(const _NexaHttpNativeIosRuntime());
  }
}

final class _NexaHttpNativeIosRuntime implements NexaHttpNativeRuntime {
  const _NexaHttpNativeIosRuntime();

  @override
  DynamicLibrary open() {
    return DynamicLibrary.process();
  }
}
