import 'dart:io';

import 'package:test/test.dart';

import '../scripts/native_abi_contract.dart';

void main() {
  test('public native ABI symbols stay aligned across source contracts', () {
    final header = File(
      'native/nexa_http_native_core/include/nexa_http_native.h',
    ).readAsStringSync();

    expect(
      cHeaderNexaHttpFunctionNames(header),
      nexaHttpPublicNativeAbiSymbols.toSet(),
      reason: 'The canonical C header must declare the public ABI.',
    );
    for (final path in <String>[
      'packages/nexa_http_native_android/lib/src/native/nexa_http_native_ffi.dart',
      'packages/nexa_http_native_ios/lib/src/native/nexa_http_native_ffi.dart',
      'packages/nexa_http_native_macos/lib/src/native/nexa_http_native_ffi.dart',
      'packages/nexa_http_native_windows/lib/src/native/nexa_http_native_ffi.dart',
    ]) {
      final generated = File(path).readAsStringSync();
      for (final symbol in nexaHttpPublicNativeAbiSymbols) {
        expect(
          generated,
          contains('$symbol('),
          reason: '$path missing $symbol',
        );
      }
      expect(generated, contains('@ffi.DefaultAsset('), reason: path);
      expect(generated, isNot(contains('DynamicLibrary')), reason: path);
    }
  });

  test('platform crates use one shared native export definition', () {
    for (final path in <String>[
      'packages/nexa_http_native_android/native/nexa_http_native_android_ffi/src/lib.rs',
      'packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi/src/lib.rs',
      'packages/nexa_http_native_macos/native/nexa_http_native_macos_ffi/src/lib.rs',
      'packages/nexa_http_native_windows/native/nexa_http_native_windows_ffi/src/lib.rs',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        RegExp(
          r'nexa_http_native_core::export_nexa_http_ffi!\s*\{',
        ).allMatches(source),
        hasLength(1),
        reason: path,
      );
      expect(source, isNot(contains('#[unsafe(no_mangle)]')), reason: path);
    }
  });

  test('native symbol parser normalizes ELF, Mach-O, and PE output', () {
    const toolOutput = '''
0000000000010000 T nexa_http_client_create
0000000000010100 T _nexa_http_client_execute_async
          8    7 00011000 nexa_http_binary_result_free
0000000000010200 T _nexa_http_test_binary_result_free
Dump of file C:\temp\nexa_http_external_consumer_36eed48c\payload.dll
''';

    expect(nexaHttpSymbolsFromToolOutput(toolOutput), <String>{
      'nexa_http_client_create',
      'nexa_http_client_execute_async',
      'nexa_http_binary_result_free',
      'nexa_http_test_binary_result_free',
    });
    expect(
      nexaHttpSymbolsFromToolOutput(toolOutput),
      isNot(contains('nexa_http_external_consumer_36eed48c')),
    );
  });

  test('public ABI comparison excludes test helpers and reports drift', () {
    final matching = compareNexaHttpPublicNativeAbiSymbols(<String>{
      ...nexaHttpPublicNativeAbiSymbols,
      'nexa_http_test_binary_result_free',
    });

    expect(matching.missing, isEmpty);
    expect(matching.unexpected, isEmpty);

    final drifted = compareNexaHttpPublicNativeAbiSymbols(<String>{
      ...nexaHttpPublicNativeAbiSymbols.skip(1),
      'nexa_http_platform_only',
      'nexa_http_test_binary_result_free',
    });

    expect(drifted.missing, <String>{'nexa_http_client_create'});
    expect(drifted.unexpected, <String>{'nexa_http_platform_only'});
  });
}
