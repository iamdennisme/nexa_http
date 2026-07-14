import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import 'native/nexa_http_native_ios_bindings.dart';

final class NexaHttpNativeIosPlugin {
  NexaHttpNativeIosPlugin._();

  static void registerWith() {
    registerNexaHttpNativeBindings(
      const NexaHttpNativeBindingsFactory(
        assetId:
            'package:nexa_http_native_ios/src/native/nexa_http_native_ffi.dart',
        create: NexaHttpNativeIosBindings.new,
      ),
    );
  }
}
