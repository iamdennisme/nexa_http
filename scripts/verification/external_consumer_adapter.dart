import 'dart:convert';
import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:path/path.dart' as p;

import '../native_artifact_uniqueness.dart';
import '../native_payload_identity.dart';
import 'command.dart';
import 'model.dart';
import 'report.dart';

typedef ExternalConsumerSourcePreparer =
    Future<Directory> Function(VerificationExecutionId executionId);

typedef ExternalRuntimeSmokeRunner =
    Future<void> Function({
      required Directory fixtureDirectory,
      required ExternalConsumerPlatform platform,
      required Uri fixtureUrl,
      required Map<String, String> environment,
    });

typedef ExternalDeviceIdResolver = String Function(String targetOS);

typedef ExternalAndroidLogcatPollWait = Future<void> Function(Duration delay);

Future<void> _waitForAndroidLogcatPoll(Duration delay) =>
    Future<void>.delayed(delay);

const _androidRuntimeProofPollLimit = 60;
const _androidRuntimeProofPollInterval = Duration(seconds: 1);
const _externalConsumerAndroidApplicationId =
    'com.example.nexa_http_external_consumer_fixture';

final class ExternalRuntimeProofMarkerTracker {
  static const marker = 'NEXA_HTTP_RUNTIME_PROOF ';

  final List<Map<String, Object?>> _proofs = <Map<String, Object?>>[];

  int get proofCount => _proofs.length;

  void observeLine(String line) {
    final markerIndex = line.indexOf(marker);
    if (markerIndex < 0) {
      return;
    }
    final value = jsonDecode(line.substring(markerIndex + marker.length));
    if (value is! Map) {
      throw const FormatException('Invalid runtime proof marker');
    }
    final proof = value.cast<String, Object?>();
    for (final field in const <String>[
      'request_completed',
      'callback_received',
      'body_consumed',
      'body_released',
      'client_closed',
    ]) {
      if (proof[field] != true) {
        throw FormatException('Incomplete runtime proof marker: $field');
      }
    }
    _proofs.add(proof);
  }

  void requireSingleProofSince(int previousCount, {required String targetOS}) {
    final produced = _proofs.length - previousCount;
    if (produced != 1) {
      throw StateError(
        'Expected exactly one runtime proof marker for $targetOS, '
        'found $produced',
      );
    }
  }
}

