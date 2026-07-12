import 'dart:convert';
import 'dart:io';

import '../workspace_bootstrap.dart';
import 'catalog.dart';
import 'candidate_adapter.dart';
import 'candidate_set.dart';
import 'checks/candidate_checks.dart';
import 'checks/integration_checks.dart';
import 'checks/released_consumer_check.dart';
import 'checks/static_checks.dart';
import 'development_path_adapter.dart';
import 'executor.dart';
import 'external_consumer_adapter.dart';
import 'model.dart';
import 'native_abi_adapter.dart';
import 'planner.dart';
import 'report.dart';
import 'released_consumer_adapter.dart';
import 'target_matrix.dart';
import 'workspace_inventory.dart';

typedef VerificationCliWriter = void Function(String value);

final class VerificationIntegrationCliInput {
  VerificationIntegrationCliInput({
    required this.executionId,
    required this.fixtureUrl,
    required Map<String, String> deviceIds,
    required this.reportOut,
  }) : deviceIds = Map<String, String>.unmodifiable(deviceIds);

  final VerificationExecutionId executionId;
  final Uri fixtureUrl;
  final Map<String, String> deviceIds;
  final File? reportOut;
}

final class VerificationCandidateCliInput {
  const VerificationCandidateCliInput({
    required this.executionId,
    required this.candidateDirectory,
    required this.candidateId,
    required this.expectedDigest,
    required this.sdkRef,
    required this.fixtureUrl,
    required this.deviceId,
    required this.reportOut,
  });

  final VerificationExecutionId executionId;
  final Directory candidateDirectory;
  final String candidateId;
  final String expectedDigest;
  final String sdkRef;
  final Uri fixtureUrl;
  final String deviceId;
  final File? reportOut;
}

final class VerificationReleasedConsumerCliInput {
  const VerificationReleasedConsumerCliInput({
    required this.integration,
    required this.repoUrl,
    required this.ref,
  });

  final VerificationIntegrationCliInput integration;
  final String repoUrl;
  final String ref;
}

final class VerificationCliUsageError implements Exception {
  const VerificationCliUsageError(this.message);

  final String message;

  @override
  String toString() => message;
}

final class VerificationCliCommand {
  const VerificationCliCommand({required this.name, required this.arguments});

  final String name;
  final List<String> arguments;
}

const verificationCliCommandNames = <String>[
  'bootstrap',
  'verify-static',
  'verify-integration',
  'verify-release-candidate',
  'check',
  'matrix',
];

VerificationCliCommand parseVerificationCliCommand(List<String> arguments) {
  final command = arguments.isEmpty ? '' : arguments.first;
  if (verificationCliCommandNames.contains(command)) {
    return VerificationCliCommand(
      name: command,
      arguments: List<String>.unmodifiable(arguments.skip(1)),
    );
  }
  throw VerificationCliUsageError('Unknown workspace command: $command');
}

