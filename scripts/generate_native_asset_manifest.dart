import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  final config = _Config.parse(args);
  final distDir = Directory(config.distDirectory);
  if (!distDir.existsSync()) {
    stderr.writeln('Asset directory does not exist: ${distDir.path}');
    exit(64);
  }

  final assets = <Map<String, Object?>>[];
  final shaLines = <String>[];

  for (final descriptor in _descriptors) {
    final file = File(p.join(distDir.path, descriptor.sourceName));
    if (!file.existsSync()) {
      stderr.writeln('Missing required native asset: ${file.path}');
      exit(66);
    }

    final digest = sha256.convert(await file.readAsBytes()).toString();
    shaLines.add('$digest  ${descriptor.sourceName}');

    assets.add(<String, Object?>{
      'target_os': descriptor.targetOS,
      'target_architecture': descriptor.targetArchitecture,
      if (descriptor.targetSdk != null) 'target_sdk': descriptor.targetSdk,
      'file_name': descriptor.sourceName,
      'source_url': config.baseUrl == null
          ? descriptor.sourceName
          : '${config.baseUrl!}/${descriptor.sourceName}',
      'sha256': digest,
    });
  }

  final manifestFile = File(config.outputPath);
  await manifestFile.parent.create(recursive: true);
  await manifestFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'package': 'rust_net',
      'package_version': config.version,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'assets': assets,
    }),
  );

  if (config.shaOutputPath != null) {
    final shaFile = File(config.shaOutputPath!);
    await shaFile.parent.create(recursive: true);
    await shaFile.writeAsString('${shaLines.join('\n')}\n');
  }
}

final class _Config {
  const _Config({
    required this.version,
    required this.distDirectory,
    required this.outputPath,
    required this.baseUrl,
    required this.shaOutputPath,
  });

  final String version;
  final String distDirectory;
  final String outputPath;
  final String? baseUrl;
  final String? shaOutputPath;

  static _Config parse(List<String> args) {
    String? version;
    var distDirectory = 'dist/native-assets';
    var outputPath = 'dist/rust_net_native_assets_manifest.json';
    String? baseUrl;
    String? shaOutputPath;

    for (var index = 0; index < args.length; index++) {
      final argument = args[index];
      if (argument == '--version') {
        version = args[++index];
      } else if (argument.startsWith('--version=')) {
        version = argument.substring('--version='.length);
      } else if (argument == '--dist') {
        distDirectory = args[++index];
      } else if (argument.startsWith('--dist=')) {
        distDirectory = argument.substring('--dist='.length);
      } else if (argument == '--output') {
        outputPath = args[++index];
      } else if (argument.startsWith('--output=')) {
        outputPath = argument.substring('--output='.length);
      } else if (argument == '--base-url') {
        baseUrl = args[++index];
      } else if (argument.startsWith('--base-url=')) {
        baseUrl = argument.substring('--base-url='.length);
      } else if (argument == '--sha-output') {
        shaOutputPath = args[++index];
      } else if (argument.startsWith('--sha-output=')) {
        shaOutputPath = argument.substring('--sha-output='.length);
      } else {
        stderr.writeln('Unknown argument: $argument');
        exit(64);
      }
    }

    if (version == null || version.isEmpty) {
      stderr.writeln('Missing required --version argument.');
      exit(64);
    }

    return _Config(
      version: version,
      distDirectory: distDirectory,
      outputPath: outputPath,
      baseUrl: baseUrl,
      shaOutputPath: shaOutputPath,
    );
  }
}

final class _AssetDescriptor {
  const _AssetDescriptor({
    required this.targetOS,
    required this.targetArchitecture,
    required this.sourceName,
    this.targetSdk,
  });

  final String targetOS;
  final String targetArchitecture;
  final String sourceName;
  final String? targetSdk;
}

const _descriptors = <_AssetDescriptor>[
  _AssetDescriptor(
    targetOS: 'android',
    targetArchitecture: 'arm64',
    sourceName: 'rust_net-native-android-arm64-v8a.so',
  ),
  _AssetDescriptor(
    targetOS: 'android',
    targetArchitecture: 'arm',
    sourceName: 'rust_net-native-android-armeabi-v7a.so',
  ),
  _AssetDescriptor(
    targetOS: 'android',
    targetArchitecture: 'x64',
    sourceName: 'rust_net-native-android-x86_64.so',
  ),
  _AssetDescriptor(
    targetOS: 'ios',
    targetArchitecture: 'arm64',
    targetSdk: 'iphoneos',
    sourceName: 'rust_net-native-ios-arm64.dylib',
  ),
  _AssetDescriptor(
    targetOS: 'ios',
    targetArchitecture: 'arm64',
    targetSdk: 'iphonesimulator',
    sourceName: 'rust_net-native-ios-sim-arm64.dylib',
  ),
  _AssetDescriptor(
    targetOS: 'ios',
    targetArchitecture: 'x64',
    targetSdk: 'iphonesimulator',
    sourceName: 'rust_net-native-ios-sim-x64.dylib',
  ),
  _AssetDescriptor(
    targetOS: 'macos',
    targetArchitecture: 'arm64',
    sourceName: 'rust_net-native-macos-arm64.dylib',
  ),
  _AssetDescriptor(
    targetOS: 'macos',
    targetArchitecture: 'x64',
    sourceName: 'rust_net-native-macos-x64.dylib',
  ),
  _AssetDescriptor(
    targetOS: 'linux',
    targetArchitecture: 'x64',
    sourceName: 'rust_net-native-linux-x64.so',
  ),
  _AssetDescriptor(
    targetOS: 'windows',
    targetArchitecture: 'x64',
    sourceName: 'rust_net-native-windows-x64.dll',
  ),
];