ExternalRuntimeSmokeRunner createFlutterRuntimeSmokeRunner(
  VerificationCommandRunner runCommand, {
  required ExternalDeviceIdResolver deviceIdForTargetOS,
  required ExternalRuntimeProofMarkerTracker proofTracker,
  Map<String, String> baseEnvironment = const <String, String>{},
  ExternalAndroidLogcatPollWait waitForAndroidLogcatPoll =
      _waitForAndroidLogcatPoll,
}) {
  return ({
    required fixtureDirectory,
    required platform,
    required fixtureUrl,
    required environment,
  }) async {
    final deviceId = deviceIdForTargetOS(platform.targetOS).trim();
    if (deviceId.isEmpty) {
      throw StateError(
        'A Flutter device ID is required for ${platform.targetOS}',
      );
    }
    final previousProofCount = proofTracker.proofCount;
    Object? flutterError;
    StackTrace? flutterStackTrace;
    try {
      if (platform.targetOS == 'android') {
        final commandEnvironment = <String, String>{
          ...baseEnvironment,
          ...environment,
        };
        await runCommand(
          VerificationCommand(
            executable: 'adb',
            arguments: <String>[
              '-s',
              deviceId,
              'install',
              '-t',
              '-r',
              _androidRuntimeApk(fixtureDirectory).path,
            ],
            workingDirectory: fixtureDirectory.path,
            environment: commandEnvironment,
          ),
        );
        await runCommand(
          VerificationCommand(
            executable: 'adb',
            arguments: <String>['-s', deviceId, 'logcat', '-c'],
            workingDirectory: fixtureDirectory.path,
            environment: commandEnvironment,
          ),
        );
        await runCommand(
          VerificationCommand(
            executable: 'adb',
            arguments: <String>[
              '-s',
              deviceId,
              'shell',
              'am',
              'start',
              '-W',
              '-n',
              '$_externalConsumerAndroidApplicationId/.MainActivity',
            ],
            workingDirectory: fixtureDirectory.path,
            environment: commandEnvironment,
          ),
        );
      } else {
        try {
          await runCommand(
            VerificationCommand(
              executable: 'flutter',
              arguments: <String>[
                'run',
                '-d',
                deviceId,
                '--debug',
                '--dart-define=NEXA_HTTP_FIXTURE_URL=$fixtureUrl',
              ],
              workingDirectory: fixtureDirectory.path,
              environment: <String, String>{...baseEnvironment, ...environment},
            ),
          );
        } on ProcessException catch (error, stackTrace) {
          flutterError = error;
          flutterStackTrace = stackTrace;
        }
      }
      if (platform.targetOS == 'android' &&
          proofTracker.proofCount == previousProofCount) {
        for (var poll = 0; poll < _androidRuntimeProofPollLimit; poll += 1) {
          await runCommand(
            VerificationCommand(
              executable: 'adb',
              arguments: <String>[
                '-s',
                deviceId,
                'logcat',
                '-d',
                '-v',
                'raw',
                '-s',
                'flutter:I',
              ],
              workingDirectory: fixtureDirectory.path,
              environment: <String, String>{...baseEnvironment, ...environment},
            ),
          );
          if (proofTracker.proofCount != previousProofCount) {
            break;
          }
          if (poll + 1 < _androidRuntimeProofPollLimit) {
            await waitForAndroidLogcatPoll(_androidRuntimeProofPollInterval);
          }
        }
      }
      if (proofTracker.proofCount == previousProofCount + 1) {
        proofTracker.requireSingleProofSince(
          previousProofCount,
          targetOS: platform.targetOS,
        );
        return;
      }
      if (flutterError != null) {
        Error.throwWithStackTrace(flutterError, flutterStackTrace!);
      }
      proofTracker.requireSingleProofSince(
        previousProofCount,
        targetOS: platform.targetOS,
      );
    } finally {
      if (platform.targetOS == 'android') {
        try {
          await runCommand(
            VerificationCommand(
              executable: 'adb',
              arguments: <String>[
                '-s',
                deviceId,
                'shell',
                'am',
                'force-stop',
                _externalConsumerAndroidApplicationId,
              ],
              workingDirectory: fixtureDirectory.path,
              environment: <String, String>{...baseEnvironment, ...environment},
            ),
          );
        } on ProcessException {
          // Cleanup is best-effort and cannot replace or mask runtime proof.
        }
      }
    }
  };
}

typedef ExternalConsumerRunner =
    Future<void> Function(VerificationExecutionId executionId);

typedef ExternalRuntimePayloadProofRunner =
    Future<List<VerificationRuntimePayloadProof>> Function(
      VerificationExecutionId executionId,
    );

typedef ExternalNativePayloadVerifier =
    Future<VerifiedNativePayload> Function({
      required Directory distribution,
      required String platform,
    });

final class ExternalConsumerVerificationSession {
  const ExternalConsumerVerificationSession._({
    required this.runner,
    required this.verifyArtifactUniqueness,
    required this.tempRoot,
  });

  final ExternalConsumerRunner runner;
  final ExternalRuntimePayloadProofRunner verifyArtifactUniqueness;
  final Directory tempRoot;

  Future<void> close() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  }
}

