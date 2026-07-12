import 'dart:convert';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

import '../../scripts/verification/model.dart';
import '../../scripts/verification/target_matrix.dart';

void main() {
  test('canonical matrix fixes every native target identity field', () {
    expect(
      nexaHttpSupportedNativeTargets.map(
        (target) => <String>[
          target.targetOS,
          target.targetArchitecture,
          target.targetSdk ?? 'none',
          target.rustTargetTriple,
          target.sourceArtifactFileName,
          target.releaseAssetFileName,
          target.buildScriptName,
          target.integrationExecutionId,
          target.runner,
          target.nativeAssetId,
        ],
      ),
      const <List<String>>[
        <String>[
          'android',
          'arm64',
          'none',
          'aarch64-linux-android',
          'libnexa_http_native_android_ffi.so',
          'nexa_http-native-android-arm64-v8a.so',
          'build_native_android.sh',
          'android-linux',
          'ubuntu-latest',
          'package:nexa_http_native_android/src/native/'
              'nexa_http_native_ffi.dart',
        ],
        <String>[
          'android',
          'arm',
          'none',
          'armv7-linux-androideabi',
          'libnexa_http_native_android_ffi.so',
          'nexa_http-native-android-armeabi-v7a.so',
          'build_native_android.sh',
          'android-linux',
          'ubuntu-latest',
          'package:nexa_http_native_android/src/native/'
              'nexa_http_native_ffi.dart',
        ],
        <String>[
          'android',
          'x64',
          'none',
          'x86_64-linux-android',
          'libnexa_http_native_android_ffi.so',
          'nexa_http-native-android-x86_64.so',
          'build_native_android.sh',
          'android-linux',
          'ubuntu-latest',
          'package:nexa_http_native_android/src/native/'
              'nexa_http_native_ffi.dart',
        ],
        <String>[
          'ios',
          'arm64',
          'iphoneos',
          'aarch64-apple-ios',
          'libnexa_http_native_ios_ffi.dylib',
          'nexa_http-native-ios-arm64.dylib',
          'build_native_ios.sh',
          'apple-macos',
          'macos-14',
          'package:nexa_http_native_ios/src/native/nexa_http_native_ffi.dart',
        ],
        <String>[
          'ios',
          'arm64',
          'iphonesimulator',
          'aarch64-apple-ios-sim',
          'libnexa_http_native_ios_ffi.dylib',
          'nexa_http-native-ios-sim-arm64.dylib',
          'build_native_ios.sh',
          'apple-macos',
          'macos-14',
          'package:nexa_http_native_ios/src/native/nexa_http_native_ffi.dart',
        ],
        <String>[
          'ios',
          'x64',
          'iphonesimulator',
          'x86_64-apple-ios',
          'libnexa_http_native_ios_ffi.dylib',
          'nexa_http-native-ios-sim-x64.dylib',
          'build_native_ios.sh',
          'apple-macos',
          'macos-14',
          'package:nexa_http_native_ios/src/native/nexa_http_native_ffi.dart',
        ],
        <String>[
          'macos',
          'arm64',
          'none',
          'aarch64-apple-darwin',
          'libnexa_http_native_macos_ffi.dylib',
          'nexa_http-native-macos-arm64.dylib',
          'build_native_macos.sh',
          'apple-macos',
          'macos-14',
          'package:nexa_http_native_macos/src/native/nexa_http_native_ffi.dart',
        ],
        <String>[
          'macos',
          'x64',
          'none',
          'x86_64-apple-darwin',
          'libnexa_http_native_macos_ffi.dylib',
          'nexa_http-native-macos-x64.dylib',
          'build_native_macos.sh',
          'apple-macos',
          'macos-14',
          'package:nexa_http_native_macos/src/native/nexa_http_native_ffi.dart',
        ],
        <String>[
          'windows',
          'x64',
          'none',
          'x86_64-pc-windows-msvc',
          'nexa_http_native_windows_ffi.dll',
          'nexa_http-native-windows-x64.dll',
          'build_native_windows.sh',
          'windows-x64',
          'windows-latest',
          'package:nexa_http_native_windows/src/native/'
              'nexa_http_native_ffi.dart',
        ],
      ],
    );
  });

  test('different target tuples have different materialization paths', () {
    final paths = nexaHttpSupportedNativeTargets
        .map((target) => target.materializationRelativePath('debug'))
        .toList(growable: false);

    expect(paths, hasLength(paths.toSet().length));
    expect(paths, everyElement(startsWith('debug/')));
  });

  test('integration execution groups cover every canonical target once', () {
    final rows = buildIntegrationExecutionRows();

    expect(
      rows.map(
        (row) => <Object>[
          row.executionId.value,
          row.runner.value,
          row.targets.length,
        ],
      ),
      <List<Object>>[
        <Object>['android-linux', 'ubuntu-latest', 3],
        <Object>['apple-macos', 'macos-14', 5],
        <Object>['windows-x64', 'windows-latest', 1],
      ],
    );

    final coveredTargets = rows
        .expand((row) => row.targets)
        .map(_targetKey)
        .toList();
    final canonicalTargets = nexaHttpSupportedNativeTargets
        .map(_targetKey)
        .toList();

    expect(coveredTargets.toSet(), canonicalTargets.toSet());
    expect(coveredTargets, hasLength(coveredTargets.toSet().length));
  });

  test('rejects a target assigned to more than one execution group', () {
    final rows = buildIntegrationExecutionRows();
    final duplicatedTarget = rows.first.targets.first;

    expect(
      () => validateIntegrationExecutionRows(<IntegrationExecutionRow>[
        ...rows,
        IntegrationExecutionRow(
          executionId: const VerificationExecutionId('duplicate-row'),
          runner: const VerificationRunner('ubuntu-latest'),
          targets: <NexaHttpNativeTarget>[duplicatedTarget],
        ),
      ]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Native target is covered more than once'),
        ),
      ),
    );
  });

  test('rejects a canonical target with no execution group', () {
    final rows = buildIntegrationExecutionRows();

    expect(
      () => validateIntegrationExecutionRows(<IntegrationExecutionRow>[
        rows[0],
        rows[1],
        IntegrationExecutionRow(
          executionId: rows[2].executionId,
          runner: rows[2].runner,
          targets: const <NexaHttpNativeTarget>[],
        ),
      ]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Native targets have no execution coverage'),
        ),
      ),
    );
  });

  test('projects the integration matrix as stable Actions JSON', () {
    final decoded =
        jsonDecode(
              buildActionsMatrixJson(VerificationSuiteId.verifyIntegration),
            )
            as Map<String, Object?>;
    final rows = decoded['include']! as List<Object?>;

    expect(
      rows.map((row) {
        final values = row! as Map<String, Object?>;
        return <Object?>[
          values['suite'],
          values['execution_id'],
          values['runner'],
          (values['logical_targets']! as List<Object?>).length,
        ];
      }),
      <List<Object?>>[
        <Object?>['verify-integration', 'android-linux', 'ubuntu-latest', 3],
        <Object?>['verify-integration', 'apple-macos', 'macos-14', 5],
        <Object?>['verify-integration', 'windows-x64', 'windows-latest', 1],
      ],
    );
  });

  test('projects host-independent static checks to one runner', () {
    final decoded =
        jsonDecode(buildActionsMatrixJson(VerificationSuiteId.verifyStatic))
            as Map<String, Object?>;

    expect(decoded, <String, Object?>{
      'include': <Map<String, Object?>>[
        <String, Object?>{
          'suite': 'verify-static',
          'execution_id': 'static-linux',
          'runner': 'ubuntu-latest',
          'logical_targets': <Object?>[],
        },
      ],
    });
  });

  test('projects four blocking release-candidate platform rows', () {
    final decoded =
        jsonDecode(
              buildActionsMatrixJson(
                VerificationSuiteId.verifyReleaseCandidate,
              ),
            )
            as Map<String, Object?>;
    final rows = decoded['include']! as List<Object?>;

    expect(
      rows.map((row) {
        final values = row! as Map<String, Object?>;
        return <Object?>[
          values['execution_id'],
          values['runner'],
          (values['logical_targets']! as List<Object?>).length,
        ];
      }),
      <List<Object?>>[
        <Object?>['candidate-android', 'ubuntu-latest', 3],
        <Object?>['candidate-ios', 'macos-14', 3],
        <Object?>['candidate-macos', 'macos-14', 2],
        <Object?>['candidate-windows', 'windows-latest', 1],
      ],
    );
  });
}

String _targetKey(NexaHttpNativeTarget target) {
  return <String>[
    target.targetOS,
    target.targetArchitecture,
    target.targetSdk ?? '',
  ].join(':');
}
