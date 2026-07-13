import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

typedef NativePayloadIdentityCommandRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

Future<String> nexaHttpNativePayloadIdentitySha256(
  File file, {
  required String platform,
  NativePayloadIdentityCommandRunner runCommand = Process.run,
}) async {
  if (platform == 'windows') {
    return sha256OfFile(file);
  }
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

final class PeNativePayloadSectionDigest {
  const PeNativePayloadSectionDigest({
    required this.machine,
    required this.name,
    required this.virtualSize,
    required this.rawSize,
    required this.characteristics,
    required this.sha256,
  });

  final int machine;
  final String name;
  final int virtualSize;
  final int rawSize;
  final int characteristics;
  final String sha256;

  Map<String, Object> toJson() => <String, Object>{
    'machine': machine,
    'name': name,
    'virtual_size': virtualSize,
    'raw_size': rawSize,
    'characteristics': characteristics,
    'sha256': sha256,
  };
}

Future<List<PeNativePayloadSectionDigest>> peNativePayloadSectionDigests(
  File file,
) async {
  final sections = await _readPeSections(file);
  return <PeNativePayloadSectionDigest>[
    for (final section in sections)
      PeNativePayloadSectionDigest(
        machine: section.machine,
        name: section.name,
        virtualSize: section.virtualSize,
        rawSize: section.rawSize,
        characteristics: section.characteristics,
        sha256: section.rawSize == 0
            ? sha256OfString('')
            : (await sha256
                      .bind(
                        file.openRead(
                          section.rawOffset,
                          section.rawOffset + section.rawSize,
                        ),
                      )
                      .first)
                  .toString(),
      ),
  ];
}

Future<List<_PeSection>> _readPeSections(File file) async {
  final handle = await file.open();
  try {
    final dosHeader = await _readExact(handle, 0, 64, file);
    final peOffset = _uint32(dosHeader, 0x3c);
    final peHeader = await _readExact(handle, peOffset, 24, file);
    if (ascii.decode(peHeader.sublist(0, 4), allowInvalid: true) !=
        'PE\u0000\u0000') {
      throw FormatException('PE signature is missing: ${file.path}');
    }
    final machine = _uint16(peHeader, 4);
    final sectionCount = _uint16(peHeader, 6);
    final optionalHeaderSize = _uint16(peHeader, 20);
    if (sectionCount == 0) {
      throw FormatException('PE image contains no sections: ${file.path}');
    }
    final tableOffset = peOffset + 24 + optionalHeaderSize;
    final table = await _readExact(
      handle,
      tableOffset,
      sectionCount * 40,
      file,
    );
    return <_PeSection>[
      for (var index = 0; index < sectionCount; index++)
        _PeSection.fromHeader(machine, table, index * 40),
    ];
  } finally {
    await handle.close();
  }
}

Future<Uint8List> _readExact(
  RandomAccessFile handle,
  int offset,
  int length,
  File file,
) async {
  await handle.setPosition(offset);
  final bytes = await handle.read(length);
  if (bytes.length != length) {
    throw FormatException(
      'PE structure exceeds file bounds: ${file.path} '
      'offset=$offset length=$length actual=${bytes.length}',
    );
  }
  return bytes;
}

int _uint16(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint16(offset, Endian.little);

int _uint32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint32(offset, Endian.little);

final class _PeSection {
  const _PeSection({
    required this.machine,
    required this.name,
    required this.virtualSize,
    required this.rawSize,
    required this.rawOffset,
    required this.characteristics,
  });

  factory _PeSection.fromHeader(int machine, Uint8List table, int offset) {
    final nameBytes = table.sublist(offset, offset + 8);
    final zero = nameBytes.indexOf(0);
    return _PeSection(
      machine: machine,
      name: ascii.decode(
        zero == -1 ? nameBytes : nameBytes.sublist(0, zero),
        allowInvalid: false,
      ),
      virtualSize: _uint32(table, offset + 8),
      rawSize: _uint32(table, offset + 16),
      rawOffset: _uint32(table, offset + 20),
      characteristics: _uint32(table, offset + 36),
    );
  }

  final int machine;
  final String name;
  final int virtualSize;
  final int rawSize;
  final int rawOffset;
  final int characteristics;
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