Future<ExternalConsumerVerificationSession> createExternalConsumerSession({
  required String workspaceRoot,
  required Uri fixtureUrl,
  required Map<String, String> deviceIds,
  required VerificationCommandRunner runCommand,
  required ExternalRuntimeProofMarkerTracker runtimeProofTracker,
  Map<String, String> commandEnvironment = const <String, String>{},
  String? candidateDirectory,
  String? candidateRef,
  List<VerificationPreparedArtifactProof> preparedArtifactProofs =
      const <VerificationPreparedArtifactProof>[],
  ExternalNativePayloadVerifier verifyUniquePayload = _verifyUniquePayload,
}) async {
  final tempRoot = await Directory.systemTemp.createTemp(
    'nexa_http_external_consumer_',
  );
  final runtimeSmoke = createFlutterRuntimeSmokeRunner(
    runCommand,
    deviceIdForTargetOS: (targetOS) => deviceIds[targetOS] ?? '',
    proofTracker: runtimeProofTracker,
    baseEnvironment: commandEnvironment,
  );
  final fixturesByPlatform = <String, Directory>{};
  final preparedProofs = List<VerificationPreparedArtifactProof>.unmodifiable(
    preparedArtifactProofs,
  );
  return ExternalConsumerVerificationSession._(
    tempRoot: tempRoot,
    runner: createExternalConsumerRunner(
      fixtureRoot: Directory(p.join(tempRoot.path, 'fixtures')),
      fixtureUrl: fixtureUrl,
      prepareSource: (_) async => Directory(workspaceRoot).absolute,
      candidateDirectory: candidateDirectory,
      candidateRef: candidateRef,
      runCommand: runCommand,
      runRuntimeSmoke: runtimeSmoke,
      onPlatformComplete: (fixtureDirectory, platform) {
        fixturesByPlatform[platform.targetOS] = fixtureDirectory;
      },
      commandEnvironment: commandEnvironment,
    ),
    verifyArtifactUniqueness: (executionId) async {
      final runtimeProofs = <VerificationRuntimePayloadProof>[];
      for (final platform in externalConsumerPlatformsForExecution(
        executionId,
      )) {
        final fixture = fixturesByPlatform[platform.targetOS];
        if (fixture == null) {
          throw StateError(
            'No completed clean-host build for ${platform.targetOS}',
          );
        }
        final distribution = await _finalDistributionDirectory(
          fixture,
          platform.targetOS,
        );
        final packagedPayload = await verifyUniquePayload(
          distribution: distribution,
          platform: platform.targetOS,
        );
        final matches = preparedProofs
            .where(
              (proof) =>
                  proof.target.targetOS == platform.targetOS &&
                  proof.identitySha256 == packagedPayload.identitySha256,
            )
            .toList(growable: false);
        if (matches.length != 1) {
          final diagnostics = await describeNativePayloadProofMismatch(
            platform: platform.targetOS,
            packagedPayload: packagedPayload,
            preparedProofs: preparedProofs
                .where((proof) => proof.target.targetOS == platform.targetOS)
                .toList(growable: false),
          );
          throw StateError(
            'Packaged Native Asset proof mismatch for '
            '${platform.targetOS}: digest=${packagedPayload.sha256}; '
            'identity_digest=${packagedPayload.identitySha256}; '
            'matching_prepared_proofs=${matches.length}; $diagnostics',
          );
        }
        final prepared = matches.single;
        runtimeProofs.add(
          VerificationRuntimePayloadProof(
            target: prepared.target,
            nativeAssetId: prepared.nativeAssetId,
            absolutePackagedFile: packagedPayload.file.absolute.path,
            sha256: packagedPayload.sha256,
            identitySha256: packagedPayload.identitySha256,
            payloadCount: 1,
            requestCompleted: true,
            callbackReceived: true,
            bodyConsumed: true,
            bodyReleased: true,
            clientClosed: true,
          ),
        );
      }
      return List<VerificationRuntimePayloadProof>.unmodifiable(runtimeProofs);
    },
  );
}

