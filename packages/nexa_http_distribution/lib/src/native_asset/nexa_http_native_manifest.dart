import 'dart:convert';

import 'nexa_http_native_file_transfer.dart';

final class NexaHttpNativeAssetManifest {
  const NexaHttpNativeAssetManifest({
    required this.baseUri,
    required this.packageVersion,
    required this.entries,
  });

  final Uri baseUri;
  final String packageVersion;
  final List<NexaHttpNativeAssetManifestEntry> entries;

  static Future<NexaHttpNativeAssetManifest> load(Uri uri) async {
    final raw = await readUriAsString(uri);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw FormatException('Native asset manifest must be a JSON object.');
    }

    final entriesJson = json['assets'];
    if (entriesJson is! List) {
      throw FormatException(
        'Native asset manifest is missing the "assets" list.',
      );
    }

    return NexaHttpNativeAssetManifest(
      baseUri: uri,
      packageVersion: (json['package_version'] as String?)?.trim() ?? '',
      entries: entriesJson
          .map((entry) => NexaHttpNativeAssetManifestEntry.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ))
          .toList(growable: false),
    );
  }

  NexaHttpNativeAssetManifestEntry select({
    required String packageVersion,
    required String targetOS,
    required String targetArchitecture,
    required String? targetSdk,
  }) {
    if (this.packageVersion.isNotEmpty &&
        this.packageVersion != packageVersion) {
      throw StateError(
        'Native asset manifest version mismatch. Expected $packageVersion, got ${this.packageVersion}.',
      );
    }

    final matches = entries.where((entry) {
      if (entry.targetOS != targetOS) {
        return false;
      }
      if (entry.targetArchitecture != targetArchitecture) {
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

final class NexaHttpNativeAssetManifestEntry {
  const NexaHttpNativeAssetManifestEntry({
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

  static NexaHttpNativeAssetManifestEntry fromJson(
    Map<String, dynamic> json,
  ) {
    return NexaHttpNativeAssetManifestEntry(
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