VerificationIntegrationCliInput parseIntegrationCliInput(
  List<String> arguments,
) {
  String? executionValue;
  String? fixtureUrlValue;
  File? reportOut;
  final deviceIds = <String, String>{};

  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length) {
      throw VerificationCliUsageError(
        'Missing value for integration argument ${arguments[index]}',
      );
    }
    final option = arguments[index];
    final value = arguments[index + 1].trim();
    switch (option) {
      case '--execution':
        executionValue = value;
      case '--fixture-url':
        fixtureUrlValue = value;
      case '--device':
        final separator = value.indexOf('=');
        if (separator <= 0 || separator == value.length - 1) {
          throw VerificationCliUsageError(
            'Invalid device input: $value; expected <target-os>=<device-id>',
          );
        }
        final targetOS = value.substring(0, separator);
        if (deviceIds.containsKey(targetOS)) {
          throw VerificationCliUsageError(
            'Duplicate device input for target OS $targetOS',
          );
        }
        deviceIds[targetOS] = value.substring(separator + 1);
      case '--report-out':
        reportOut = File(value);
      default:
        throw VerificationCliUsageError(
          'Unknown verify-integration argument: $option',
        );
    }
  }

  if (executionValue == null || fixtureUrlValue == null) {
    throw const VerificationCliUsageError(
      'verify-integration requires --execution and --fixture-url',
    );
  }
  final executionId = VerificationExecutionId(executionValue);
  final fixtureUrl = Uri.tryParse(fixtureUrlValue);
  if (fixtureUrl == null ||
      !fixtureUrl.hasScheme ||
      (fixtureUrl.scheme != 'http' && fixtureUrl.scheme != 'https')) {
    throw VerificationCliUsageError(
      'Invalid integration fixture URL: $fixtureUrlValue',
    );
  }
  final requiredTargetOS = externalConsumerPlatformsForExecution(
    executionId,
  ).map((platform) => platform.targetOS).toSet();
  final missingDevices = requiredTargetOS.difference(deviceIds.keys.toSet());
  if (missingDevices.isNotEmpty) {
    throw VerificationCliUsageError(
      'Missing device IDs for target OS: ${missingDevices.toList()..sort()}',
    );
  }
  final unknownDevices = deviceIds.keys.toSet().difference(requiredTargetOS);
  if (unknownDevices.isNotEmpty) {
    throw VerificationCliUsageError(
      'Unexpected device IDs for target OS: ${unknownDevices.toList()..sort()}',
    );
  }
  return VerificationIntegrationCliInput(
    executionId: executionId,
    fixtureUrl: fixtureUrl,
    deviceIds: deviceIds,
    reportOut: reportOut,
  );
}

VerificationCandidateCliInput parseCandidateCliInput(List<String> arguments) {
  final values = <String, String>{};
  final devices = <String, String>{};
  File? reportOut;
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length) {
      throw VerificationCliUsageError(
        'Missing value for candidate argument ${arguments[index]}',
      );
    }
    final option = arguments[index];
    final value = arguments[index + 1].trim();
    if (option == '--device') {
      final separator = value.indexOf('=');
      if (separator <= 0 || separator == value.length - 1) {
        throw VerificationCliUsageError(
          'Invalid device input: $value; expected <target-os>=<device-id>',
        );
      }
      devices[value.substring(0, separator)] = value.substring(separator + 1);
      continue;
    }
    if (option == '--report-out') {
      reportOut = File(value);
      continue;
    }
    const supported = <String>{
      '--execution',
      '--candidate-dir',
      '--candidate-id',
      '--candidate-digest',
      '--sdk-ref',
      '--fixture-url',
    };
    if (!supported.contains(option)) {
      throw VerificationCliUsageError(
        'Unknown verify-release-candidate argument: $option',
      );
    }
    if (values.containsKey(option)) {
      throw VerificationCliUsageError('Duplicate candidate argument: $option');
    }
    values[option] = value;
  }
  if (values.length != 6 || values.values.any((value) => value.isEmpty)) {
    throw const VerificationCliUsageError(
      'verify-release-candidate requires execution, candidate directory, '
      'candidate ID/digest, SDK ref, fixture URL and device',
    );
  }
  final executionId = VerificationExecutionId(values['--execution']!);
  final targetOS = _candidateTargetOS(executionId);
  if (devices.length != 1 || !devices.containsKey(targetOS)) {
    throw VerificationCliUsageError(
      'Candidate execution $executionId requires only --device $targetOS=<id>',
    );
  }
  final expectedDigest = values['--candidate-digest']!.toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedDigest)) {
    throw const VerificationCliUsageError(
      'Candidate digest must be a SHA-256 value',
    );
  }
  final fixtureUrl = Uri.tryParse(values['--fixture-url']!);
  if (fixtureUrl == null ||
      (fixtureUrl.scheme != 'http' && fixtureUrl.scheme != 'https')) {
    throw VerificationCliUsageError(
      'Invalid candidate fixture URL: ${values['--fixture-url']}',
    );
  }
  return VerificationCandidateCliInput(
    executionId: executionId,
    candidateDirectory: Directory(values['--candidate-dir']!),
    candidateId: values['--candidate-id']!,
    expectedDigest: expectedDigest,
    sdkRef: values['--sdk-ref']!,
    fixtureUrl: fixtureUrl,
    deviceId: devices[targetOS]!,
    reportOut: reportOut,
  );
}