Future<String> describeNativePayloadProofMismatch({
  required String platform,
  required VerifiedNativePayload packagedPayload,
  required List<VerificationPreparedArtifactProof> preparedProofs,
}) async {
  final preparedDiagnostics = <Map<String, Object?>>[
    for (final proof in preparedProofs)
      <String, Object?>{
        'target': proof.target.toJson(),
        'path': proof.absolutePreparedFile,
        'sha256': proof.sha256,
        'identity_sha256': proof.identitySha256,
      },
  ];
  final diagnostics = <String, Object?>{
    'packaged_path': packagedPayload.file.absolute.path,
    'prepared_proofs': preparedDiagnostics,
  };
  if (platform == 'windows') {
    diagnostics['packaged_pe_sections'] = await _peSectionDiagnostics(
      packagedPayload.file,
    );
    for (var index = 0; index < preparedProofs.length; index++) {
      preparedDiagnostics[index]['pe_sections'] = await _peSectionDiagnostics(
        File(preparedProofs[index].absolutePreparedFile),
      );
    }
  }
  return 'proof_diagnostics=${jsonEncode(diagnostics)}';
}

Future<Object> _peSectionDiagnostics(File file) async {
  try {
    return <Map<String, Object>>[
      for (final section in await peNativePayloadSectionDigests(file))
        section.toJson(),
    ];
  } on Object catch (error) {
    return <String, Object>{'error': '$error'};
  }
}

Future<VerifiedNativePayload> _verifyUniquePayload({
  required Directory distribution,
  required String platform,
}) {
  return verifyUniqueNexaHttpNativePayload(
    distribution: distribution,
    platform: platform,
  );
}

typedef ExternalPlatformComplete =
    void Function(
      Directory fixtureDirectory,
      ExternalConsumerPlatform platform,
    );

ExternalConsumerRunner createExternalConsumerRunner({
  required Directory fixtureRoot,
  required Uri fixtureUrl,
  required ExternalConsumerSourcePreparer prepareSource,
  required VerificationCommandRunner runCommand,
  required ExternalRuntimeSmokeRunner runRuntimeSmoke,
  ExternalPlatformComplete? onPlatformComplete,
  Map<String, String> commandEnvironment = const <String, String>{},
  Map<String, String> Function(VerificationExecutionId executionId)?
  environmentForExecution,
  String? candidateDirectory,
  String? candidateRef,
}) {
  return (executionId) async {
    final executionEnvironment = <String, String>{
      ...commandEnvironment,
      ...?environmentForExecution?.call(executionId),
    };
    final sourceRoot = await prepareSource(executionId);
    for (final platform in externalConsumerPlatformsForExecution(executionId)) {
      final fixtureDirectory = Directory(
        p.join(fixtureRoot.path, platform.targetOS),
      );
      if (fixtureDirectory.existsSync()) {
        await fixtureDirectory.delete(recursive: true);
      }
      await fixtureDirectory.create(recursive: true);
      await runCommand(
        VerificationCommand(
          executable: 'flutter',
          arguments: platform.createArguments,
          workingDirectory: fixtureDirectory.path,
          environment: executionEnvironment,
        ),
      );
      await configureExternalConsumerFixture(
        fixtureDirectory,
        targetOS: platform.targetOS,
      );
      await File(p.join(fixtureDirectory.path, 'pubspec.yaml')).writeAsString(
        buildPathConsumerPubspec(
          sourceRoot.path,
          targetOS: platform.targetOS,
          candidateDirectory: candidateDirectory,
          candidateRef: candidateRef,
        ),
      );
      final libDirectory = Directory(p.join(fixtureDirectory.path, 'lib'));
      await libDirectory.create(recursive: true);
      await File(
        p.join(libDirectory.path, 'main.dart'),
      ).writeAsString(buildExternalConsumerRuntimeMain());
      await runCommand(
        VerificationCommand(
          executable: 'flutter',
          arguments: const <String>['pub', 'get'],
          workingDirectory: fixtureDirectory.path,
          environment: executionEnvironment,
        ),
      );
      await runCommand(
        VerificationCommand(
          executable: 'flutter',
          arguments: externalConsumerBuildArguments(
            platform: platform,
            fixtureUrl: fixtureUrl,
          ),
          workingDirectory: fixtureDirectory.path,
          environment: executionEnvironment,
        ),
      );
      await runRuntimeSmoke(
        fixtureDirectory: fixtureDirectory,
        platform: platform,
        fixtureUrl: fixtureUrl,
        environment: executionEnvironment,
      );
      onPlatformComplete?.call(fixtureDirectory, platform);
    }
  };
}

