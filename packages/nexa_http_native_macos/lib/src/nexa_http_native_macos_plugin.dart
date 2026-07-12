import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import 'native/nexa_http_native_macos_bindings.dart';

final class NexaHttpNativeMacosPlugin {
  NexaHttpNativeMacosPlugin._();

  static void registerWith() {
    registerNexaHttpNativeBindings(
      const NexaHttpNativeBindingsFactory(
        assetId:
            'package:nexa_http_native_macos/src/native/nexa_http_native_ffi.dart',
        create: NexaHttpNativeMacosBindings.new,
      ),
    );
  }
}
