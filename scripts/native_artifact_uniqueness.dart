import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;

import 'native_abi_contract.dart';
import 'native_abi_verifier.dart';
import 'native_payload_identity.dart';

typedef NativePayloadSymbolReader =
    Future<Set<String>> Function(File file, String platform);
typedef NativePayloadIdentityReader =
    Future<String> Function(File file, String platform);

final class VerifiedNativePayload {
  const VerifiedNativePayload({
    required this.file,
    required this.sha256,
    required this.identitySha256,
  });

  final File file;
  final String sha256;
  final String identitySha256;
}

Future<VerifiedNativePayload> verifyUniqueNexaHttpNativePayload({
  required Directory distribution,
  required String platform,
  NativePayloadSymbolReader readSymbols = _readSymbols,
  NativePayloadIdentityReader readIdentity = _readIdentity,
}) async {
  final payloads = <File>[];
  await for (final entity in distribution.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File || !_isNativeLibrary(entity.path, platform)) {
      continue;
    }
    final symbols = await readSymbols(entity, platform);
    final canonicalIntersection = symbols.intersection(
      nexaHttpPublicNativeAbiSymbols.toSet(),
    );
    if (canonicalIntersection.isEmpty) {
      continue;
    }
    final difference = compareNexaHttpPublicNativeAbiSymbols(symbols);
    if (!difference.matches) {
      throw StateError(
        'Native payload ABI mismatch: ${entity.path}; '
        'missing=${difference.missing}; unexpected=${difference.unexpected}',
      );
    }
    payloads.add(entity.absolute);
  }

  if (payloads.length != 1) {
    throw StateError(
      'Expected exactly one canonical nexa_http native payload for $platform '
      'in ${distribution.path}, found ${payloads.length}: '
      '${payloads.map((file) => file.path).join(', ')}',
    );
  }
  final file = payloads.single;
  return VerifiedNativePayload(
    file: file,
    sha256: await sha256OfFile(file),
    identitySha256: await readIdentity(file, platform),
  );
}

bool _isNativeLibrary(String path, String platform) {
  final extension = p.extension(path).toLowerCase();
  return switch (platform) {
    'android' => extension == '.so',
    'ios' || 'macos' => extension == '.dylib' || _isFrameworkExecutable(path),
    'windows' => extension == '.dll',
    _ => throw StateError('Unsupported payload platform: $platform'),
  };
}

bool _isFrameworkExecutable(String path) {
  final executableName = p.basename(path);
  var directory = Directory(p.dirname(path));
  while (directory.path != directory.parent.path) {
    if (p.extension(directory.path) == '.framework') {
      return executableName == p.basenameWithoutExtension(directory.path);
    }
    directory = directory.parent;
  }
  return false;
}

Future<Set<String>> _readSymbols(File file, String platform) {
  return readNexaHttpNativeSymbols(file, platform: platform);
}

Future<String> _readIdentity(File file, String platform) {
  return nexaHttpNativePayloadIdentitySha256(file, platform: platform);
}
