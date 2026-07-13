import 'package:test/test.dart';

import '../../scripts/verification/command.dart';
import '../../scripts/verification/external_consumer_adapter.dart';
import '../../scripts/verification/model.dart';
import '../../scripts/verification/released_consumer_adapter.dart';

void main() {
  test('released consumer uses one explicit git ref and public packages', () {
    final pubspec = buildReleasedConsumerPubspec(
      repoUrl: 'https://github.com/example/nexa_http.git',
      ref: 'v2.0.0',
      targetOS: 'macos',
    );

    expect(pubspec, contains('path: packages/nexa_http'));
    expect(pubspec, contains('path: packages/nexa_http_native_macos'));
    expect(RegExp(r'ref: v2\.0\.0').allMatches(pubspec), hasLength(2));
    expect(pubspec, isNot(contains('nexa_http_native_internal:')));
  });

  test('released consumer rejects placeholder refs', () {
    expect(
      () => buildReleasedConsumerPubspec(
        repoUrl: 'https://github.com/example/nexa_http.git',
        ref: 'vX.Y.Z',
        targetOS: 'macos',
      ),
      throwsStateError,
    );
  });

  test('released Android consumer builds once with its fixture URL', () async {
    final commands = <VerificationCommand>[];
    final proofTracker = ExternalRuntimeProofMarkerTracker();
    final runner = createReleasedConsumerRunner(
      repoUrl: 'https://github.com/example/nexa_http.git',
      ref: 'v2.0.0',
      fixtureUrl: Uri.parse('http://10.0.2.2:8080/healthz'),
      deviceIds: const <String, String>{'android': 'emulator-5554'},
      runCommand: (command) async {
        commands.add(command);
        if (command.executable == 'adb' &&
            command.arguments.contains('logcat') &&
            command.arguments.contains('-d')) {
          proofTracker.observeLine(
            'flutter: NEXA_HTTP_RUNTIME_PROOF '
            '{"request_completed":true,"callback_received":true,'
            '"body_consumed":true,"body_released":true,'
            '"client_closed":true}',
          );
        }
      },
      runtimeProofTracker: proofTracker,
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
  });
}
