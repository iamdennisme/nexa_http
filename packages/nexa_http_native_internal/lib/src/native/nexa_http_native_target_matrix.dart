import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const nexaHttpNativeAssetName = 'src/native/nexa_http_native_ffi.dart';

final class NexaHttpNativeTarget {
  const NexaHttpNativeTarget({
    required this.targetOS,
    required this.targetArchitecture,
    required this.releaseAssetFileName,
    required this.sourceArtifactFileName,
    required this.buildScriptName,
    required this.carrierPackageName,
    required this.integrationExecutionId,
    required this.runner,
    this.targetSdk,
    required this.rustTargetTriple,
    this.nativeAssetName = nexaHttpNativeAssetName,
  });

  final String targetOS;
  final String targetArchitecture;
  final String? targetSdk;
  final String releaseAssetFileName;
  final String sourceArtifactFileName;
  final String buildScriptName;
  final String carrierPackageName;
  final String rustTargetTriple;
  final String integrationExecutionId;
  final String runner;
  final String nativeAssetName;

  String get nativeAssetId => 'package:$carrierPackageName/$nativeAssetName';

  String materializationRelativePath(String profile) => p.join(
    profile,
    targetOS,
    targetArchitecture,
    targetSdk ?? 'none',
    releaseAssetFileName,
  );
}

final class NexaHttpNativeReleaseAssetDescriptor {
  const NexaHttpNativeReleaseAssetDescriptor({
    required this.targetOS,
    required this.targetArchitecture,
    required this.fileName,
    this.targetSdk,
  });

  final String targetOS;
  final String targetArchitecture;
  final String? targetSdk;
  final String fileName;
}

final class NexaHttpNativeReleaseManifestBundle {
  const NexaHttpNativeReleaseManifestBundle({
    required this.manifest,
    required this.sha256Lines,
  });

  final Map<String, Object?> manifest;
  final List<String> sha256Lines;
}

