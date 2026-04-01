import 'dart:io';

enum NexaHttpHostPlatform { android, ios, macos, windows }

NexaHttpHostPlatform currentNexaHttpHostPlatform() {
  if (Platform.isAndroid) {
    return NexaHttpHostPlatform.android;
  }
  if (Platform.isIOS) {
    return NexaHttpHostPlatform.ios;
  }
  if (Platform.isMacOS) {
    return NexaHttpHostPlatform.macos;
  }
  if (Platform.isWindows) {
    return NexaHttpHostPlatform.windows;
  }

  throw UnsupportedError('Unsupported platform for nexa_http native loading.');
}
