import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

import 'native/nexa_http_native_windows_bindings.dart';

final class NexaHttpNativeWindowsPlugin {
  NexaHttpNativeWindowsPlugin._();

  static void registerWith() {
    registerNexaHttpNativeBindings(
      const NexaHttpNativeBindingsFactory(
        assetId:
            'package:nexa_http_native_windows/src/native/nexa_http_native_ffi.dart',
        create: NexaHttpNativeWindowsBindings.new,
      ),
    );
  }
}
