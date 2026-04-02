import 'package:path/path.dart' as p;

final class NexaHttpNativeTarget {
  const NexaHttpNativeTarget({
    required this.targetOS,
    required this.targetArchitecture,
    required this.releaseAssetFileName,
    required this.packagedRelativePath,
    required this.sourceArtifactFileName,
    this.targetSdk,
    this.rustTargetTriple,
    this.legacyWorkspaceRelativePaths = const <String>[],
  });

  final String targetOS;
  final String targetArchitecture;
  final String? targetSdk;
  final String releaseAssetFileName;
  final String packagedRelativePath;
  final String sourceArtifactFileName;
  final String? rustTargetTriple;
  final List<String> legacyWorkspaceRelativePaths;

  List<String> sourceDirCandidates(String sourceDir) {
    return <String>[
      p.joinAll(<String>[sourceDir, ..._sourceArtifactSegments('debug')]),
      p.joinAll(<String>[sourceDir, ..._sourceArtifactSegments('release')]),
      p.normalize(
        p.joinAll(<String>[
          sourceDir,
          '..',
          '..',
          '..',
          '..',
          ..._sourceArtifactSegments('debug'),
        ]),
      ),
      p.normalize(
        p.joinAll(<String>[
          sourceDir,
          '..',
          '..',
          '..',
          '..',
          ..._sourceArtifactSegments('release'),
        ]),
      ),
    ];
  }

  List<String> runtimeWorkspaceRelativePaths() {
    return <String>[
      p.joinAll(_sourceArtifactSegments('debug')),
      p.joinAll(_sourceArtifactSegments('release')),
      ...legacyWorkspaceRelativePaths,
    ];
  }

  List<String> _sourceArtifactSegments(String mode) {
    return <String>[
      'target',
      if (rustTargetTriple != null) rustTargetTriple!,
      mode,
      sourceArtifactFileName,
    ];
  }
}

const nexaHttpSupportedNativeTargets = <NexaHttpNativeTarget>[
  NexaHttpNativeTarget(
    targetOS: 'android',
    targetArchitecture: 'arm64',
    releaseAssetFileName: 'nexa_http-native-android-arm64-v8a.so',
    packagedRelativePath:
        'android/src/main/jniLibs/arm64-v8a/libnexa_http_native.so',
    rustTargetTriple: 'aarch64-linux-android',
    sourceArtifactFileName: 'libnexa_http_native_android_ffi.so',
  ),
  NexaHttpNativeTarget(
    targetOS: 'android',
    targetArchitecture: 'arm',
    releaseAssetFileName: 'nexa_http-native-android-armeabi-v7a.so',
    packagedRelativePath:
        'android/src/main/jniLibs/armeabi-v7a/libnexa_http_native.so',
    rustTargetTriple: 'armv7-linux-androideabi',
    sourceArtifactFileName: 'libnexa_http_native_android_ffi.so',
  ),
  NexaHttpNativeTarget(
    targetOS: 'android',
    targetArchitecture: 'x64',
    releaseAssetFileName: 'nexa_http-native-android-x86_64.so',
    packagedRelativePath:
        'android/src/main/jniLibs/x86_64/libnexa_http_native.so',
    rustTargetTriple: 'x86_64-linux-android',
    sourceArtifactFileName: 'libnexa_http_native_android_ffi.so',
  ),
  NexaHttpNativeTarget(
    targetOS: 'ios',
    targetArchitecture: 'arm64',
    targetSdk: 'iphoneos',
    releaseAssetFileName: 'nexa_http-native-ios-arm64.dylib',
    packagedRelativePath: 'ios/Frameworks/libnexa_http_native-ios-arm64.dylib',
    rustTargetTriple: 'aarch64-apple-ios',
    sourceArtifactFileName: 'libnexa_http_native_ios_ffi.dylib',
    legacyWorkspaceRelativePaths: <String>[
      'packages/nexa_http_native_ios/ios/Frameworks/libnexa_http_native-ios-arm64.dylib',
    ],
  ),
  NexaHttpNativeTarget(
    targetOS: 'ios',
    targetArchitecture: 'arm64',
    targetSdk: 'iphonesimulator',
    releaseAssetFileName: 'nexa_http-native-ios-sim-arm64.dylib',
    packagedRelativePath:
        'ios/Frameworks/libnexa_http_native-ios-sim-arm64.dylib',
    rustTargetTriple: 'aarch64-apple-ios-sim',
    sourceArtifactFileName: 'libnexa_http_native_ios_ffi.dylib',
    legacyWorkspaceRelativePaths: <String>[
      'packages/nexa_http_native_ios/ios/Frameworks/libnexa_http_native-ios-sim-arm64.dylib',
    ],
  ),
  NexaHttpNativeTarget(
    targetOS: 'ios',
    targetArchitecture: 'x64',
    targetSdk: 'iphonesimulator',
    releaseAssetFileName: 'nexa_http-native-ios-sim-x64.dylib',
    packagedRelativePath:
        'ios/Frameworks/libnexa_http_native-ios-sim-x64.dylib',
    rustTargetTriple: 'x86_64-apple-ios',
    sourceArtifactFileName: 'libnexa_http_native_ios_ffi.dylib',
    legacyWorkspaceRelativePaths: <String>[
      'packages/nexa_http_native_ios/ios/Frameworks/libnexa_http_native-ios-sim-x64.dylib',
    ],
  ),
  NexaHttpNativeTarget(
    targetOS: 'macos',
    targetArchitecture: 'arm64',
    releaseAssetFileName: 'nexa_http-native-macos-arm64.dylib',
    packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
    sourceArtifactFileName: 'libnexa_http_native_macos_ffi.dylib',
    legacyWorkspaceRelativePaths: <String>[
      'packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/target/debug/libnexa_http_native.dylib',
      'packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/target/release/libnexa_http_native.dylib',
    ],
  ),
  NexaHttpNativeTarget(
    targetOS: 'macos',
    targetArchitecture: 'x64',
    releaseAssetFileName: 'nexa_http-native-macos-x64.dylib',
    packagedRelativePath: 'macos/Libraries/libnexa_http_native.dylib',
    sourceArtifactFileName: 'libnexa_http_native_macos_ffi.dylib',
    legacyWorkspaceRelativePaths: <String>[
      'packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/target/debug/libnexa_http_native.dylib',
      'packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/target/release/libnexa_http_native.dylib',
    ],
  ),
  NexaHttpNativeTarget(
    targetOS: 'windows',
    targetArchitecture: 'x64',
    releaseAssetFileName: 'nexa_http-native-windows-x64.dll',
    packagedRelativePath: 'windows/Libraries/nexa_http_native.dll',
    rustTargetTriple: 'x86_64-pc-windows-msvc',
    sourceArtifactFileName: 'nexa_http_native_windows_ffi.dll',
    legacyWorkspaceRelativePaths: <String>[
      'packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/target/x86_64-pc-windows-msvc/debug/nexa_http_native.dll',
      'packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/target/x86_64-pc-windows-msvc/release/nexa_http_native.dll',
    ],
  ),
];

NexaHttpNativeTarget? findNexaHttpNativeTarget({
  required String targetOS,
  required String targetArchitecture,
  required String? targetSdk,
}) {
  for (final target in nexaHttpSupportedNativeTargets) {
    if (target.targetOS == targetOS &&
        target.targetArchitecture == targetArchitecture &&
        target.targetSdk == targetSdk) {
      return target;
    }
  }
  return null;
}
