import 'dart:io';
import 'dart:typed_data';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

import '../scripts/native_payload_identity.dart';

void main() {
  test('Mach-O identity ignores file path and UUID output order', () {
    final first = machONativePayloadIdentitySha256('''
UUID: F90D5B1B-8F07-359B-A87B-D467518F31B4 (arm64) /prepared/library.dylib
UUID: A1F8EEBD-BFE6-37D7-A59B-C12D09A31D5D (x86_64) /prepared/library.dylib
''');
    final packaged = machONativePayloadIdentitySha256('''
UUID: A1F8EEBD-BFE6-37D7-A59B-C12D09A31D5D (x86_64) /App/Frameworks/native
UUID: F90D5B1B-8F07-359B-A87B-D467518F31B4 (arm64) /App/Frameworks/native
''');

    expect(packaged, first);
    expect(first, hasLength(64));
  });

  test('PE identity ignores mutable headers and appended signatures', () async {
    final directory = await Directory.systemTemp.createTemp(
      'nexa_http_pe_identity_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final prepared = File('${directory.path}/prepared.dll');
    final packaged = File('${directory.path}/packaged.dll');
    await prepared.writeAsBytes(
      _peFixture(timestamp: 1, checksum: 2, signature: const <int>[1, 2]),
    );
    await packaged.writeAsBytes(
      _peFixture(timestamp: 3, checksum: 4, signature: const <int>[9, 8, 7]),
    );

    expect(await sha256OfFile(packaged), isNot(await sha256OfFile(prepared)));
    expect(
      await peNativePayloadIdentitySha256(packaged),
      await peNativePayloadIdentitySha256(prepared),
    );
  });

  test('PE identity changes when section bytes change', () async {
    final directory = await Directory.systemTemp.createTemp(
      'nexa_http_pe_identity_section_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final first = File('${directory.path}/first.dll');
    final second = File('${directory.path}/second.dll');
    await first.writeAsBytes(_peFixture(section: const <int>[1, 2, 3, 4]));
    await second.writeAsBytes(_peFixture(section: const <int>[1, 2, 3, 5]));

    expect(
      await peNativePayloadIdentitySha256(second),
      isNot(await peNativePayloadIdentitySha256(first)),
    );
  });
}

Uint8List _peFixture({
  int timestamp = 0,
  int checksum = 0,
  List<int> section = const <int>[1, 2, 3, 4],
  List<int> signature = const <int>[],
}) {
  const peOffset = 0x80;
  const optionalHeaderSize = 0xf0;
  const sectionOffset = 0x200;
  final bytes = Uint8List(sectionOffset + section.length + signature.length);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0x3c, peOffset, Endian.little);
  bytes.setRange(peOffset, peOffset + 4, const <int>[0x50, 0x45, 0, 0]);
  data.setUint16(peOffset + 4, 0x8664, Endian.little);
  data.setUint16(peOffset + 6, 1, Endian.little);
  data.setUint32(peOffset + 8, timestamp, Endian.little);
  data.setUint16(peOffset + 20, optionalHeaderSize, Endian.little);
  data.setUint16(peOffset + 24, 0x20b, Endian.little);
  data.setUint32(peOffset + 24 + 64, checksum, Endian.little);
  final sectionHeader = peOffset + 24 + optionalHeaderSize;
  bytes.setRange(sectionHeader, sectionHeader + 8, const <int>[
    0x2e,
    0x74,
    0x65,
    0x78,
    0x74,
    0,
    0,
    0,
  ]);
  data.setUint32(sectionHeader + 8, section.length, Endian.little);
  data.setUint32(sectionHeader + 16, section.length, Endian.little);
  data.setUint32(sectionHeader + 20, sectionOffset, Endian.little);
  data.setUint32(sectionHeader + 36, 0x60000020, Endian.little);
  bytes.setRange(sectionOffset, sectionOffset + section.length, section);
  bytes.setRange(sectionOffset + section.length, bytes.length, signature);
  return bytes;
}