Future<Directory> _finalDistributionDirectory(
  Directory fixture,
  String targetOS,
) async {
  if (targetOS == 'android') {
    final apk = _androidRuntimeApk(fixture);
    final extracted = Directory(p.join(fixture.path, '.nexa_http_apk_payload'));
    if (extracted.existsSync()) {
      await extracted.delete(recursive: true);
    }
    await extracted.create(recursive: true);
    final result = await Process.run('unzip', <String>[
      '-qq',
      apk.path,
      'lib/*',
      '-d',
      extracted.path,
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to extract Android APK payload: ${result.stderr}',
      );
    }
    final runtimeAbiDirectory = Directory(
      p.join(extracted.path, 'lib', 'x86_64'),
    );
    if (!runtimeAbiDirectory.existsSync()) {
      throw StateError(
        'Android x86_64 runtime payload does not exist: '
        '${runtimeAbiDirectory.path}',
      );
    }
    return runtimeAbiDirectory;
  }
  final root = switch (targetOS) {
    'ios' => Directory(p.join(fixture.path, 'build', 'ios', 'iphonesimulator')),
    'macos' => Directory(
      p.join(fixture.path, 'build', 'macos', 'Build', 'Products', 'Debug'),
    ),
    'windows' => Directory(
      p.join(fixture.path, 'build', 'windows', 'x64', 'runner', 'Debug'),
    ),
    _ => throw StateError('No final distribution for $targetOS'),
  };
  if (!root.existsSync()) {
    throw StateError(
      'Final $targetOS distribution does not exist: ${root.path}',
    );
  }
  if (targetOS == 'ios' || targetOS == 'macos') {
    return resolveSingleAppleAppBundle(root, targetOS: targetOS);
  }
  return root;
}

File _androidRuntimeApk(Directory fixtureDirectory) => File(
  p.join(
    fixtureDirectory.path,
    'build',
    'app',
    'outputs',
    'flutter-apk',
    'app-release.apk',
  ),
);

Directory resolveSingleAppleAppBundle(
  Directory productsRoot, {
  required String targetOS,
}) {
  final appBundles = productsRoot
      .listSync(followLinks: false)
      .whereType<Directory>()
      .where((directory) => p.extension(directory.path) == '.app')
      .toList(growable: false);
  if (appBundles.length != 1) {
    throw StateError(
      'Expected exactly one final $targetOS app bundle in '
      '${productsRoot.path}, found ${appBundles.length}: '
      '${appBundles.map((directory) => directory.path).join(', ')}',
    );
  }
  return appBundles.single.absolute;
}

final class ExternalConsumerPlatform {
  const ExternalConsumerPlatform({
    required this.targetOS,
    required this.buildArguments,
  });

  final String targetOS;
  final List<String> buildArguments;

  List<String> get createArguments => <String>[
    'create',
    '--platforms=$targetOS',
    '--project-name=nexa_http_external_consumer_fixture',
    '.',
  ];
}

