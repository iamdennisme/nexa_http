import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import 'native/nexa_http_native_android_bindings.dart';

final class NexaHttpNativeAndroidPlugin {
  NexaHttpNativeAndroidPlugin._();

  static void registerWith() {
    registerNexaHttpNativeBindings(
      const NexaHttpNativeBindingsFactory(
        assetId:
            'package:nexa_http_native_android/src/native/nexa_http_native_ffi.dart',
        create: NexaHttpNativeAndroidBindings.new,
      ),
    );
  }
}
