import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const rustNetNativeAssetName = 'src/native/rust_net_native_ffi.dart';
const _manifestPathUserDefine = 'rust_net_manifest_path';
const _manifestUrlUserDefine = 'rust_net_manifest_url';
const _releaseBaseUrlUserDefine = 'rust_net_release_base_url';
const _githubReleaseBaseUrl =
    'https://github.com/iamdennisme/rust_net/releases/download';
const _manifestFileName = 'rust_net_native_assets_manifest.json';

final class RustNetNativeAssetBundle {
  RustNetNativeAssetBundle._();

  static Future<CodeAsset> resolve(BuildInput input) async {
    final manifestOverride = input.userDefines.path(_manifestPathUserDefine) != null ||
        input.userDefines[_manifestUrlUserDefine] is String;

    final localArtifact = manifestOverride
        ? null
        : await _maybeResolveLocalWorkspaceArtifact(input);
    final legacyArtifact = manifestOverride || localArtifact != null
        ? null
        : await _maybeResolveLegacyPackagedArtifact(input);
    final materialized =
        localArtifact ?? legacyArtifact ?? await _downloadFromManifest(input);

    return CodeAsset(
      package: input.packageName,
      name: rustNetNativeAssetName,
      linkMode: DynamicLoadingBundled(),
      file: materialized.uri,
    );
  }

  static Future<File?> _maybeResolveLocalWorkspaceArtifact(BuildInput input) async {
    if (input.config.code.targetOS != OS.current ||
        input.config.code.targetArchitecture != Architecture.current) {
      return null;
    }

    final packageRoot = Directory.fromUri(input.packageRoot);
    final targetRoot = p.join(packageRoot.path, 'native', 'rust_net_native', 'target');
    final fileName = input.config.code.targetOS.dylibFileName('rust_net_native');
    final candidates = <String>[
      p.join(targetRoot, 'debug', fileName),
      p.join(targetRoot, 'release', fileName),
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) {
        return file;
      }
    }

