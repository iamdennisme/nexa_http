import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'nexa_http_native_digest.dart';

const nexaHttpNativeAssetsManifestFileName =
    'nexa_http_native_assets_manifest.json';

final class NexaHttpNativeReleaseAssetDescriptor {
  const NexaHttpNativeReleaseAssetDescriptor({
    required this.targetOS,
    required this.targetArchitecture,
    required this.fileName,
    this.targetSdk,
  });

  final String targetOS;
  final String targetArchitecture;
  final String fileName;
  final String? targetSdk;
}

final class NexaHttpNativeReleaseManifestBundle {
  const NexaHttpNativeReleaseManifestBundle({
    required this.manifest,
    required this.sha256Lines,
  });

  final Map<String, Object?> manifest;
  final List<String> sha256Lines;
}

const nexaHttpNativeReleaseAssetDescriptors = <NexaHttpNativeReleaseAssetDescriptor>[
  NexaHttpNativeReleaseAssetDescriptor(
    targetOS: 'android',
    targetArchitecture: 'arm64',
    fileName: 'nexa_http-native-android-arm64-v8a.so',
  ),
  NexaHttpNativeReleaseAssetDescriptor(
    targetOS: 'android',
    targetArchitecture: 'arm',
    fileName: 'nexa_http-native-android-armeabi-v7a.so',
  ),
  NexaHttpNativeReleaseAssetDescriptor(
    targetOS: 'android',
    targetArchitecture: 'x64',
    fileName: 'nexa_http-native-android-x86_64.so',
  ),
  NexaHttpNativeReleaseAssetDescriptor(
    targetOS: 'ios',
    targetArchitecture: 'arm64',
    targetSdk: 'iphoneos',
    fileName: 'nexa_http-native-ios-arm64.dylib',
  ),
  NexaHttpNativeReleaseAssetDescriptor(
    targetOS: 'ios',
    targetArchitecture: 'arm64',
    targetSdk: 'iphonesimulator',
    fileName: 'nexa_http-native-ios-sim-arm64.dylib',
  ),
  NexaHttpNativeReleaseAssetDescriptor(
    targetOS: 'ios',
    targetArchitecture: 'x64',
    targetSdk: 'iphonesimulator',
    fileName: 'nexa_http-native-ios-sim-x64.dylib',
  ),
  NexaHttpNativeReleaseAssetDescriptor(
    targetOS: 'macos',
    targetArchitecture: 'arm64',
    fileName: 'nexa_http-native-macos-arm64.dylib',
  ),
  NexaHttpNativeReleaseAssetDescriptor(
    targetOS: 'macos',
    targetArchitecture: 'x64',
    fileName: 'nexa_http-native-macos-x64.dylib',
  ),
  NexaHttpNativeReleaseAssetDescriptor(
    targetOS: 'windows',
    targetArchitecture: 'x64',
    fileName: 'nexa_http-native-windows-x64.dll',
  ),
];

Future<NexaHttpNativeReleaseManifestBundle> buildNexaHttpNativeReleaseManifest({
  required String version,
  required String distDirectory,
  DateTime? generatedAt,
  String? baseUrl,
}) async {
  final assets = <Map<String, Object?>>[];
  final shaLines = <String>[];

  for (final descriptor in nexaHttpNativeReleaseAssetDescriptors) {
    final file = File(p.join(distDirectory, descriptor.fileName));
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
      'source_url': baseUrl == null
          ? descriptor.fileName
          : '$baseUrl/${descriptor.fileName}',
      'sha256': digest,
    });
  }

  return NexaHttpNativeReleaseManifestBundle(
    manifest: <String, Object?>{
      'package': 'nexa_http',
      'package_version': version,
      'generated_at': (generatedAt ?? DateTime.now().toUtc()).toIso8601String(),
      'assets': assets,
    },
    sha256Lines: shaLines,
  );
}

Future<void> writeNexaHttpNativeReleaseManifestBundle({
  required String version,
  required String distDirectory,
  required String outputPath,
  DateTime? generatedAt,
  String? baseUrl,
  String? shaOutputPath,
}) async {
  final bundle = await buildNexaHttpNativeReleaseManifest(
    version: version,
    distDirectory: distDirectory,
    generatedAt: generatedAt,
    baseUrl: baseUrl,
  );

  final manifestFile = File(outputPath);
  await manifestFile.parent.create(recursive: true);
  await manifestFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(bundle.manifest),
  );

  if (shaOutputPath == null) {
    return;
  }

  final shaFile = File(shaOutputPath);
  await shaFile.parent.create(recursive: true);
  await shaFile.writeAsString('${bundle.sha256Lines.join('\n')}\n');
}
