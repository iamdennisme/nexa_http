import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/verification/catalog.dart';
import '../../scripts/verification/checks/integration_checks.dart';
import '../../scripts/verification/executor.dart';
import '../../scripts/verification/model.dart';
import '../../scripts/verification/planner.dart';
import '../../scripts/verification/report.dart';
import '../../scripts/verification/target_matrix.dart';

void main() {
  test('integration suite registers build and consumer checks once', () {
    final catalog = VerificationCatalog(
      buildIntegrationChecks(
        workspaceRoot: '/workspace',
        executionRows: buildIntegrationExecutionRows(),
        runCommand: (_) async {},
        verifyAbi: (_) async {},
        verifyDevelopmentPath: (_) async {},
        verifyExternalConsumer: (_, _) async {},
        verifyArtifactUniqueness: (_) async =>
            const <VerificationRuntimePayloadProof>[],
      ),
    );

    expect(
      catalog
          .checksForSuite(VerificationSuiteId.verifyIntegration)
          .map((check) => check.id.value),
      <String>[
        'artifact-uniqueness',
        'development-path',
        'external-consumer',
        'native-abi',
        'native-build',
      ],
    );
  });

  test('Android execution invokes its platform build script once', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_android_build_command_',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final rows = buildIntegrationExecutionRows();
    final commands = <VerificationCommand>[];
    final check = nativeBuildCheck(workspace.path, rows, (command) async {
      commands.add(command);
      await _writeRequestedArtifacts(command, rows);
    }, resolveBashExecutable: () async => 'git-bash.exe');
    final catalog = VerificationCatalog(<VerificationCheckDefinition>[check]);
    final plan = VerificationPlanner(catalog).planSuite(
      VerificationSuiteId.verifyIntegration,
      const VerificationExecutionId('android-linux'),
    );

    await const VerificationExecutor().execute(plan);

    expect(commands, hasLength(1));
    expect(commands.single.executable, 'git-bash.exe');
    expect(commands.single.arguments, <String>[
      p.join(workspace.absolute.path, 'scripts', 'build_native_android.sh'),
      'debug',
      '--output-dir',
      p.join(
        workspace.absolute.path,
        '.dart_tool',
        'nexa_http_native',
        'integration',
        'android-linux',
      ),
      '--target',
      'aarch64-linux-android',
      '--target',
      'armv7-linux-androideabi',
      '--target',
      'x86_64-linux-android',
    ]);
  });

  test(
    'native build produces canonical prepared artifact identities',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'nexa_http_native_build_identity_',
      );
      addTearDown(() => workspace.delete(recursive: true));
      final rows = buildIntegrationExecutionRows();
      final commands = <VerificationCommand>[];
      final check = nativeBuildCheck(workspace.path, rows, (command) async {
        commands.add(command);
        await _writeRequestedArtifacts(
          command,
          rows,
          contentsByArchitecture: const <String, String>{
            'arm64': 'android-arm64',
            'arm': 'android-arm',
            'x64': 'android-x64',
          },
        );
      });
      final plan =
          VerificationPlanner(
            VerificationCatalog(<VerificationCheckDefinition>[check]),
          ).planSuite(
            VerificationSuiteId.verifyIntegration,
            const VerificationExecutionId('android-linux'),
          );

      final result = await const VerificationExecutor().execute(plan);

      expect(commands, hasLength(1));
      expect(
        result.preparedArtifactIdentities.map(
          (identity) => <Object?>[
            identity.target.targetOS,
            identity.target.targetArchitecture,
            identity.target.targetSdk,
            identity.target.rustTargetTriple,
            identity.nativeAssetId,
            identity.file.path,
            identity.sha256,
            identity.sourceIdentity,
          ],
        ),
        <List<Object?>>[
          <Object?>[
            'android',
            'arm64',
            null,
            'aarch64-linux-android',
            'package:nexa_http_native_android/src/native/'
                'nexa_http_native_ffi.dart',
            p.join(
              workspace.absolute.path,
              '.dart_tool',
              'nexa_http_native',
              'integration',
              'android-linux',
              'nexa_http-native-android-arm64-v8a.so',
            ),
            'b6894f8a1ae2bd52406a7fe0967edb27fd9dd76df504a3bde61e1deb7cb1a972',
            'workspace',
          ],
          <Object?>[
            'android',
            'arm',
            null,
            'armv7-linux-androideabi',
            'package:nexa_http_native_android/src/native/'
                'nexa_http_native_ffi.dart',
            p.join(
              workspace.absolute.path,
              '.dart_tool',
              'nexa_http_native',
              'integration',
              'android-linux',
              'nexa_http-native-android-armeabi-v7a.so',
            ),
            'bf76d1d268df3ae9dafcb3ffee7b9138e8ba4e66847408d4567a08f1e40a814f',
            'workspace',
          ],
          <Object?>[
            'android',
            'x64',
            null,
            'x86_64-linux-android',
            'package:nexa_http_native_android/src/native/'
                'nexa_http_native_ffi.dart',
            p.join(
              workspace.absolute.path,
              '.dart_tool',
              'nexa_http_native',
              'integration',
              'android-linux',
              'nexa_http-native-android-x86_64.so',
            ),
            '58d3e3bbc3d3101bb9cdf5134041d6f7365cd086c690d3c60db8cfd811aed67d',
            'workspace',
          ],
        ],
      );
    },
  );

  test('Apple ABI verification reuses one grouped platform build', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_native_abi_identity_',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final rows = buildIntegrationExecutionRows();
    final commands = <VerificationCommand>[];
    List<VerifiedNativeArtifactIdentity>? abiIdentities;
    final catalog = VerificationCatalog(<VerificationCheckDefinition>[
      nativeBuildCheck(
        workspace.path,
        rows,
        (command) async {
          commands.add(command);
          await _writeRequestedArtifacts(command, rows);
        },
        identityDigest: (file, {required platform}) => sha256OfFile(file),
      ),
      nativeAbiCheck(rows, (identities) async => abiIdentities = identities),
    ]);
    final plan = VerificationPlanner(catalog).planSuite(
      VerificationSuiteId.verifyIntegration,
      const VerificationExecutionId('apple-macos'),
    );

    final result = await const VerificationExecutor().execute(plan);

    expect(commands.map((command) => command.arguments.first), <String>[
      p.join(workspace.absolute.path, 'scripts', 'build_native_ios.sh'),
      p.join(workspace.absolute.path, 'scripts', 'build_native_macos.sh'),
    ]);
    expect(abiIdentities, hasLength(5));
    for (var index = 0; index < abiIdentities!.length; index++) {
      expect(
        identical(
          abiIdentities![index].file,
          result.preparedArtifactIdentities[index].file,
        ),
        isTrue,
      );
    }
  });

  test('development path runs after the Windows build producer', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'nexa_http_windows_build_command_',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final rows = buildIntegrationExecutionRows();
    final commands = <VerificationCommand>[];
    final developmentExecutions = <VerificationExecutionId>[];
    final catalog = VerificationCatalog(<VerificationCheckDefinition>[
      nativeBuildCheck(
        workspace.path,
        rows,
        (command) async {
          commands.add(command);
          await _writeRequestedArtifacts(command, rows);
        },
        identityDigest: (file, {required platform}) => sha256OfFile(file),
      ),
      developmentPathCheck(
        rows,
        (executionId) async => developmentExecutions.add(executionId),
      ),
    ]);
    final plan = VerificationPlanner(catalog).planSuite(
      VerificationSuiteId.verifyIntegration,
      const VerificationExecutionId('windows-x64'),
    );

    await const VerificationExecutor().execute(plan);

    expect(commands, hasLength(1));
    expect(
      commands.single.arguments.first,
      p.join(workspace.absolute.path, 'scripts', 'build_native_windows.sh'),
    );
    expect(developmentExecutions, <VerificationExecutionId>[
      const VerificationExecutionId('windows-x64'),
    ]);
  });
}

Future<void> _writeRequestedArtifacts(
  VerificationCommand command,
  List<IntegrationExecutionRow> rows, {
  Map<String, String> contentsByArchitecture = const <String, String>{},
}) async {
  final outputDirectory = Directory(
    command.arguments[command.arguments.indexOf('--output-dir') + 1],
  );
  await outputDirectory.create(recursive: true);
  final requestedTriples = <String>[
    for (var index = 0; index < command.arguments.length; index++)
      if (command.arguments[index] == '--target') command.arguments[index + 1],
  ];
  for (final target
      in rows
          .expand((row) => row.targets)
          .where(
            (target) => requestedTriples.contains(target.rustTargetTriple),
          )) {
    await File(
      p.join(outputDirectory.path, target.releaseAssetFileName),
    ).writeAsString(
      contentsByArchitecture[target.targetArchitecture] ??
          target.rustTargetTriple,
    );
  }
}