const nexaHttpSupportedNativeTargets = <NexaHttpNativeTarget>[
  NexaHttpNativeTarget(
    targetOS: 'android',
    targetArchitecture: 'arm64',
    releaseAssetFileName: 'nexa_http-native-android-arm64-v8a.so',
    rustTargetTriple: 'aarch64-linux-android',
    sourceArtifactFileName: 'libnexa_http_native_android_ffi.so',
    buildScriptName: 'build_native_android.sh',
    carrierPackageName: 'nexa_http_native_android',
    integrationExecutionId: 'android-linux',
    runner: 'ubuntu-latest',
  ),
  NexaHttpNativeTarget(
    targetOS: 'android',
    targetArchitecture: 'arm',
    releaseAssetFileName: 'nexa_http-native-android-armeabi-v7a.so',
    rustTargetTriple: 'armv7-linux-androideabi',
    sourceArtifactFileName: 'libnexa_http_native_android_ffi.so',
    buildScriptName: 'build_native_android.sh',
    carrierPackageName: 'nexa_http_native_android',
    integrationExecutionId: 'android-linux',
    runner: 'ubuntu-latest',
  ),
  NexaHttpNativeTarget(
    targetOS: 'android',
    targetArchitecture: 'x64',
    releaseAssetFileName: 'nexa_http-native-android-x86_64.so',
    rustTargetTriple: 'x86_64-linux-android',
    sourceArtifactFileName: 'libnexa_http_native_android_ffi.so',
    buildScriptName: 'build_native_android.sh',
    carrierPackageName: 'nexa_http_native_android',
    integrationExecutionId: 'android-linux',
    runner: 'ubuntu-latest',
  ),
  NexaHttpNativeTarget(
    targetOS: 'ios',
    targetArchitecture: 'arm64',
    targetSdk: 'iphoneos',
    releaseAssetFileName: 'nexa_http-native-ios-arm64.dylib',
    rustTargetTriple: 'aarch64-apple-ios',
    sourceArtifactFileName: 'libnexa_http_native_ios_ffi.dylib',
    buildScriptName: 'build_native_ios.sh',
    carrierPackageName: 'nexa_http_native_ios',
    integrationExecutionId: 'apple-macos',
    runner: 'macos-14',
  ),
  NexaHttpNativeTarget(
    targetOS: 'ios',
    targetArchitecture: 'arm64',
    targetSdk: 'iphonesimulator',
    releaseAssetFileName: 'nexa_http-native-ios-sim-arm64.dylib',
    rustTargetTriple: 'aarch64-apple-ios-sim',
    sourceArtifactFileName: 'libnexa_http_native_ios_ffi.dylib',
    buildScriptName: 'build_native_ios.sh',
    carrierPackageName: 'nexa_http_native_ios',
    integrationExecutionId: 'apple-macos',
    runner: 'macos-14',
  ),
  NexaHttpNativeTarget(
    targetOS: 'ios',
    targetArchitecture: 'x64',
    targetSdk: 'iphonesimulator',
    releaseAssetFileName: 'nexa_http-native-ios-sim-x64.dylib',
    rustTargetTriple: 'x86_64-apple-ios',
    sourceArtifactFileName: 'libnexa_http_native_ios_ffi.dylib',
    buildScriptName: 'build_native_ios.sh',
    carrierPackageName: 'nexa_http_native_ios',
    integrationExecutionId: 'apple-macos',
    runner: 'macos-14',
  ),
  NexaHttpNativeTarget(
    targetOS: 'macos',
    targetArchitecture: 'arm64',
    releaseAssetFileName: 'nexa_http-native-macos-arm64.dylib',
    rustTargetTriple: 'aarch64-apple-darwin',
    sourceArtifactFileName: 'libnexa_http_native_macos_ffi.dylib',
    buildScriptName: 'build_native_macos.sh',
    carrierPackageName: 'nexa_http_native_macos',
    integrationExecutionId: 'apple-macos',
    runner: 'macos-14',
  ),
  NexaHttpNativeTarget(
    targetOS: 'macos',
    targetArchitecture: 'x64',
    releaseAssetFileName: 'nexa_http-native-macos-x64.dylib',
    rustTargetTriple: 'x86_64-apple-darwin',
    sourceArtifactFileName: 'libnexa_http_native_macos_ffi.dylib',
    buildScriptName: 'build_native_macos.sh',
    carrierPackageName: 'nexa_http_native_macos',
    integrationExecutionId: 'apple-macos',
    runner: 'macos-14',
  ),
  NexaHttpNativeTarget(
    targetOS: 'windows',
    targetArchitecture: 'x64',
    releaseAssetFileName: 'nexa_http-native-windows-x64.dll',
    rustTargetTriple: 'x86_64-pc-windows-msvc',
    sourceArtifactFileName: 'nexa_http_native_windows_ffi.dll',
    buildScriptName: 'build_native_windows.sh',
    carrierPackageName: 'nexa_http_native_windows',
    integrationExecutionId: 'windows-x64',
    runner: 'windows-latest',
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

String builtArtifactPathForTarget(
  String sourceDir,
  NexaHttpNativeTarget target, {
  String mode = 'debug',
}) {
  return '$sourceDir/target/${target.rustTargetTriple}/$mode/${target.sourceArtifactFileName}';
}

final nexaHttpNativeReleaseAssetDescriptors = nexaHttpSupportedNativeTargets
    .map(
      (target) => NexaHttpNativeReleaseAssetDescriptor(
        targetOS: target.targetOS,
        targetArchitecture: target.targetArchitecture,
        targetSdk: target.targetSdk,
        fileName: target.releaseAssetFileName,
      ),
    )
    .toList(growable: false);

String sha256OfString(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}

Future<String> sha256OfFile(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

Future<NexaHttpNativeReleaseManifestBundle> buildNexaHttpNativeReleaseManifest({
  required String distDirectory,
  String? baseUrl,
}) async {
  final assets = <Map<String, Object?>>[];
  final shaLines = <String>[];

  for (final descriptor in nexaHttpNativeReleaseAssetDescriptors) {
    final file = File('$distDirectory/${descriptor.fileName}');
    if (!file.existsSync()) {
      throw StateError('Missing required native asset: ${file.path}');
    }

    final digest = await sha256OfFile(file);
    shaLines.add('$digest  ${descriptor.fileName}');
    assets.add(<String, Object?>{
      'target_os': descriptor.targetOS,
      'target_architecture': descriptor.targetArchitecture,
      if (descriptor.targetSdk != null) 'target_sdk': descriptor.targetSdk,
      'file_name': descriptor.fileName,
      'source_url': baseUrl == null || baseUrl.isEmpty
          ? descriptor.fileName
          : '$baseUrl/${descriptor.fileName}',
      'sha256': digest,
    });
  }

  return NexaHttpNativeReleaseManifestBundle(
    manifest: <String, Object?>{'package': 'nexa_http', 'assets': assets},
    sha256Lines: shaLines,
  );
}

Future<void> writeNexaHttpNativeReleaseManifestBundle({
  required String distDirectory,
  required String outputPath,
  String? shaOutputPath,
  String? baseUrl,
}) async {
  final bundle = await buildNexaHttpNativeReleaseManifest(
    distDirectory: distDirectory,
    baseUrl: baseUrl,
  );

  final manifestFile = File(outputPath);
  await manifestFile.parent.create(recursive: true);
  await manifestFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(bundle.manifest),
  );

  if (shaOutputPath != null && shaOutputPath.isNotEmpty) {
    final shaFile = File(shaOutputPath);
    await shaFile.parent.create(recursive: true);
    await shaFile.writeAsString('${bundle.sha256Lines.join('\n')}\n');
  }
}