    final manifestPath = p.join(packageRoot.path, 'native', 'rust_net_native', 'Cargo.toml');
    final result = await Process.run(
      'cargo',
      <String>['build', '--manifest-path', manifestPath],
      workingDirectory: packageRoot.path,
    );
    if (result.exitCode != 0) {
      return null;
    }

    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  static Future<File?> _maybeResolveLegacyPackagedArtifact(BuildInput input) async {
    final packageRoot = input.packageRoot;
    final targetOS = input.config.code.targetOS;
    final targetArchitecture = input.config.code.targetArchitecture;

    final candidates = <Uri>[
      switch (targetOS) {
        OS.macOS => packageRoot.resolve(
            '../rust_net_native_macos/macos/Libraries/librust_net_native.dylib',
          ),
        OS.linux => packageRoot.resolve(
            '../rust_net_native_linux/linux/Libraries/librust_net_native.so',
          ),
        OS.windows => packageRoot.resolve(
            '../rust_net_native_windows/windows/Libraries/rust_net_native.dll',
          ),
        OS.android => packageRoot.resolve(
            '../rust_net_native_android/android/src/main/jniLibs/${_androidAbi(targetArchitecture)}/librust_net_native.so',
          ),
        OS.iOS => packageRoot.resolve(
            '../rust_net_native_ios/ios/Frameworks/${_iosLibraryName(targetArchitecture, _targetSdk(input))}',
          ),
        _ => packageRoot,
      },
    ].where((uri) => uri != packageRoot).toList(growable: false);

    for (final candidate in candidates) {
      final file = File.fromUri(candidate);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  static Future<File> _downloadFromManifest(BuildInput input) async {
    final manifestUri = await _resolveManifestUri(input);
    final manifest = await _RustNetNativeAssetManifest.load(manifestUri);
    final entry = manifest.select(
      packageVersion: _packageVersion(input.packageRoot),
      targetOS: input.config.code.targetOS,
      targetArchitecture: input.config.code.targetArchitecture,
      targetSdk: _targetSdk(input),
    );

    final outputDirectory = Directory.fromUri(
      input.outputDirectoryShared.resolve('rust_net_native/${entry.cacheKey}/'),
    );
    await outputDirectory.create(recursive: true);

    final destination = File.fromUri(outputDirectory.uri.resolve(entry.fileName));
    if (await destination.exists()) {
      final existingDigest = await _sha256Of(destination);
      if (existingDigest == entry.sha256) {
        return destination;
      }
      await destination.delete();
    }

    final sourceUri = entry.resolveSourceUri(manifest.baseUri);
    await _copyUriToFile(sourceUri, destination);

    final actualDigest = await _sha256Of(destination);
    if (actualDigest != entry.sha256) {
      throw StateError(
        'Checksum mismatch for $sourceUri. Expected ${entry.sha256}, got $actualDigest.',
      );
    }

    return destination;
  }

  static Future<Uri> _resolveManifestUri(BuildInput input) async {
    final manifestPath = input.userDefines.path(_manifestPathUserDefine);
    if (manifestPath != null) {
      return manifestPath;
    }

    final manifestUrl = input.userDefines[_manifestUrlUserDefine];
    if (manifestUrl is String && manifestUrl.trim().isNotEmpty) {
      return Uri.parse(manifestUrl.trim());
    }

    final releaseBaseUrl = input.userDefines[_releaseBaseUrlUserDefine];
    final packageVersion = _packageVersion(input.packageRoot);
    final base = releaseBaseUrl is String && releaseBaseUrl.trim().isNotEmpty
        ? releaseBaseUrl.trim()
        : '$_githubReleaseBaseUrl/v$packageVersion';
    return Uri.parse('$base/$_manifestFileName');
  }

  static String _packageVersion(Uri packageRoot) {
    final pubspecFile = File.fromUri(packageRoot.resolve('pubspec.yaml'));
    final pubspec = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
    return (pubspec['version'] as String?)?.trim() ??
        (throw StateError('pubspec.yaml is missing a version field.'));
  }

  static String? _targetSdk(BuildInput input) {
    if (input.config.code.targetOS == OS.iOS) {
      return input.config.code.iOS.targetSdk.toString();
    }
    return null;
  }

  static String _androidAbi(Architecture architecture) {
    return switch (architecture) {
      Architecture.arm64 => 'arm64-v8a',
      Architecture.arm => 'armeabi-v7a',
      Architecture.x64 => 'x86_64',
      _ => throw UnsupportedError(
          'No legacy Android ABI mapping for architecture $architecture.',
        ),
    };
  }

  static String _iosLibraryName(
    Architecture architecture,
    String? targetSdk,
  ) {
    final isSimulator = targetSdk == IOSSdk.iPhoneSimulator.toString();
    return switch ((architecture, isSimulator)) {
      (Architecture.arm64, false) => 'librust_net_native-ios-arm64.dylib',
      (Architecture.arm64, true) => 'librust_net_native-ios-sim-arm64.dylib',
      (Architecture.x64, true) => 'librust_net_native-ios-sim-x64.dylib',
      _ => throw UnsupportedError(
          'No legacy iOS artifact mapping for architecture=$architecture sdk=${targetSdk ?? '-'}',
        ),
    };
  }

  static Future<void> _copyUriToFile(Uri sourceUri, File destination) async {
    switch (sourceUri.scheme) {
      case 'file':
      case '':
        final source = File.fromUri(
          sourceUri.scheme.isEmpty ? sourceUri.replace(scheme: 'file') : sourceUri,
        );
        await source.copy(destination.path);
        return;
      case 'http':
      case 'https':
        final client = HttpClient();
        try {
          final request = await client.getUrl(sourceUri);
          final response = await request.close();
          if (response.statusCode != HttpStatus.ok) {
            throw HttpException(
              'Failed to download $sourceUri: ${response.statusCode}',
              uri: sourceUri,
            );
          }
          await response.pipe(destination.openWrite());
        } finally {
          client.close(force: true);
        }
        return;
      default:
        throw UnsupportedError(
          'Unsupported native asset URI scheme: ${sourceUri.scheme}',
        );
    }
  }

  static Future<String> _sha256Of(File file) async {
    final digest = sha256.convert(await file.readAsBytes());
    return digest.toString();
  }
}

final class _RustNetNativeAssetManifest {
  const _RustNetNativeAssetManifest({
    required this.baseUri,
    required this.packageVersion,
    required this.entries,
  });

  final Uri baseUri;
  final String packageVersion;
  final List<_RustNetNativeAssetManifestEntry> entries;

  static Future<_RustNetNativeAssetManifest> load(Uri uri) async {
    final raw = await _readUriAsString(uri);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw FormatException('Native asset manifest must be a JSON object.');
    }

    final entriesJson = json['assets'];
    if (entriesJson is! List) {
      throw FormatException('Native asset manifest is missing the "assets" list.');
    }

    return _RustNetNativeAssetManifest(
      baseUri: uri,
      packageVersion: (json['package_version'] as String?)?.trim() ?? '',
      entries: entriesJson
          .map((entry) => _RustNetNativeAssetManifestEntry.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ))
          .toList(growable: false),
    );
  }

