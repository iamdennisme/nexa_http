import 'dart:ffi';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

final class NexaHttpNativeAndroidPlugin {
  NexaHttpNativeAndroidPlugin._();

  static void registerWith() {
    registerNexaHttpNativeRuntime(const _NexaHttpNativeAndroidRuntime());
  }
}

final class _NexaHttpNativeAndroidRuntime implements NexaHttpNativeRuntime {
  const _NexaHttpNativeAndroidRuntime();

  @override
  DynamicLibrary open() {
    return DynamicLibrary.open('libnexa_http_native.so');
  }
}
