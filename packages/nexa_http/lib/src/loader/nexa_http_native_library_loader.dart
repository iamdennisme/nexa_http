import 'dart:ffi';

import 'nexa_http_platform_registry.dart';

DynamicLibrary loadNexaHttpDynamicLibrary({String? explicitPath}) {
  final trimmed = explicitPath?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    return DynamicLibrary.open(trimmed);
  }

  return NexaHttpPlatformRegistry.requireInstance().open();
}