  _RustNetNativeAssetManifestEntry select({
    required String packageVersion,
    required OS targetOS,
    required Architecture targetArchitecture,
    required String? targetSdk,
  }) {
    if (this.packageVersion.isNotEmpty && this.packageVersion != packageVersion) {
      throw StateError(
        'Native asset manifest version mismatch. Expected $packageVersion, got ${this.packageVersion}.',
      );
    }

    final matches = entries.where((entry) {
      if (entry.targetOS != targetOS.toString()) {
        return false;
      }
      if (entry.targetArchitecture != targetArchitecture.toString()) {
        return false;
      }
      if ((entry.targetSdk ?? '') != (targetSdk ?? '')) {
        return false;
      }
      return true;
    }).toList(growable: false);

    if (matches.isEmpty) {
      throw StateError(
        'No native asset entry matches os=$targetOS arch=$targetArchitecture sdk=${targetSdk ?? '-'}',
      );
    }
    if (matches.length > 1) {
      throw StateError(
        'Multiple native asset entries match os=$targetOS arch=$targetArchitecture sdk=${targetSdk ?? '-'}',
      );
    }
    return matches.single;
  }
}

final class _RustNetNativeAssetManifestEntry {
  const _RustNetNativeAssetManifestEntry({
    required this.targetOS,
    required this.targetArchitecture,
    required this.targetSdk,
    required this.fileName,
    required this.sourceUrl,
    required this.sha256,
  });

  final String targetOS;
  final String targetArchitecture;
  final String? targetSdk;
  final String fileName;
  final String sourceUrl;
  final String sha256;

  String get cacheKey => sha256.substring(0, 12);

  static _RustNetNativeAssetManifestEntry fromJson(Map<String, dynamic> json) {
    return _RustNetNativeAssetManifestEntry(
      targetOS: json['target_os'] as String,
      targetArchitecture: json['target_architecture'] as String,
      targetSdk: (json['target_sdk'] as String?)?.trim(),
      fileName: json['file_name'] as String,
      sourceUrl: (json['source_url'] ?? json['url']) as String,
      sha256: json['sha256'] as String,
    );
  }

  Uri resolveSourceUri(Uri manifestUri) {
    final uri = Uri.parse(sourceUrl);
    if (uri.hasScheme) {
      return uri;
    }
    return manifestUri.resolveUri(uri);
  }
}

Future<String> _readUriAsString(Uri uri) async {
  switch (uri.scheme) {
    case 'file':
    case '':
      return File.fromUri(
        uri.scheme.isEmpty ? uri.replace(scheme: 'file') : uri,
      ).readAsString();
    case 'http':
    case 'https':
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Failed to download $uri: ${response.statusCode}',
            uri: uri,
          );
        }
        return utf8.decode(await response.fold<List<int>>(
          <int>[],
          (buffer, chunk) => buffer..addAll(chunk),
        ));
      } finally {
        client.close(force: true);
      }
    default:
      throw UnsupportedError('Unsupported manifest URI scheme: ${uri.scheme}');
  }
}
