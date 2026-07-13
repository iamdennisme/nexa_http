import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/native_abi_contract.dart';
import '../scripts/native_abi_verifier.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp(
      'nexa_http_native_abi_verifier_',
    );
    for (final relativePath in _androidArtifactPaths) {
      await File(p.join(workspace.path, relativePath)).create(recursive: true);
    }
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  test(
    'verifies every Android artifact with the public ABI contract',
    () async {
      final commands = <NexaHttpNativeSymbolCommand>[];

      await verifyNexaHttpNativeAbi(
        workspace.path,
        host: NexaHttpNativeAbiHost.android,
        runSymbolCommand: (command) async {
          commands.add(command);
          return NexaHttpNativeSymbolCommandResult(
            exitCode: 0,
            stdout: <String>[
              ...nexaHttpPublicNativeAbiSymbols,
              'nexa_http_test_binary_result_free',
            ].join('\n'),
            stderr: '',
          );
        },
      );

      expect(commands, hasLength(3));
      expect(
        commands.every((command) => command.arguments.last.endsWith('.so')),
        isTrue,
      );
    },
  );

  test('reports target, artifact, missing, and unexpected symbols', () async {
    expect(
      () => verifyNexaHttpNativeAbi(
        workspace.path,
        host: NexaHttpNativeAbiHost.android,
        sdkRef: 'candidate-42',
        runSymbolCommand: (command) async {
          return NexaHttpNativeSymbolCommandResult(
            exitCode: 0,
            stdout: <String>[
              ...nexaHttpPublicNativeAbiSymbols.skip(1),
              'nexa_http_platform_only',
            ].join('\n'),
            stderr: '',
          );
        },
      ),
      throwsA(
        isA<StateError>()
            .having(
              (error) => error.message,
              'message',
              contains('stage=native ABI verification'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('platform=android'),
            )
            .having((error) => error.message, 'message', contains('artifact='))
            .having(
              (error) => error.message,
              'message',
              contains('missing=nexa_http_client_create'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('unexpected=nexa_http_platform_only'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('sdk_version='),
            )
            .having(
              (error) => error.message,
              'message',
              contains('git_ref=candidate-42'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('expected_action='),
            )
            .having(
              (error) => error.message,
              'message',
              contains('underlying_error=public symbol set mismatch'),
            ),
      ),
    );
  });

  test('Windows verification falls back to LLVM COFF exports', () async {
    await File(
      p.join(
        workspace.path,
        '.dart_tool/nexa_http_native/workspace/debug/nexa_http-native-windows-x64.dll',
      ),
    ).create(recursive: true);
    final commands = <String>[];

    await verifyNexaHttpNativeAbi(
      workspace.path,
      host: NexaHttpNativeAbiHost.windows,
      runSymbolCommand: (command) async {
        commands.add(command.executable);
        if (command.executable == 'dumpbin') {
          return const NexaHttpNativeSymbolCommandResult(
            exitCode: -1,
            stdout: '',
            stderr: 'not found',
          );
        }
        return NexaHttpNativeSymbolCommandResult(
          exitCode: 0,
          stdout: nexaHttpPublicNativeAbiSymbols
              .map((symbol) => 'Name: $symbol')
              .join('\n'),
          stderr: '',
        );
      },
    );

    expect(commands, <String>['dumpbin', 'llvm-readobj']);
  });
}

const _androidArtifactPaths = <String>[
  '.dart_tool/nexa_http_native/workspace/debug/nexa_http-native-android-arm64-v8a.so',
  '.dart_tool/nexa_http_native/workspace/debug/nexa_http-native-android-armeabi-v7a.so',
  '.dart_tool/nexa_http_native/workspace/debug/nexa_http-native-android-x86_64.so',
];
