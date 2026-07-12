import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/native_abi_contract.dart';
import '../scripts/native_artifact_uniqueness.dart';

void main() {
  late Directory distribution;
  setUp(() async {
    distribution = await Directory.systemTemp.createTemp(
      'nexa_http_payload_scan_',
    );
  });
  tearDown(() => distribution.delete(recursive: true));

  test('rejects zero canonical payloads', () async {
    await File(p.join(distribution.path, 'unrelated.dylib')).writeAsString('x');
    await expectLater(
      verifyUniqueNexaHttpNativePayload(
        distribution: distribution,
        platform: 'macos',
        readSymbols: (_, _) async => const <String>{'unrelated'},
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('found 0'),
        ),
      ),
    );
  });

  test('returns one exact payload and streaming digest', () async {
    final payload = File(p.join(distribution.path, 'payload.dylib'));
    await payload.writeAsString('canonical');
    final result = await verifyUniqueNexaHttpNativePayload(
      distribution: distribution,
      platform: 'macos',
      readSymbols: (_, _) async => nexaHttpPublicNativeAbiSymbols.toSet(),
      readIdentity: (file, _) => sha256OfFile(file),
    );
    expect(result.file.path, payload.absolute.path);
    expect(result.sha256, hasLength(64));
  });

  test('recognizes a versioned macOS framework executable', () async {
    final payload = File(
      p.join(
        distribution.path,
        'nexa_http_native.framework',
        'Versions',
        'A',
        'nexa_http_native',
      ),
    );
    await payload.parent.create(recursive: true);
    await payload.writeAsString('canonical');

    final result = await verifyUniqueNexaHttpNativePayload(
      distribution: distribution,
      platform: 'macos',
      readSymbols: (_, _) async => nexaHttpPublicNativeAbiSymbols.toSet(),
      readIdentity: (file, _) => sha256OfFile(file),
    );

    expect(result.file.path, payload.absolute.path);
  });

  test('rejects two exact payloads', () async {
    await File(p.join(distribution.path, 'first.dylib')).writeAsString('one');
    await File(p.join(distribution.path, 'second.dylib')).writeAsString('two');
    await expectLater(
      verifyUniqueNexaHttpNativePayload(
        distribution: distribution,
        platform: 'macos',
        readSymbols: (_, _) async => nexaHttpPublicNativeAbiSymbols.toSet(),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('found 2'),
        ),
      ),
    );
  });
}
