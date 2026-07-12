import 'dart:io';

import 'package:path/path.dart' as p;

import 'command.dart';
import 'consumer_fixture.dart';
import 'model.dart';

typedef ExternalConsumerSourcePreparer =
    Future<Directory> Function(VerificationExecutionId executionId);

typedef ExternalRuntimeSmokeRunner =
    Future<void> Function({
      required Directory fixtureDirectory,
      required ExternalConsumerPlatform platform,
      required Uri fixtureUrl,
    });

typedef ExternalDeviceIdResolver = String Function(String targetOS);

ExternalRuntimeSmokeRunner createFlutterRuntimeSmokeRunner(
  VerificationCommandRunner runCommand, {
  required ExternalDeviceIdResolver deviceIdForTargetOS,
  Map<String, String> environment = const <String, String>{},
}) {
  return ({
    required fixtureDirectory,
    required platform,
    required fixtureUrl,
  }) async {
    final deviceId = deviceIdForTargetOS(platform.targetOS).trim();
    if (deviceId.isEmpty) {
      throw StateError(
        'A Flutter device ID is required for ${platform.targetOS}',
      );
    }
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
        environment: environment,
      ),
    );
  };
}

typedef ExternalConsumerRunner =
    Future<void> Function(VerificationExecutionId executionId);

final class ExternalConsumerVerificationSession {
  const ExternalConsumerVerificationSession._({
    required this.runner,
    required this.tempRoot,
  });

  final ExternalConsumerRunner runner;
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
  Map<String, String> commandEnvironment = const <String, String>{},
}) async {
  final tempRoot = await Directory.systemTemp.createTemp(
    'nexa_http_external_consumer_',
  );
  final sourceDirectory = Directory(p.join(tempRoot.path, 'source'));
  final materializer = ConsumerFixtureMaterializer(
    workspaceRoot: workspaceRoot,
    outputDirectoryForExecution: (_) => sourceDirectory,
  );
  final runtimeSmoke = createFlutterRuntimeSmokeRunner(
    runCommand,
    deviceIdForTargetOS: (targetOS) => deviceIds[targetOS] ?? '',
    environment: commandEnvironment,
  );
  return ExternalConsumerVerificationSession._(
    tempRoot: tempRoot,
    runner: createExternalConsumerRunner(
      fixtureRoot: Directory(p.join(tempRoot.path, 'fixtures')),
      fixtureUrl: fixtureUrl,
      prepareSource: (executionId) {
        return materializer.prepare(VerificationRunContext(executionId));
      },
      runCommand: runCommand,
      runRuntimeSmoke: runtimeSmoke,
      commandEnvironment: commandEnvironment,
    ),
  );
}

ExternalConsumerRunner createExternalConsumerRunner({
  required Directory fixtureRoot,
  required Uri fixtureUrl,
  required ExternalConsumerSourcePreparer prepareSource,
  required VerificationCommandRunner runCommand,
  required ExternalRuntimeSmokeRunner runRuntimeSmoke,
  Map<String, String> commandEnvironment = const <String, String>{},
}) {
  return (executionId) async {
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
          environment: commandEnvironment,
        ),
      );
      await File(p.join(fixtureDirectory.path, 'pubspec.yaml')).writeAsString(
        buildPathConsumerPubspec(sourceRoot.path, targetOS: platform.targetOS),
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
          environment: commandEnvironment,
        ),
      );
      await runCommand(
        VerificationCommand(
          executable: 'flutter',
          arguments: platform.buildArguments,
          workingDirectory: fixtureDirectory.path,
          environment: commandEnvironment,
        ),
      );
      await runRuntimeSmoke(
        fixtureDirectory: fixtureDirectory,
        platform: platform,
        fixtureUrl: fixtureUrl,
      );
    }
  };
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
        buildArguments: <String>['build', 'apk', '--debug'],
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

String buildPathConsumerPubspec(String sourceRoot, {required String targetOS}) {
  final carrier = switch (targetOS) {
    'android' => 'nexa_http_native_android',
    'ios' => 'nexa_http_native_ios',
    'macos' => 'nexa_http_native_macos',
    'windows' => 'nexa_http_native_windows',
    _ => throw StateError('No carrier package for target OS $targetOS'),
  };
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
''';
}

String buildExternalConsumerRuntimeMain() {
  return '''
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nexa_http/nexa_http.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const fixtureUrl = String.fromEnvironment('NEXA_HTTP_FIXTURE_URL');
  if (fixtureUrl.isEmpty) {
    throw StateError('NEXA_HTTP_FIXTURE_URL is required');
  }

  final client = NexaHttpClientBuilder()
      .callTimeout(const Duration(seconds: 10))
      .userAgent('nexa-http-clean-host/2.0')
      .build();
  try {
    final request = RequestBuilder().url(Uri.parse(fixtureUrl)).get().build();
    final response = await client.newCall(request).execute();
    if (response.statusCode != 200 || response.body == null) {
      throw StateError('Unexpected fixture response: \${response.statusCode}');
    }
    final body = await response.body!.string();
    if (body.isEmpty) {
      throw StateError('Fixture response body is empty');
    }
    print('NEXA_HTTP_RUNTIME_SMOKE_OK');
  } finally {
    await client.close();
  }
  exit(0);
}
''';
}
