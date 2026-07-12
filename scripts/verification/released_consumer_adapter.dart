import 'dart:io';

import 'package:path/path.dart' as p;

import 'command.dart';
import 'external_consumer_adapter.dart';
import 'model.dart';

typedef ReleasedConsumerRunner =
    Future<void> Function(VerificationExecutionId executionId);

ReleasedConsumerRunner createReleasedConsumerRunner({
  required String repoUrl,
  required String ref,
  required Uri fixtureUrl,
  required Map<String, String> deviceIds,
  required VerificationCommandRunner runCommand,
}) {
  return (executionId) async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'nexa_http_released_consumer_',
    );
    final runtimeSmoke = createFlutterRuntimeSmokeRunner(
      runCommand,
      deviceIdForTargetOS: (targetOS) => deviceIds[targetOS] ?? '',
    );
    try {
      for (final platform in externalConsumerPlatformsForExecution(
        executionId,
      )) {
        final fixtureDirectory = Directory(
          p.join(tempRoot.path, platform.targetOS),
        );
        await fixtureDirectory.create(recursive: true);
        await runCommand(
          VerificationCommand(
            executable: 'flutter',
            arguments: platform.createArguments,
            workingDirectory: fixtureDirectory.path,
          ),
        );
        await File(p.join(fixtureDirectory.path, 'pubspec.yaml')).writeAsString(
          buildReleasedConsumerPubspec(
            repoUrl: repoUrl,
            ref: ref,
            targetOS: platform.targetOS,
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
          ),
        );
        await runCommand(
          VerificationCommand(
            executable: 'flutter',
            arguments: platform.buildArguments,
            workingDirectory: fixtureDirectory.path,
          ),
        );
        await runtimeSmoke(
          fixtureDirectory: fixtureDirectory,
          platform: platform,
          fixtureUrl: fixtureUrl,
        );
      }
    } finally {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    }
  };
}

String buildReleasedConsumerPubspec({
  required String repoUrl,
  required String ref,
  required String targetOS,
}) {
  final resolvedRepoUrl = repoUrl.trim();
  final resolvedRef = ref.trim();
  if (resolvedRepoUrl.isEmpty) {
    throw StateError('Released consumer repository URL is required');
  }
  if (resolvedRef.isEmpty || resolvedRef == 'vX.Y.Z') {
    throw StateError('Released consumer requires a real git ref');
  }
  final carrier = switch (targetOS) {
    'android' => 'nexa_http_native_android',
    'ios' => 'nexa_http_native_ios',
    'macos' => 'nexa_http_native_macos',
    'windows' => 'nexa_http_native_windows',
    _ => throw StateError('No released consumer carrier for $targetOS'),
  };
  return '''
name: nexa_http_released_consumer_fixture
publish_to: none

environment:
  sdk: ^3.11.0

dependencies:
  flutter:
    sdk: flutter
  nexa_http:
    git:
      url: $resolvedRepoUrl
      ref: $resolvedRef
      path: packages/nexa_http
  $carrier:
    git:
      url: $resolvedRepoUrl
      ref: $resolvedRef
      path: packages/$carrier
''';
}