VerificationReleasedConsumerCliInput parseReleasedConsumerCliInput(
  List<String> arguments,
) {
  String? repoUrl;
  String? ref;
  final integrationArguments = <String>[];
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length) {
      throw VerificationCliUsageError(
        'Missing value for released-consumer argument ${arguments[index]}',
      );
    }
    final option = arguments[index];
    final value = arguments[index + 1].trim();
    switch (option) {
      case '--repo-url':
        repoUrl = value;
      case '--ref':
        ref = value;
      default:
        integrationArguments.addAll(<String>[option, value]);
    }
  }
  if (repoUrl == null || repoUrl.isEmpty || ref == null || ref.isEmpty) {
    throw const VerificationCliUsageError(
      'released-consumer requires --repo-url and --ref',
    );
  }
  return VerificationReleasedConsumerCliInput(
    integration: parseIntegrationCliInput(integrationArguments),
    repoUrl: repoUrl,
    ref: ref,
  );
}

String _candidateTargetOS(VerificationExecutionId executionId) {
  return switch (executionId.value) {
    'candidate-android' => 'android',
    'candidate-ios' => 'ios',
    'candidate-macos' => 'macos',
    'candidate-windows' => 'windows',
    _ => throw VerificationCliUsageError(
      'Unknown release-candidate execution: $executionId',
    ),
  };
}

