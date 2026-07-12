import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/verification/external_consumer_adapter.dart';
import '../../scripts/verification/command.dart';
import '../../scripts/verification/model.dart';

void main() {
  test(
    'consumer runtime uses only the public API and consumes the response body',
    () {
      final source = buildExternalConsumerRuntimeMain();

      expect(source, contains("import 'package:nexa_http/nexa_http.dart';"));
      expect(source, isNot(contains('package:nexa_http_native_')));
      expect(source, contains('.newCall(request).execute()'));
      expect(source, contains('await response.body!.string()'));
      expect(source, contains('await client.close()'));
      expect(source, contains('NEXA_HTTP_RUNTIME_SMOKE_OK'));
      expect(source, contains("import 'dart:io';"));
      expect(source, contains('exit(0)'));
    },
  );

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

  test('Apple execution keeps iOS and macOS consumer proofs separate', () {
    final platforms = externalConsumerPlatformsForExecution(
      const VerificationExecutionId('apple-macos'),
    );

    expect(platforms.map((platform) => platform.targetOS), <String>[
      'ios',
      'macos',
    ]);
  });

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
        runCommand: (command) async => commands.add(command),
        runRuntimeSmoke:
            ({
              required fixtureDirectory,
              required platform,
              required fixtureUrl,
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
    final runner = createFlutterRuntimeSmokeRunner(
      (command) async => commands.add(command),
      deviceIdForTargetOS: (targetOS) => 'device-$targetOS',
    );
    final fixture = Directory('/fixture/macos');

    await runner(
      fixtureDirectory: fixture,
      platform: const ExternalConsumerPlatform(
        targetOS: 'macos',
        buildArguments: <String>[],
      ),
      fixtureUrl: Uri.parse('http://127.0.0.1:8080/healthz'),
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
}