List<ExternalConsumerPlatform> externalConsumerPlatformsForExecution(
  VerificationExecutionId executionId,
) {
  return switch (executionId.value) {
    'android-linux' || 'candidate-android' => const <ExternalConsumerPlatform>[
      ExternalConsumerPlatform(
        targetOS: 'android',
        buildArguments: <String>[
          'build',
          'apk',
          '--release',
          '--target-platform=android-x64',
        ],
      ),
    ],
    'apple-macos' => const <ExternalConsumerPlatform>[
      ExternalConsumerPlatform(
        targetOS: 'ios',
        buildArguments: <String>[
          'build',
          'ios',
          '--simulator',
          '--debug',
          '--no-codesign',
        ],
      ),
      ExternalConsumerPlatform(
        targetOS: 'macos',
        buildArguments: <String>['build', 'macos', '--debug'],
      ),
    ],
    'windows-x64' => const <ExternalConsumerPlatform>[
      ExternalConsumerPlatform(
        targetOS: 'windows',
        buildArguments: <String>['build', 'windows', '--debug'],
      ),
    ],
    'candidate-ios' => const <ExternalConsumerPlatform>[
      ExternalConsumerPlatform(
        targetOS: 'ios',
        buildArguments: <String>[
          'build',
          'ios',
          '--simulator',
          '--debug',
          '--no-codesign',
        ],
      ),
    ],
    'candidate-macos' => const <ExternalConsumerPlatform>[
      ExternalConsumerPlatform(
        targetOS: 'macos',
        buildArguments: <String>['build', 'macos', '--debug'],
      ),
    ],
    'candidate-windows' => const <ExternalConsumerPlatform>[
      ExternalConsumerPlatform(
        targetOS: 'windows',
        buildArguments: <String>['build', 'windows', '--debug'],
      ),
    ],
    _ => throw StateError(
      'No external consumer platform projection for execution $executionId',
    ),
  };
}

List<String> externalConsumerBuildArguments({
  required ExternalConsumerPlatform platform,
  required Uri fixtureUrl,
}) => <String>[
  ...platform.buildArguments,
  if (platform.targetOS == 'android')
    '--dart-define=NEXA_HTTP_FIXTURE_URL=$fixtureUrl',
];

String buildPathConsumerPubspec(
  String sourceRoot, {
  required String targetOS,
  String? candidateDirectory,
  String? candidateRef,
}) {
  final carrier = switch (targetOS) {
    'android' => 'nexa_http_native_android',
    'ios' => 'nexa_http_native_ios',
    'macos' => 'nexa_http_native_macos',
    'windows' => 'nexa_http_native_windows',
    _ => throw StateError('No carrier package for target OS $targetOS'),
  };
  final resolvedCandidateDirectory = candidateDirectory?.trim() ?? '';
  final resolvedCandidateRef = candidateRef?.trim() ?? '';
  if (resolvedCandidateDirectory.isEmpty != resolvedCandidateRef.isEmpty) {
    throw StateError('Candidate directory and ref must be provided together.');
  }
  final hookDefines = resolvedCandidateDirectory.isEmpty
      ? ''
      : '''

hooks:
  user_defines:
    $carrier:
      $nexaHttpNativeCandidateDirectoryDefine: ${jsonEncode(_candidateDirectoryUserDefine(resolvedCandidateDirectory))}
      $nexaHttpNativeCandidateRefDefine: ${jsonEncode(resolvedCandidateRef)}
''';
  return '''
name: nexa_http_external_consumer_fixture
publish_to: none

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  nexa_http:
    path: ${p.join(sourceRoot, 'packages', 'nexa_http')}
  $carrier:
    path: ${p.join(sourceRoot, 'packages', carrier)}
$hookDefines
''';
}

String _candidateDirectoryUserDefine(String candidateDirectory) {
  final windowsPaths = p.Context(style: p.Style.windows);
  if (windowsPaths.isAbsolute(candidateDirectory)) {
    return windowsPaths.toUri(candidateDirectory).toString();
  }
  return Directory(candidateDirectory).absolute.uri.toString();
}

