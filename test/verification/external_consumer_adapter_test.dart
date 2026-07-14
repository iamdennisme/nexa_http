import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/native_artifact_uniqueness.dart';
import '../../scripts/verification/external_consumer_adapter.dart';
import '../../scripts/verification/command.dart';
import '../../scripts/verification/model.dart';
import '../../scripts/verification/report.dart';

void main() {
  test(
    'consumer runtime uses only the public API and consumes the response body',
    () {
      final source = buildExternalConsumerRuntimeMain();

      expect(source, contains("import 'package:nexa_http/nexa_http.dart';"));
      expect(source, isNot(contains('package:nexa_http_native_')));
      expect(source, contains('.newCall(request).execute()'));
      expect(source, contains('await response.body!.string()'));
      expect(source, contains('NexaHttpClient? client;'));
      expect(source, contains('client = NexaHttpClientBuilder()'));
      expect(source, contains('await client?.close()'));
      const proofMarker =
          'NEXA_HTTP_RUNTIME_PROOF '
          '{"request_completed":true,"callback_received":true,'
          '"body_consumed":true,"body_released":true,'
          '"client_closed":true}';
      expect(source, contains(proofMarker));
      expect(source, isNot(contains('NEXA_HTTP_RUNTIME_SMOKE_OK')));
      final requestCompleted = source.indexOf(
        'await client.newCall(request).execute()',
      );
      final bodyConsumedAndReleased = source.indexOf(
        'await response.body!.string()',
      );
      final clientClosed = source.indexOf('await client?.close()');
      expect(bodyConsumedAndReleased, greaterThan(requestCompleted));
      expect(clientClosed, greaterThan(bodyConsumedAndReleased));
      expect(source.indexOf(proofMarker), greaterThan(clientClosed));
      final androidKeepAlive = source.indexOf(
        'if (Platform.isAndroid) {\n      return;\n    }',
      );
      expect(androidKeepAlive, greaterThan(source.indexOf(proofMarker)));
      final markerFlushDelay = source.indexOf(
        'await Future<void>.delayed(const Duration(seconds: 2))',
      );
      expect(markerFlushDelay, greaterThan(androidKeepAlive));
      expect(source.indexOf('exit(exitCode)'), greaterThan(markerFlushDelay));
      expect(source, contains("import 'dart:io';"));
    },
  );

  test('consumer runtime emits ordered lifecycle phase diagnostics', () {
    final source = buildExternalConsumerRuntimeMain();
    var previousIndex = -1;
    for (final phase in const <String>[
      'binding_ready',
      'app_mounted',
      'client_built',
      'request_started',
      'response_received',
      'client_closed',
    ]) {
      final index = source.indexOf('NEXA_HTTP_RUNTIME_PHASE $phase');
      expect(index, greaterThan(previousIndex), reason: phase);
      previousIndex = index;
    }
    expect(
      source.indexOf('NEXA_HTTP_RUNTIME_PROOF '),
      greaterThan(previousIndex),
    );
  });

  test('path consumer declares only the public package and target carrier', () {
    final pubspec = buildPathConsumerPubspec('/snapshot', targetOS: 'ios');

    expect(pubspec, contains(p.join('/snapshot', 'packages', 'nexa_http')));
    expect(
      pubspec,
      contains(p.join('/snapshot', 'packages', 'nexa_http_native_ios')),
    );
    expect(pubspec, isNot(contains('nexa_http_native_internal:')));
    expect(pubspec, isNot(contains('nexa_http_native_macos:')));
  });

  test(
    'candidate hook path serializes a Windows absolute path as a file URI',
    () {
      final pubspec = buildPathConsumerPubspec(
        r'D:\a\nexa_http\nexa_http',
        targetOS: 'windows',
        candidateDirectory: r'D:\a\nexa_http\nexa_http\candidate',
        candidateRef: '20c3786',
      );

      expect(
        pubspec,
        contains(
          'candidate_directory: "file:///D:/a/nexa_http/nexa_http/candidate"',
        ),
      );
      expect(pubspec, isNot(contains(r'candidate_directory: "D:\\a')));
    },
  );

  test('Apple execution keeps iOS and macOS consumer proofs separate', () {
    final platforms = externalConsumerPlatformsForExecution(
      const VerificationExecutionId('apple-macos'),
    );

    expect(platforms.map((platform) => platform.targetOS), <String>[
      'ios',
      'macos',
    ]);
  });

  test('Apple distribution resolves the single final app bundle', () async {
    final root = await Directory.systemTemp.createTemp(
      'nexa_http_apple_distribution_',
    );
    addTearDown(() => root.delete(recursive: true));
    final app = Directory(p.join(root.path, 'Runner.app'))..createSync();
    await File(p.join(root.path, 'sibling.dylib')).writeAsString('stale');

    final resolved = resolveSingleAppleAppBundle(root, targetOS: 'ios');

    expect(resolved.absolute.path, app.absolute.path);
  });

  test('Android runtime build targets only the x64 emulator ABI', () {
    final platform = externalConsumerPlatformsForExecution(
      const VerificationExecutionId('android-linux'),
    ).single;

    expect(platform.buildArguments, <String>[
      'build',
      'apk',
      '--release',
      '--target-platform=android-x64',
    ]);
  });

  test(
    'Android pipeline builds once with the fixture URL then reuses the APK',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'nexa_http_android_pipeline_',
      );
      addTearDown(() async => tempRoot.delete(recursive: true));
      final sourceRoot = Directory(p.join(tempRoot.path, 'source'))
        ..createSync();
      final commands = <VerificationCommand>[];
      final proofTracker = ExternalRuntimeProofMarkerTracker();
      int? releaseManifestPermissionCountAtBuild;
      Future<void> runCommand(VerificationCommand command) async {
        commands.add(command);
        if (command.executable == 'flutter' &&
            command.arguments.firstOrNull == 'create') {
          await _writeAndroidMainManifest(command.workingDirectory);
        }
        if (command.executable == 'flutter' &&
            command.arguments.firstOrNull == 'build') {
          final manifest = await File(
            p.join(
              command.workingDirectory,
              'android',
              'app',
              'src',
              'main',
              'AndroidManifest.xml',
            ),
          ).readAsString();
          releaseManifestPermissionCountAtBuild = RegExp(
            r'<uses-permission android:name="android\.permission\.INTERNET"\s*/>',
          ).allMatches(manifest).length;
        }
        if (command.executable == 'adb' &&
            command.arguments.contains('logcat') &&
            command.arguments.contains('-d')) {
          proofTracker.observeLine(_runtimeProofMarkerLine);
        }
      }

      final runner = createExternalConsumerRunner(
        fixtureRoot: Directory(p.join(tempRoot.path, 'fixtures')),
        fixtureUrl: Uri.parse('http://10.0.2.2:8080/healthz'),
        prepareSource: (_) async => sourceRoot,
        runCommand: runCommand,
        runRuntimeSmoke: createFlutterRuntimeSmokeRunner(
          runCommand,
          deviceIdForTargetOS: (_) => 'emulator-5554',
          proofTracker: proofTracker,
          waitForAndroidLogcatPoll: (_) async {},
        ),
      );

      await runner(const VerificationExecutionId('android-linux'));

      final flutterBuilds = commands
          .where(
            (command) =>
                command.executable == 'flutter' &&
                command.arguments.firstOrNull == 'build',
          )
          .toList(growable: false);
      expect(flutterBuilds, hasLength(1));
      expect(
        flutterBuilds.single.arguments,
        contains(
          '--dart-define=NEXA_HTTP_FIXTURE_URL=http://10.0.2.2:8080/healthz',
        ),
      );
      expect(
        commands.where(
          (command) =>
              command.executable == 'flutter' &&
              command.arguments.firstOrNull == 'run',
        ),
        isEmpty,
      );
      expect(
        commands.where(
          (command) =>
              command.executable == 'adb' &&
              command.arguments.contains('install'),
        ),
        hasLength(1),
      );
      expect(releaseManifestPermissionCountAtBuild, 1);
    },
  );

  test(
    'Apple consumer pipeline prepares source once and runs two platform smokes',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'nexa_http_external_pipeline_',
      );
      addTearDown(() async {
        if (tempRoot.existsSync()) {
          await tempRoot.delete(recursive: true);
        }
      });
      final sourceRoot = Directory(p.join(tempRoot.path, 'source'));
      await sourceRoot.create();
      var prepareRuns = 0;
      final commands = <VerificationCommand>[];
      final runtimePlatforms = <String>[];
      final runner = createExternalConsumerRunner(
        fixtureRoot: Directory(p.join(tempRoot.path, 'fixtures')),
        fixtureUrl: Uri.parse('http://127.0.0.1:8080/healthz'),
        prepareSource: (_) async {
          prepareRuns += 1;
          return sourceRoot;
        },
        runCommand: (command) async {
          commands.add(command);
          if (command.arguments case <String>[
            'create',
            '--platforms=macos',
            _,
            _,
          ]) {
            final runnerDirectory = Directory(
              p.join(command.workingDirectory, 'macos', 'Runner'),
            );
            await runnerDirectory.create(recursive: true);
            for (final name in <String>[
              'DebugProfile.entitlements',
              'Release.entitlements',
            ]) {
              await File(p.join(runnerDirectory.path, name)).writeAsString('''
<plist version="1.0">
<dict>
</dict>
</plist>
''');
            }
          }
        },
        runRuntimeSmoke:
            ({
              required fixtureDirectory,
              required platform,
              required fixtureUrl,
              required environment,
            }) async {
              runtimePlatforms.add(platform.targetOS);
            },
      );

      await runner(const VerificationExecutionId('apple-macos'));

      expect(prepareRuns, 1);
      expect(commands, hasLength(6));
      expect(runtimePlatforms, <String>['ios', 'macos']);
      for (final targetOS in runtimePlatforms) {
        final fixture = Directory(p.join(tempRoot.path, 'fixtures', targetOS));
        expect(File(p.join(fixture.path, 'pubspec.yaml')).existsSync(), isTrue);
        expect(
          File(p.join(fixture.path, 'lib', 'main.dart')).existsSync(),
          isTrue,
        );
      }
    },
  );

  test('runtime smoke uses an explicit device and fixture URL', () async {
    final commands = <VerificationCommand>[];
    final proofTracker = ExternalRuntimeProofMarkerTracker();
    final runner = createFlutterRuntimeSmokeRunner(
      (command) async {
        commands.add(command);
        proofTracker.observeLine(
          'flutter: NEXA_HTTP_RUNTIME_PROOF '
          '{"request_completed":true,"callback_received":true,'
          '"body_consumed":true,"body_released":true,'
          '"client_closed":true}',
        );
      },
      deviceIdForTargetOS: (targetOS) => 'device-$targetOS',
      proofTracker: proofTracker,
    );
    final fixture = Directory('/fixture/macos');

    await runner(
      fixtureDirectory: fixture,
      platform: const ExternalConsumerPlatform(
        targetOS: 'macos',
        buildArguments: <String>[],
      ),
      fixtureUrl: Uri.parse('http://127.0.0.1:8080/healthz'),
      environment: const <String, String>{},
    );

    expect(commands.single.executable, 'flutter');
    expect(commands.single.workingDirectory, fixture.path);
    expect(commands.single.arguments, <String>[
      'run',
      '-d',
      'device-macos',
      '--debug',
      '--dart-define=NEXA_HTTP_FIXTURE_URL=http://127.0.0.1:8080/healthz',
    ]);
  });

  test('runtime smoke rejects exit-zero without a proof marker', () async {
    final runner = createFlutterRuntimeSmokeRunner(
      (_) async {},
      deviceIdForTargetOS: (_) => 'macos',
      proofTracker: ExternalRuntimeProofMarkerTracker(),
    );

    await expectLater(
      runner(
        fixtureDirectory: Directory('/fixture/macos'),
        platform: const ExternalConsumerPlatform(
          targetOS: 'macos',
          buildArguments: <String>[],
        ),
        fixtureUrl: Uri.parse('http://127.0.0.1:8080/healthz'),
        environment: const <String, String>{},
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('runtime proof failure reports the observed fixture phases', () {
    final tracker = ExternalRuntimeProofMarkerTracker()
      ..observeLine('flutter: NEXA_HTTP_RUNTIME_PHASE client_built')
      ..observeLine('flutter: NEXA_HTTP_RUNTIME_PHASE request_started');

    expect(
      () => tracker.requireSingleProofSince(
        0,
        previousPhaseCount: 0,
        targetOS: 'android',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('phases=client_built,request_started'),
        ),
      ),
    );
  });

  test('runtime proof wins over a Flutter teardown connection error', () async {
    final proofTracker = ExternalRuntimeProofMarkerTracker();
    final runner = createFlutterRuntimeSmokeRunner(
      (_) async {
        proofTracker.observeLine(_runtimeProofMarkerLine);
        throw ProcessException(
          'flutter',
          const <String>['run'],
          'DDS failed',
          1,
        );
      },
      deviceIdForTargetOS: (_) => 'macos',
      proofTracker: proofTracker,
    );

    await expectLater(
      runner(
        fixtureDirectory: Directory('/fixture/macos'),
        platform: const ExternalConsumerPlatform(
          targetOS: 'macos',
          buildArguments: <String>[],
        ),
        fixtureUrl: Uri.parse('http://127.0.0.1:8080/healthz'),
        environment: const <String, String>{},
      ),
      completes,
    );
  });

  test('Android runtime proof is recovered from cleared logcat', () async {
    final commands = <VerificationCommand>[];
    final proofTracker = ExternalRuntimeProofMarkerTracker();
    final runner = createFlutterRuntimeSmokeRunner(
      (command) async {
        commands.add(command);
        if (command.arguments.contains('logcat') &&
            command.arguments.contains('-d')) {
          proofTracker.observeLine(_runtimeProofMarkerLine);
        }
      },
      deviceIdForTargetOS: (_) => 'emulator-5554',
      proofTracker: proofTracker,
    );

    await runner(
      fixtureDirectory: Directory('/fixture/android'),
      platform: const ExternalConsumerPlatform(
        targetOS: 'android',
        buildArguments: <String>[],
      ),
      fixtureUrl: Uri.parse('http://10.0.2.2:8080/healthz'),
      environment: const <String, String>{},
    );

    expect(
      commands.map(
        (command) => <Object>[command.executable, command.arguments],
      ),
      <List<Object>>[
        <Object>[
          'adb',
          <String>[
            '-s',
            'emulator-5554',
            'install',
            '-t',
            '-r',
            '/fixture/android/build/app/outputs/flutter-apk/app-release.apk',
          ],
        ],
        <Object>[
          'adb',
          <String>['-s', 'emulator-5554', 'logcat', '-c'],
        ],
        <Object>[
          'adb',
          <String>[
            '-s',
            'emulator-5554',
            'shell',
            'am',
            'start',
            '-W',
            '-n',
            'com.example.nexa_http_external_consumer_fixture/.MainActivity',
          ],
        ],
        <Object>[
          'adb',
          <String>[
            '-s',
            'emulator-5554',
            'logcat',
            '-d',
            '-v',
            'raw',
            '-s',
            'flutter:I',
          ],
        ],
        <Object>[
          'adb',
          <String>[
            '-s',
            'emulator-5554',
            'shell',
            'am',
            'force-stop',
            'com.example.nexa_http_external_consumer_fixture',
          ],
        ],
      ],
    );
  });

  test('Android runtime proof polls filtered logcat until delivery', () async {
    final commands = <VerificationCommand>[];
    final proofTracker = ExternalRuntimeProofMarkerTracker();
    var logcatDumps = 0;
    var waits = 0;
    final runner = createFlutterRuntimeSmokeRunner(
      (command) async {
        commands.add(command);
        if (command.executable == 'adb' &&
            command.arguments.contains('logcat') &&
            command.arguments.contains('-d')) {
          logcatDumps += 1;
          if (logcatDumps == 2) {
            proofTracker.observeLine(_runtimeProofMarkerLine);
          }
        }
      },
      deviceIdForTargetOS: (_) => 'emulator-5554',
      proofTracker: proofTracker,
      waitForAndroidLogcatPoll: (_) async {
        waits += 1;
      },
    );

    await runner(
      fixtureDirectory: Directory('/fixture/android'),
      platform: const ExternalConsumerPlatform(
        targetOS: 'android',
        buildArguments: <String>[],
      ),
      fixtureUrl: Uri.parse('http://10.0.2.2:8080/healthz'),
      environment: const <String, String>{},
    );

    expect(logcatDumps, 2);
    expect(waits, 1);
    expect(
      commands
          .where(
            (command) =>
                command.executable == 'adb' &&
                command.arguments.contains('logcat') &&
                command.arguments.contains('-d'),
          )
          .every(
            (command) =>
                command.arguments.length >= 2 &&
                command.arguments[command.arguments.length - 2] == '-s' &&
                command.arguments.last == 'flutter:I',
          ),
      isTrue,
    );
  });

  test(
    'Android runtime proof tolerates a slow ATD callback delivery',
    () async {
      final proofTracker = ExternalRuntimeProofMarkerTracker();
      var logcatDumps = 0;
      final runner = createFlutterRuntimeSmokeRunner(
        (command) async {
          if (command.executable == 'adb' &&
              command.arguments.contains('logcat') &&
              command.arguments.contains('-d')) {
            logcatDumps += 1;
            if (logcatDumps == 45) {
              proofTracker.observeLine(_runtimeProofMarkerLine);
            }
          }
        },
        deviceIdForTargetOS: (_) => 'emulator-5554',
        proofTracker: proofTracker,
        waitForAndroidLogcatPoll: (_) async {},
      );

      await runner(
        fixtureDirectory: Directory('/fixture/android'),
        platform: const ExternalConsumerPlatform(
          targetOS: 'android',
          buildArguments: <String>[],
        ),
        fixtureUrl: Uri.parse('http://10.0.2.2:8080/healthz'),
        environment: const <String, String>{},
      );

      expect(logcatDumps, 45);
    },
  );

  test('Android runtime proof polling is bounded at sixty attempts', () async {
    var logcatDumps = 0;
    var waits = 0;
    final runner = createFlutterRuntimeSmokeRunner(
      (command) async {
        if (command.executable == 'adb' &&
            command.arguments.contains('logcat') &&
            command.arguments.contains('-d')) {
          logcatDumps += 1;
        }
      },
      deviceIdForTargetOS: (_) => 'emulator-5554',
      proofTracker: ExternalRuntimeProofMarkerTracker(),
      waitForAndroidLogcatPoll: (_) async {
        waits += 1;
      },
    );

    await expectLater(
      runner(
        fixtureDirectory: Directory('/fixture/android'),
        platform: const ExternalConsumerPlatform(
          targetOS: 'android',
          buildArguments: <String>[],
        ),
        fixtureUrl: Uri.parse('http://10.0.2.2:8080/healthz'),
        environment: const <String, String>{},
      ),
      throwsA(isA<StateError>()),
    );

    expect(logcatDumps, 60);
    expect(waits, 59);
  });

  test(
    'Android runtime proof rejects duplicate markers from one logcat dump',
    () async {
      final proofTracker = ExternalRuntimeProofMarkerTracker();
      final runner = createFlutterRuntimeSmokeRunner(
        (command) async {
          if (command.executable == 'adb' &&
              command.arguments.contains('logcat') &&
              command.arguments.contains('-d')) {
            proofTracker
              ..observeLine(_runtimeProofMarkerLine)
              ..observeLine(_runtimeProofMarkerLine);
          }
        },
        deviceIdForTargetOS: (_) => 'emulator-5554',
        proofTracker: proofTracker,
        waitForAndroidLogcatPoll: (_) async {},
      );

      await expectLater(
        runner(
          fixtureDirectory: Directory('/fixture/android'),
          platform: const ExternalConsumerPlatform(
            targetOS: 'android',
            buildArguments: <String>[],
          ),
          fixtureUrl: Uri.parse('http://10.0.2.2:8080/healthz'),
          environment: const <String, String>{},
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'uniqueness returns runtime proofs for the matching packaged digests',
    () async {
      const iosDigest =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const macosDigest =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final session = await _createAppleProofSession(
        preparedArtifactProofs: <VerificationPreparedArtifactProof>[
          _iosPreparedProof(iosDigest),
          _macosPreparedProof(macosDigest),
        ],
        iosPackagedDigest: iosDigest,
        macosPackagedDigest: macosDigest,
      );
      addTearDown(session.close);

      await session.runner(const VerificationExecutionId('apple-macos'));
      final proofs = await session.verifyArtifactUniqueness(
        const VerificationExecutionId('apple-macos'),
      );

      expect(proofs, hasLength(2));
      expect(proofs.map((proof) => proof.target.targetOS), <String>[
        'ios',
        'macos',
      ]);
      expect(proofs.map((proof) => proof.absolutePackagedFile), <String>[
        '/packaged/ios.dylib',
        '/packaged/macos.dylib',
      ]);
      expect(proofs.map((proof) => proof.sha256), <String>[
        iosDigest,
        macosDigest,
      ]);
      for (final proof in proofs) {
        expect(proof.payloadCount, 1);
        expect(proof.requestCompleted, isTrue);
        expect(proof.callbackReceived, isTrue);
        expect(proof.bodyConsumed, isTrue);
        expect(proof.bodyReleased, isTrue);
        expect(proof.clientClosed, isTrue);
      }
    },
  );

  test('uniqueness rejects a packaged digest with no prepared match', () async {
    const preparedIosDigest =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const packagedIosDigest =
        'cccccccccccccccccccccccccccccccc'
        'cccccccccccccccccccccccccccccccc';
    const macosDigest =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final session = await _createAppleProofSession(
      preparedArtifactProofs: <VerificationPreparedArtifactProof>[
        _iosPreparedProof(preparedIosDigest),
        _macosPreparedProof(macosDigest),
      ],
      iosPackagedDigest: packagedIosDigest,
      macosPackagedDigest: macosDigest,
    );
    addTearDown(session.close);
    await session.runner(const VerificationExecutionId('apple-macos'));

    expect(
      () => session.verifyArtifactUniqueness(
        const VerificationExecutionId('apple-macos'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('ios'),
            contains(packagedIosDigest),
            contains('proof_diagnostics='),
            contains('"prepared_proofs":'),
            contains(preparedIosDigest),
            contains('"path":"/prepared/ios.dylib"'),
          ),
        ),
      ),
    );
  });

  test('uniqueness rejects ambiguous prepared proofs', () async {
    const iosDigest =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const macosDigest =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final session = await _createAppleProofSession(
      preparedArtifactProofs: <VerificationPreparedArtifactProof>[
        _iosPreparedProof(iosDigest),
        _iosPreparedProof(iosDigest),
        _macosPreparedProof(macosDigest),
      ],
      iosPackagedDigest: iosDigest,
      macosPackagedDigest: macosDigest,
    );
    addTearDown(session.close);
    await session.runner(const VerificationExecutionId('apple-macos'));

    expect(
      () => session.verifyArtifactUniqueness(
        const VerificationExecutionId('apple-macos'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('ios'), contains('matching_prepared_proofs=2')),
        ),
      ),
    );
  });

  test('macOS clean host enables outbound network access', () async {
    final fixture = await Directory.systemTemp.createTemp(
      'nexa_http_macos_entitlements_',
    );
    addTearDown(() => fixture.delete(recursive: true));
    final runnerDirectory = Directory(p.join(fixture.path, 'macos', 'Runner'));
    await runnerDirectory.create(recursive: true);
    for (final name in <String>[
      'DebugProfile.entitlements',
      'Release.entitlements',
    ]) {
      await File(p.join(runnerDirectory.path, name)).writeAsString('''
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
</dict>
</plist>
''');
    }

    await enableMacosNetworkClientEntitlement(fixture);

    for (final name in <String>[
      'DebugProfile.entitlements',
      'Release.entitlements',
    ]) {
      final contents = await File(
        p.join(runnerDirectory.path, name),
      ).readAsString();
      expect(
        RegExp(
          r'<key>com\.apple\.security\.network\.client</key>',
        ).allMatches(contents),
        hasLength(1),
      );
      expect(contents, contains('<true/>'));
    }
  });
}

VerificationPreparedArtifactProof _iosPreparedProof(String digest) {
  return VerificationPreparedArtifactProof(
    target: VerificationNativeTargetTuple(
      targetOS: 'ios',
      targetArchitecture: 'arm64',
      targetSdk: 'simulator',
      rustTarget: 'aarch64-apple-ios-sim',
    ),
    nativeAssetId:
        'package:nexa_http_native_ios/src/native/nexa_http_native_ffi.dart',
    absolutePreparedFile: '/prepared/ios.dylib',
    sha256: digest,
    identitySha256: digest,
    sourceIdentity: 'workspace',
  );
}

VerificationPreparedArtifactProof _macosPreparedProof(String digest) {
  return VerificationPreparedArtifactProof(
    target: VerificationNativeTargetTuple(
      targetOS: 'macos',
      targetArchitecture: 'arm64',
      targetSdk: null,
      rustTarget: 'aarch64-apple-darwin',
    ),
    nativeAssetId:
        'package:nexa_http_native_macos/src/native/nexa_http_native_ffi.dart',
    absolutePreparedFile: '/prepared/macos.dylib',
    sha256: digest,
    identitySha256: digest,
    sourceIdentity: 'workspace',
  );
}

Future<ExternalConsumerVerificationSession> _createAppleProofSession({
  required List<VerificationPreparedArtifactProof> preparedArtifactProofs,
  required String iosPackagedDigest,
  required String macosPackagedDigest,
}) {
  final runtimeProofTracker = ExternalRuntimeProofMarkerTracker();
  return createExternalConsumerSession(
    workspaceRoot: '/workspace',
    fixtureUrl: Uri.parse('http://127.0.0.1:8080/healthz'),
    deviceIds: const <String, String>{'ios': 'ios-simulator', 'macos': 'macos'},
    runCommand: (command) async {
      if (command.arguments case <String>['run', ...]) {
        runtimeProofTracker.observeLine(_runtimeProofMarkerLine);
      }
      if (command.arguments case <String>[
        'create',
        '--platforms=macos',
        _,
        _,
      ]) {
        await _writeMacosEntitlementFixtures(command.workingDirectory);
      }
      if (command.arguments case <String>['build', 'ios', ...]) {
        await Directory(
          p.join(
            command.workingDirectory,
            'build',
            'ios',
            'iphonesimulator',
            'Runner.app',
          ),
        ).create(recursive: true);
      }
      if (command.arguments case <String>['build', 'macos', ...]) {
        await Directory(
          p.join(
            command.workingDirectory,
            'build',
            'macos',
            'Build',
            'Products',
            'Debug',
            'Runner.app',
          ),
        ).create(recursive: true);
      }
    },
    runtimeProofTracker: runtimeProofTracker,
    preparedArtifactProofs: preparedArtifactProofs,
    verifyUniquePayload: ({required distribution, required platform}) async {
      return VerifiedNativePayload(
        file: File('/packaged/$platform.dylib'),
        sha256: platform == 'ios' ? iosPackagedDigest : macosPackagedDigest,
        identitySha256: platform == 'ios'
            ? iosPackagedDigest
            : macosPackagedDigest,
      );
    },
  );
}

const _runtimeProofMarkerLine =
    'flutter: NEXA_HTTP_RUNTIME_PROOF '
    '{"request_completed":true,"callback_received":true,'
    '"body_consumed":true,"body_released":true,"client_closed":true}';

Future<void> _writeMacosEntitlementFixtures(String fixturePath) async {
  final runnerDirectory = Directory(p.join(fixturePath, 'macos', 'Runner'));
  await runnerDirectory.create(recursive: true);
  for (final name in <String>[
    'DebugProfile.entitlements',
    'Release.entitlements',
  ]) {
    await File(p.join(runnerDirectory.path, name)).writeAsString('''
<plist version="1.0">
<dict>
</dict>
</plist>
''');
  }
}

Future<void> _writeAndroidMainManifest(String fixturePath) async {
  final manifest = File(
    p.join(fixturePath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
  );
  await manifest.parent.create(recursive: true);
  await manifest.writeAsString('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="fixture" />
</manifest>
''');
}
