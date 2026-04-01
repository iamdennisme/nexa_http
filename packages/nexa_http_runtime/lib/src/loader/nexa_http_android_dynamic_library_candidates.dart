List<String> resolveNexaHttpAndroidDynamicLibraryCandidates() {
  return const <String>[
    'libnexa_http_native.so',
    'libnexa_http.so',
    'libnexa_http_native_android_ffi.so',
    'libnexa_http-native-android-arm64.so',
    'libnexa_http-native-android-arm.so',
    'libnexa_http-native-android-x64.so',
  ];
}
