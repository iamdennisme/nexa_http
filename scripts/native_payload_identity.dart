import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

typedef NativePayloadIdentityCommandRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

Future<String> nexaHttpNativePayloadIdentitySha256(
  File file, {
  required String platform,
  NativePayloadIdentityCommandRunner runCommand = Process.run,
}) async {
  if (platform != 'ios' && platform != 'macos') {
    return sha256OfFile(file);
  }
  final result = await runCommand('dwarfdump', <String>['--uuid', file.path]);
  if (result.exitCode != 0) {
    throw StateError(
      'Unable to read Mach-O UUID identity for ${file.path}: ${result.stderr}',
    );
  }
  return machONativePayloadIdentitySha256('${result.stdout}');
}

String machONativePayloadIdentitySha256(String dwarfdumpOutput) {
  final identities = <String>[];
  final pattern = RegExp(
    r'^UUID:\s+([0-9A-Fa-f-]{36})\s+\(([^)]+)\)',
    multiLine: true,
  );
  for (final match in pattern.allMatches(dwarfdumpOutput)) {
    identities.add(
      '${match.group(2)!.toLowerCase()}:${match.group(1)!.toLowerCase()}',
    );
  }
  if (identities.isEmpty) {
    throw const FormatException('Mach-O UUID output contains no identities');
  }
  identities.sort();
  if (identities.toSet().length != identities.length) {
    throw const FormatException('Mach-O UUID output contains duplicates');
  }
  return sha256OfString(identities.join('\n'));
}
