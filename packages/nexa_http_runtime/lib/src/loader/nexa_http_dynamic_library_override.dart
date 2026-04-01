import 'nexa_http_host_platform.dart';

String? resolveNexaHttpDynamicLibraryOverridePath({
  required NexaHttpHostPlatform platform,
  required Map<String, String> environment,
}) {
  final variableName = switch (platform) {
    NexaHttpHostPlatform.android => 'NEXA_HTTP_NATIVE_ANDROID_LIB_PATH',
    NexaHttpHostPlatform.ios => 'NEXA_HTTP_NATIVE_IOS_LIB_PATH',
    NexaHttpHostPlatform.macos => 'NEXA_HTTP_NATIVE_MACOS_LIB_PATH',
    NexaHttpHostPlatform.windows => 'NEXA_HTTP_NATIVE_WINDOWS_LIB_PATH',
  };
  final value = environment[variableName]?.trim();
  return value != null && value.isNotEmpty ? value : null;
}
