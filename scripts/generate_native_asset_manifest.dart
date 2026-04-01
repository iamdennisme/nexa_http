import 'dart:io';

import 'package:nexa_http_distribution/nexa_http_distribution.dart';

Future<void> main(List<String> args) async {
  final config = _Config.parse(args);
  final distDir = Directory(config.distDirectory).absolute;
  if (!distDir.existsSync()) {
    stderr.writeln('Asset directory does not exist: ${distDir.path}');
    exit(64);
  }

  for (final descriptor in nexaHttpNativeReleaseAssetDescriptors) {
    final file = File('${distDir.path}/${descriptor.fileName}');
    if (!file.existsSync()) {
      stderr.writeln('Missing required native asset: ${file.path}');
      exit(66);
    }
  }

  await writeNexaHttpNativeReleaseManifestBundle(
    version: config.version,
    distDirectory: distDir.path,
    outputPath: config.outputPath,
    shaOutputPath: config.shaOutputPath,
    baseUrl: config.baseUrl,
  );
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
    var outputPath = 'dist/nexa_http_native_assets_manifest.json';
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