Future<void> enableMacosNetworkClientEntitlement(
  Directory fixtureDirectory,
) async {
  const entitlementKey = 'com.apple.security.network.client';
  for (final name in <String>[
    'DebugProfile.entitlements',
    'Release.entitlements',
  ]) {
    final file = File(p.join(fixtureDirectory.path, 'macos', 'Runner', name));
    if (!file.existsSync()) {
      throw StateError('macOS entitlement file does not exist: ${file.path}');
    }
    final contents = await file.readAsString();
    if (contents.contains('<key>$entitlementKey</key>')) {
      continue;
    }
    const closingDictionary = '</dict>';
    final insertionIndex = contents.lastIndexOf(closingDictionary);
    if (insertionIndex < 0) {
      throw StateError('Invalid macOS entitlement plist: ${file.path}');
    }
    await file.writeAsString(
      contents.replaceRange(
        insertionIndex,
        insertionIndex,
        '\t<key>$entitlementKey</key>\n\t<true/>\n',
      ),
    );
  }
}

Future<void> configureExternalConsumerFixture(
  Directory fixtureDirectory, {
  required String targetOS,
}) async {
  switch (targetOS) {
    case 'android':
      await enableAndroidReleaseInternetPermission(fixtureDirectory);
    case 'macos':
      await enableMacosNetworkClientEntitlement(fixtureDirectory);
    case 'ios':
    case 'windows':
      return;
    default:
      throw StateError('Unsupported external consumer platform: $targetOS');
  }
}

Future<void> enableAndroidReleaseInternetPermission(
  Directory fixtureDirectory,
) async {
  final manifest = File(
    p.join(
      fixtureDirectory.path,
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    ),
  );
  if (!manifest.existsSync()) {
    throw StateError('Android main manifest does not exist: ${manifest.path}');
  }
  final contents = await manifest.readAsString();
  final internetPermissions = RegExp(
    r'<uses-permission\b[^>]*\bandroid:name\s*=\s*'
    r'''(["'])android\.permission\.INTERNET\1[^>]*/?>''',
  ).allMatches(contents).length;
  if (internetPermissions == 1) {
    return;
  }
  if (internetPermissions > 1) {
    throw StateError(
      'Android main manifest contains duplicate INTERNET permissions: '
      '${manifest.path}',
    );
  }
  final manifestElement = RegExp(r'<manifest\b[^>]*>').firstMatch(contents);
  if (manifestElement == null) {
    throw StateError('Invalid Android main manifest: ${manifest.path}');
  }
  await manifest.writeAsString(
    contents.replaceRange(
      manifestElement.end,
      manifestElement.end,
      '\n    <uses-permission '
      'android:name="android.permission.INTERNET"/>',
    ),
  );
}

String buildExternalConsumerRuntimeMain() {
  return '''
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nexa_http/nexa_http.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  const fixtureUrl = String.fromEnvironment('NEXA_HTTP_FIXTURE_URL');
  if (fixtureUrl.isEmpty) {
    throw StateError('NEXA_HTTP_FIXTURE_URL is required');
  }

  var exitCode = 0;
  NexaHttpClient? client;
  try {
    client = NexaHttpClientBuilder()
        .callTimeout(const Duration(seconds: 10))
        .userAgent('nexa-http-clean-host/2.0')
        .build();
    final request = RequestBuilder().url(Uri.parse(fixtureUrl)).get().build();
    final response = await client.newCall(request).execute();
    if (response.statusCode != 200 || response.body == null) {
      throw StateError('Unexpected fixture response: \${response.statusCode}');
    }
    final body = await response.body!.string();
    if (body.isEmpty) {
      throw StateError('Fixture response body is empty');
    }
  } catch (error, stackTrace) {
    stderr.writeln('NEXA_HTTP_RUNTIME_SMOKE_FAILED: \${error}');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    await client?.close();
  }
  if (exitCode == 0) {
    print('NEXA_HTTP_RUNTIME_PROOF {"request_completed":true,"callback_received":true,"body_consumed":true,"body_released":true,"client_closed":true}');
    if (Platform.isAndroid) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  exit(exitCode);
}
''';
}