Future<int> runVerificationCli(
  List<String> arguments, {
  required VerificationCliWriter writeStdout,
  required VerificationCliWriter writeStderr,
  String? workspaceRoot,
  VerificationCommandRunner? runCommand,
  VerificationExecutionCheckRunner? verifyAbi,
  VerificationExecutionCheckRunner? verifyDevelopmentPath,
  VerificationExecutionCheckRunner? verifyExternalConsumer,
  CandidateSetLoader? candidateSetLoader,
  VerifiedCandidateConsumer? verifyCandidateAbi,
  VerifiedCandidateConsumer? verifyCandidateRuntime,
}) async {
  final command = parseVerificationCliCommand(arguments);
  if (command.name == 'bootstrap') {
    if (command.arguments.isNotEmpty) {
      throw const VerificationCliUsageError('Usage: bootstrap');
    }
    await runWorkspaceBootstrap(workspaceRoot ?? Directory.current.path);
    return 0;
  }
  if (command.name == 'matrix') {
    if (command.arguments.length != 2 || command.arguments.first != '--suite') {
      throw const VerificationCliUsageError('Usage: matrix --suite <suite-id>');
    }
    final suiteId = _parseSuiteId(command.arguments.last);
    writeStdout(buildActionsMatrixJson(suiteId));
    return 0;
  }
  if (command.name == 'check') {
    if (command.arguments.isEmpty) {
      throw const VerificationCliUsageError(
        'Usage: check <check-id> --execution <execution-id>',
      );
    }
    final checkId = VerificationCheckId(command.arguments.first);
    final checkArguments = command.arguments.skip(1).toList(growable: false);
    final resolvedWorkspaceRoot = workspaceRoot ?? Directory.current.path;
    final resolvedRunCommand = _resolveCommandRunner(runCommand, writeStderr);
    final staticCatalog = VerificationCatalog(
      buildStaticChecks(
        workspaceRoot: resolvedWorkspaceRoot,
        inventory: WorkspaceInventory(resolvedWorkspaceRoot),
        runCommand: resolvedRunCommand,
      ),
    );
    if (staticCatalog.containsCheck(checkId)) {
      final (executionId, reportOut) = _parseExecutionAndReportOut(
        checkArguments,
        commandName: 'check ${checkId.value}',
      );
      if (reportOut != null) {
        throw const VerificationCliUsageError(
          'Atomic diagnostics do not write gate coverage reports',
        );
      }
      final plan = VerificationPlanner(
        staticCatalog,
      ).planCheck(checkId, executionId);
      await const VerificationExecutor().execute(plan);
      return 0;
    }

    final integrationIds = buildIntegrationChecks(
      workspaceRoot: resolvedWorkspaceRoot,
      executionRows: buildIntegrationExecutionRows(),
      runCommand: (_) async {},
      verifyAbi: (_) async {},
      verifyDevelopmentPath: (_) async {},
      verifyExternalConsumer: (_) async {},
    ).map((check) => check.id).toSet();
    if (integrationIds.contains(checkId)) {
      final input = parseIntegrationCliInput(checkArguments);
      if (input.reportOut != null) {
        throw const VerificationCliUsageError(
          'Atomic diagnostics do not write gate coverage reports',
        );
      }
      ExternalConsumerVerificationSession? externalSession;
      Future<void> runExternal(VerificationExecutionId executionId) async {
        final runner =
            verifyExternalConsumer ??
            (externalSession ??= await createExternalConsumerSession(
              workspaceRoot: resolvedWorkspaceRoot,
              fixtureUrl: input.fixtureUrl,
              deviceIds: input.deviceIds,
              runCommand: resolvedRunCommand,
            )).runner;
        await runner(executionId);
      }

      final catalog = VerificationCatalog(
        buildIntegrationChecks(
          workspaceRoot: resolvedWorkspaceRoot,
          executionRows: buildIntegrationExecutionRows(),
          runCommand: resolvedRunCommand,
          verifyAbi: verifyAbi ?? createNativeAbiRunner(resolvedWorkspaceRoot),
          verifyDevelopmentPath:
              verifyDevelopmentPath ??
              createDevelopmentPathRunner(
                resolvedWorkspaceRoot,
                resolvedRunCommand,
              ),
          verifyExternalConsumer: runExternal,
        ),
      );
      final plan = VerificationPlanner(
        catalog,
      ).planCheck(checkId, input.executionId);
      try {
        await const VerificationExecutor().execute(plan);
      } finally {
        await externalSession?.close();
      }
      return 0;
    }
    final candidateRows = buildReleaseCandidateExecutionRows();
    final candidateIds = buildCandidateChecks(
      executionRows: candidateRows,
      verifyCandidateSet: (_) async {},
      verifyCandidateAbi: (_) async {},
      verifyCandidateRuntime: (_) async {},
    ).map((check) => check.id).toSet();
    if (candidateIds.contains(checkId)) {
      final input = parseCandidateCliInput(checkArguments);
      if (input.reportOut != null) {
        throw const VerificationCliUsageError(
          'Atomic diagnostics do not write gate coverage reports',
        );
      }
      final runners = CandidateVerificationRunners(
        verifySet:
            candidateSetLoader ??
            () => verifyCandidateSet(
              input.candidateDirectory,
              candidateId: input.candidateId,
              expectedDigest: input.expectedDigest,
              sdkRef: input.sdkRef,
            ),
        verifyAbi:
            verifyCandidateAbi ??
            createCandidateAbiConsumer(resolvedWorkspaceRoot),
        verifyRuntime:
            verifyCandidateRuntime ??
            createCandidateRuntimeConsumer(
              workspaceRoot: resolvedWorkspaceRoot,
              fixtureUrl: input.fixtureUrl,
              deviceId: input.deviceId,
              runCommand: resolvedRunCommand,
            ),
      );
      final catalog = VerificationCatalog(
        buildCandidateChecks(
          executionRows: candidateRows,
          verifyCandidateSet: runners.verifySet,
          verifyCandidateAbi: runners.verifyAbi,
          verifyCandidateRuntime: runners.verifyRuntime,
        ),
      );
      final plan = VerificationPlanner(
        catalog,
      ).planCheck(checkId, input.executionId);
      await const VerificationExecutor().execute(plan);
      return 0;
    }
    if (checkId.value == 'released-consumer') {
      final input = parseReleasedConsumerCliInput(checkArguments);
      if (input.integration.reportOut != null) {
        throw const VerificationCliUsageError(
          'Atomic diagnostics do not write gate coverage reports',
        );
      }
      final catalog = VerificationCatalog(<VerificationCheckDefinition>[
        releasedConsumerCheck(
          executionRows: buildIntegrationExecutionRows(),
          runCheck: createReleasedConsumerRunner(
            repoUrl: input.repoUrl,
            ref: input.ref,
            fixtureUrl: input.integration.fixtureUrl,
            deviceIds: input.integration.deviceIds,
            runCommand: resolvedRunCommand,
          ),
        ),
      ]);
      final plan = VerificationPlanner(
        catalog,
      ).planCheck(checkId, input.integration.executionId);
      await const VerificationExecutor().execute(plan);
      return 0;
    }
    throw VerificationCliUsageError('Unknown diagnostic check: $checkId');
  }
  if (command.name == 'verify-static') {
    if (command.arguments.length == 2 &&
        command.arguments.first == '--aggregate-reports') {
      final catalog = VerificationCatalog(
        buildStaticChecks(
          workspaceRoot: workspaceRoot ?? Directory.current.path,
          inventory: WorkspaceInventory(
            workspaceRoot ?? Directory.current.path,
          ),
          runCommand: (_) async {},
        ),
      );
      verifyAggregateCoverage(
        suiteId: VerificationSuiteId.verifyStatic,
        expectedExecutionIds: const <VerificationExecutionId>[
          VerificationExecutionId('static-linux'),
        ],
        expectedCheckIds: catalog
            .checksForSuite(VerificationSuiteId.verifyStatic)
            .map((check) => check.id)
            .toList(growable: false),
        reports: await _readCoverageReports(Directory(command.arguments.last)),
      );
      return 0;
    }
    final (executionId, reportOut) = _parseExecutionAndReportOut(
      command.arguments,
      commandName: command.name,
    );
    final resolvedWorkspaceRoot = workspaceRoot ?? Directory.current.path;
    final resolvedRunCommand = _resolveCommandRunner(runCommand, writeStderr);
    final catalog = VerificationCatalog(
      buildStaticChecks(
        workspaceRoot: resolvedWorkspaceRoot,
        inventory: WorkspaceInventory(resolvedWorkspaceRoot),
        runCommand: resolvedRunCommand,
      ),
    );
    final plan = VerificationPlanner(
      catalog,
    ).planSuite(VerificationSuiteId.verifyStatic, executionId);
    final result = await const VerificationExecutor().execute(plan);
    await _writeCoverageReport(
      reportOut,
      VerificationCoverageReport(
        suiteId: VerificationSuiteId.verifyStatic,
        executionId: executionId,
        plannedCheckIds: plan.nodes
            .map((node) => node.check.id)
            .toList(growable: false),
        completedCheckIds: result.completedCheckIds,
        status: VerificationCoverageStatus.passed,
      ),
    );
    return 0;
  }
  if (command.name == 'verify-integration') {
    if (command.arguments.length == 2 &&
        command.arguments.first == '--aggregate-reports') {
      final executionRows = buildIntegrationExecutionRows();
      final catalog = VerificationCatalog(
        buildIntegrationChecks(
          workspaceRoot: workspaceRoot ?? Directory.current.path,
          executionRows: executionRows,
          runCommand: (_) async {},
          verifyAbi: (_) async {},
          verifyDevelopmentPath: (_) async {},
          verifyExternalConsumer: (_) async {},
        ),
      );
      verifyAggregateCoverage(
        suiteId: VerificationSuiteId.verifyIntegration,
        expectedExecutionIds: executionRows
            .map((row) => row.executionId)
            .toList(growable: false),
        expectedCheckIds: catalog
            .checksForSuite(VerificationSuiteId.verifyIntegration)
            .map((check) => check.id)
            .toList(growable: false),
        reports: await _readCoverageReports(Directory(command.arguments.last)),
      );
      return 0;
    }
    final input = parseIntegrationCliInput(command.arguments);
    final resolvedWorkspaceRoot = workspaceRoot ?? Directory.current.path;
    final executionRows = buildIntegrationExecutionRows();
    final resolvedRunCommand = _resolveCommandRunner(runCommand, writeStderr);
    ExternalConsumerVerificationSession? externalSession;
    final resolvedExternalConsumer =
        verifyExternalConsumer ??
        (externalSession = await createExternalConsumerSession(
          workspaceRoot: resolvedWorkspaceRoot,
          fixtureUrl: input.fixtureUrl,
          deviceIds: input.deviceIds,
          runCommand: resolvedRunCommand,
        )).runner;
    final catalog = VerificationCatalog(
      buildIntegrationChecks(
        workspaceRoot: resolvedWorkspaceRoot,
        executionRows: executionRows,
        runCommand: resolvedRunCommand,
        verifyAbi: verifyAbi ?? createNativeAbiRunner(resolvedWorkspaceRoot),
        verifyDevelopmentPath:
            verifyDevelopmentPath ??
            createDevelopmentPathRunner(
              resolvedWorkspaceRoot,
              resolvedRunCommand,
            ),
        verifyExternalConsumer: resolvedExternalConsumer,
      ),
    );
    final plan = VerificationPlanner(
      catalog,
    ).planSuite(VerificationSuiteId.verifyIntegration, input.executionId);
    try {
      final result = await const VerificationExecutor().execute(plan);
      await _writeCoverageReport(
        input.reportOut,
        VerificationCoverageReport(
          suiteId: VerificationSuiteId.verifyIntegration,
          executionId: input.executionId,
          plannedCheckIds: plan.nodes
              .map((node) => node.check.id)
              .toList(growable: false),
          completedCheckIds: result.completedCheckIds,
          status: VerificationCoverageStatus.passed,
        ),
      );
    } finally {
      await externalSession?.close();
    }
    return 0;
  }
  if (command.name == 'verify-release-candidate') {
    if (command.arguments.length == 2 &&
        command.arguments.first == '--aggregate-reports') {
      final executionRows = buildReleaseCandidateExecutionRows();
      final catalog = VerificationCatalog(
        buildCandidateChecks(
          executionRows: executionRows,
          verifyCandidateSet: (_) async {},
          verifyCandidateAbi: (_) async {},
          verifyCandidateRuntime: (_) async {},
        ),
      );
      verifyAggregateCoverage(
        suiteId: VerificationSuiteId.verifyReleaseCandidate,
        expectedExecutionIds: executionRows
            .map((row) => row.executionId)
            .toList(growable: false),
        expectedCheckIds: catalog
            .checksForSuite(VerificationSuiteId.verifyReleaseCandidate)
            .map((check) => check.id)
            .toList(growable: false),
        reports: await _readCoverageReports(Directory(command.arguments.last)),
      );
      return 0;
    }
    final input = parseCandidateCliInput(command.arguments);
    final resolvedWorkspaceRoot = workspaceRoot ?? Directory.current.path;
    final resolvedRunCommand = _resolveCommandRunner(runCommand, writeStderr);
    final runners = CandidateVerificationRunners(
      verifySet:
          candidateSetLoader ??
          () => verifyCandidateSet(
            input.candidateDirectory,
            candidateId: input.candidateId,
            expectedDigest: input.expectedDigest,
            sdkRef: input.sdkRef,
          ),
      verifyAbi:
          verifyCandidateAbi ??
          createCandidateAbiConsumer(resolvedWorkspaceRoot),
      verifyRuntime:
          verifyCandidateRuntime ??
          createCandidateRuntimeConsumer(
            workspaceRoot: resolvedWorkspaceRoot,
            fixtureUrl: input.fixtureUrl,
            deviceId: input.deviceId,
            runCommand: resolvedRunCommand,
          ),
    );
    final catalog = VerificationCatalog(
      buildCandidateChecks(
        executionRows: buildReleaseCandidateExecutionRows(),
        verifyCandidateSet: runners.verifySet,
        verifyCandidateAbi: runners.verifyAbi,
        verifyCandidateRuntime: runners.verifyRuntime,
      ),
    );
    final plan = VerificationPlanner(
      catalog,
    ).planSuite(VerificationSuiteId.verifyReleaseCandidate, input.executionId);
    final result = await const VerificationExecutor().execute(plan);
    await _writeCoverageReport(
      input.reportOut,
      VerificationCoverageReport(
        suiteId: VerificationSuiteId.verifyReleaseCandidate,
        executionId: input.executionId,
        plannedCheckIds: plan.nodes
            .map((node) => node.check.id)
            .toList(growable: false),
        completedCheckIds: result.completedCheckIds,
        status: VerificationCoverageStatus.passed,
      ),
    );
    return 0;
  }
  throw VerificationCliUsageError(
    'Workspace command is not implemented yet: ${command.name}',
  );
}

(VerificationExecutionId, File?) _parseExecutionAndReportOut(
  List<String> arguments, {
  required String commandName,
}) {
  String? executionValue;
  File? reportOut;
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length) {
      throw VerificationCliUsageError(
        'Missing value for $commandName argument ${arguments[index]}',
      );
    }
    switch (arguments[index]) {
      case '--execution':
        executionValue = arguments[index + 1].trim();
      case '--report-out':
        reportOut = File(arguments[index + 1]);
      default:
        throw VerificationCliUsageError(
          'Unknown $commandName argument: ${arguments[index]}',
        );
    }
  }
  if (executionValue == null || executionValue.isEmpty) {
    throw VerificationCliUsageError(
      '$commandName requires --execution <execution-id>',
    );
  }
  return (VerificationExecutionId(executionValue), reportOut);
}

Future<void> _writeCoverageReport(
  File? outputFile,
  VerificationCoverageReport report,
) async {
  if (outputFile == null) {
    return;
  }
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString('${jsonEncode(report.toJson())}\n');
}

Future<List<VerificationCoverageReport>> _readCoverageReports(
  Directory directory,
) async {
  if (!directory.existsSync()) {
    throw StateError(
      'Coverage report directory does not exist: ${directory.path}',
    );
  }
  final files =
      directory
          .listSync(followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));
  if (files.isEmpty) {
    throw StateError('Coverage report directory is empty: ${directory.path}');
  }
  return <VerificationCoverageReport>[
    for (final file in files)
      VerificationCoverageReport.fromJson(
        (jsonDecode(await file.readAsString()) as Map).cast<String, Object?>(),
      ),
  ];
}

VerificationCommandRunner _resolveCommandRunner(
  VerificationCommandRunner? runCommand,
  VerificationCliWriter writeStderr,
) {
  return runCommand ??
      (verificationCommand) => runVerificationCommand(
        verificationCommand,
        onStdoutLine: writeStderr,
        onStderrLine: writeStderr,
      );
}

VerificationSuiteId _parseSuiteId(String value) {
  for (final suiteId in supportedVerificationSuiteIds) {
    if (suiteId.value == value) {
      return suiteId;
    }
  }
  throw VerificationCliUsageError('Unknown verification suite: $value');
}
