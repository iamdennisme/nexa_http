import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('CI consumes Catalog matrices and complete suites only', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();

    expect(workflow, contains('matrix --suite verify-static'));
    expect(workflow, contains('matrix --suite verify-integration'));
    expect(workflow, matches(RegExp(r'verify-static\s+--execution')));
    expect(workflow, matches(RegExp(r'verify-integration\s+--execution')));
    expect(workflow, contains('verify-static --aggregate-reports'));
    expect(workflow, contains('verify-integration --aggregate-reports'));
    expect(workflow, contains('scripts/wait_android_package_service.sh'));
    expect(workflow, contains('target: aosp_atd'));
    expect(workflow, contains('pre-emulator-launch-script:'));
    expect(
      workflow,
      matches(RegExp(r'check native-build\s+--execution android-linux')),
    );
    expect(workflow, isNot(contains('dart test')));
    expect(workflow, isNot(contains('cargo test')));
    expect(workflow, isNot(contains('build_native_')));
    expect(workflow, isNot(contains('verify-native-abi')));
    expect(workflow, isNot(contains('verify-artifact-consistency')));
    expect(workflow, isNot(contains('continue-on-error')));
  });

  test('release workflow has one explicit transaction entry surface', () {
    final file = File('.github/workflows/release-native-assets.yml');

    expect(file.existsSync(), isTrue);
    final workflow = file.readAsStringSync();
    expect(_workflowEventNames(workflow), <String>{
      'pull_request',
      'workflow_dispatch',
    });
    expect(_workflowDispatchInputNames(workflow), <String>{
      'version',
      'commit_sha',
      'publish',
    });
    expect(workflow, contains('pull_request:'));
    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('version:'));
    expect(workflow, contains('commit_sha:'));
    expect(workflow, contains('publish:'));
    expect(workflow, isNot(matches(RegExp(r'^\s+tags:', multiLine: true))));
    expect(workflow, isNot(contains('workflow_run:')));
    expect(workflow, isNot(matches(RegExp(r'^\s+release:', multiLine: true))));
  });

  test(
    'dispatch inputs enter shell only through quoted environment values',
    () {
      final transactionInput = _jobBlock(
        File('.github/workflows/release-native-assets.yml').readAsStringSync(),
        'transaction-input',
      );

      expect(transactionInput, contains('RELEASE_VERSION_INPUT:'));
      expect(transactionInput, contains('RELEASE_COMMIT_INPUT:'));
      expect(transactionInput, contains(r'--version "$RELEASE_VERSION_INPUT"'));
      expect(
        transactionInput,
        contains(r'--commit-sha "$RELEASE_COMMIT_INPUT"'),
      );
      expect(
        transactionInput,
        isNot(contains('--version "\${{ inputs.version }}"')),
      );
      expect(
        transactionInput,
        isNot(contains('--commit-sha "\${{ inputs.commit_sha }}"')),
      );
    },
  );

  test('only the explicitly authorized publisher can write contents', () {
    final workflow = File(
      '.github/workflows/release-native-assets.yml',
    ).readAsStringSync();
    final publisher = _jobBlock(workflow, 'publisher');

    expect(RegExp(r'contents:\s*write').allMatches(workflow), hasLength(1));
    expect(publisher, contains('contents: write'));
    expect(publisher, contains('- aggregate-candidate'));
    expect(
      publisher,
      contains(
        "github.event_name == 'workflow_dispatch' && inputs.publish == true",
      ),
    );
  });

  test('release builds and gates are projected from Catalog matrices', () {
    final workflow = File(
      '.github/workflows/release-native-assets.yml',
    ).readAsStringSync();
    final transactionInput = _jobBlock(workflow, 'transaction-input');
    final buildFragment = _jobBlock(workflow, 'build-fragment');
    final verifyCandidate = _jobBlock(workflow, 'verify-candidate');

    expect(transactionInput, contains('matrix --suite verify-integration'));
    expect(
      transactionInput,
      contains('matrix --suite verify-release-candidate'),
    );
    expect(buildFragment, contains('fromJSON(needs.transaction-input'));
    expect(buildFragment, contains('build-fragment'));
    expect(verifyCandidate, contains('fromJSON(needs.transaction-input'));
    expect(verifyCandidate, contains('verify-release-candidate'));
    expect(workflow, isNot(contains('build_native_')));
    expect(
      workflow,
      isNot(matches(RegExp(r'(aarch64|x86_64|armv7)-[a-z0-9_-]+'))),
    );
    expect(workflow, isNot(contains('nexa_http-native-')));
  });

  test(
    'one assembled candidate artifact flows unchanged through every gate',
    () {
      final workflow = File(
        '.github/workflows/release-native-assets.yml',
      ).readAsStringSync();
      final assembly = _jobBlock(workflow, 'assemble-candidate');
      final verification = _jobBlock(workflow, 'verify-candidate');

      expect(assembly, contains('needs:'));
      expect(assembly, contains('build-fragment'));
      expect(assembly, contains('merge-multiple: true'));
      expect(assembly, contains('release_transaction.dart assemble'));
      expect(assembly, contains('artifact_id:'));
      expect(assembly, contains('candidate_digest:'));
      expect(verification, contains('artifact-ids:'));
      expect(
        verification,
        contains('needs.assemble-candidate.outputs.artifact_id'),
      );
      for (final option in <String>[
        '--candidate-dir',
        '--candidate-id',
        '--candidate-digest',
        '--sdk-ref',
        '--fixture-url',
        '--device',
        '--report-out',
      ]) {
        expect(verification, contains(option));
        expect(option.allMatches(verification), hasLength(4));
      }
      expect(
        'actions/download-artifact@v4'.allMatches(verification),
        hasLength(1),
      );
      expect(
        'actions/upload-artifact@v4'.allMatches(verification),
        hasLength(1),
      );
      expect(
        verification,
        isNot(contains('release_transaction.dart build-fragment')),
      );
      expect(
        verification,
        isNot(contains('release_transaction.dart assemble')),
      );
    },
  );

  test('aggregate is a blocking report-only gate over all candidate rows', () {
    final workflow = File(
      '.github/workflows/release-native-assets.yml',
    ).readAsStringSync();
    final aggregate = _jobBlock(workflow, 'aggregate-candidate');

    for (final dependency in <String>[
      'transaction-input',
      'assemble-candidate',
      'verify-candidate',
    ]) {
      expect(aggregate, contains('- $dependency'));
    }
    expect(aggregate, contains('pattern: release-candidate-report-*'));
    expect(aggregate, contains('merge-multiple: true'));
    expect(
      aggregate,
      matches(RegExp(r'verify-release-candidate\s+--aggregate-reports')),
    );
    expect(aggregate, isNot(contains('artifact-ids:')));
    expect(aggregate, isNot(contains('release_transaction.dart assemble')));
    expect(
      aggregate,
      isNot(contains('release_transaction.dart build-fragment')),
    );
  });

  test(
    'publisher only promotes the exact artifact after aggregate success',
    () {
      final workflow = File(
        '.github/workflows/release-native-assets.yml',
      ).readAsStringSync();
      final publisher = _jobBlock(workflow, 'publisher');

      for (final dependency in <String>[
        'transaction-input',
        'assemble-candidate',
        'aggregate-candidate',
      ]) {
        expect(publisher, contains('- $dependency'));
      }
      expect(
        publisher,
        contains(
          "if: \${{ github.event_name == 'workflow_dispatch' && "
          "inputs.publish == true && "
          "needs.aggregate-candidate.result == 'success' }}",
        ),
      );
      expect(publisher, contains('artifact-ids:'));
      expect(
        publisher,
        contains('needs.assemble-candidate.outputs.artifact_id'),
      );
      expect(publisher, contains('release_transaction.dart publish'));
      for (final option in <String>[
        '--workspace-root',
        '--repository',
        '--version',
        '--commit-sha',
        '--candidate-dir',
        '--candidate-id',
        '--candidate-digest',
      ]) {
        expect(publisher, contains(option));
      }
      for (final forbidden in <String>[
        'cargo ',
        'build_native_',
        'build-fragment',
        'release_transaction.dart assemble',
        'manifest.json',
        'SHA256SUMS',
        ' mv ',
        ' cp ',
        'rsync ',
        'Rename-Item',
      ]) {
        expect(publisher, isNot(contains(forbidden)));
      }
    },
  );

  test('release authority has no workflow or failure-policy bypass', () {
    final releaseWorkflow = File(
      '.github/workflows/release-native-assets.yml',
    ).readAsStringSync();

    expect(_workflowJobNames(releaseWorkflow), <String>{
      'transaction-input',
      'build-fragment',
      'assemble-candidate',
      'verify-candidate',
      'aggregate-candidate',
      'publisher',
    });
    expect(_jobNeeds(releaseWorkflow, 'build-fragment'), <String>{
      'transaction-input',
    });
    expect(_jobNeeds(releaseWorkflow, 'assemble-candidate'), <String>{
      'transaction-input',
      'build-fragment',
    });
    expect(_jobNeeds(releaseWorkflow, 'verify-candidate'), <String>{
      'transaction-input',
      'assemble-candidate',
    });
    expect(_jobNeeds(releaseWorkflow, 'aggregate-candidate'), <String>{
      'transaction-input',
      'assemble-candidate',
      'verify-candidate',
    });
    expect(_jobNeeds(releaseWorkflow, 'publisher'), <String>{
      'transaction-input',
      'assemble-candidate',
      'aggregate-candidate',
    });
    final assembly = _jobBlock(releaseWorkflow, 'assemble-candidate');
    final verification = _jobBlock(releaseWorkflow, 'verify-candidate');
    final publisher = _jobBlock(releaseWorkflow, 'publisher');
    expect('actions/download-artifact@v4'.allMatches(assembly), hasLength(1));
    expect('actions/upload-artifact@v4'.allMatches(assembly), hasLength(1));
    expect(
      'actions/download-artifact@v4'.allMatches(verification),
      hasLength(1),
    );
    expect('actions/upload-artifact@v4'.allMatches(verification), hasLength(1));
    expect('actions/download-artifact@v4'.allMatches(publisher), hasLength(1));
    expect('actions/upload-artifact@v4'.allMatches(publisher), isEmpty);
    expect(releaseWorkflow, isNot(contains('continue-on-error')));
    expect(releaseWorkflow, isNot(contains('allow-failure')));
    expect(releaseWorkflow, isNot(contains('fail-fast: true')));
    expect(File('scripts/tag_release_validation.sh').existsSync(), isFalse);

    final workflows = Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(workflows, isNot(matches(RegExp(r'^\s+tags:', multiLine: true))));
    expect(workflows, isNot(contains('workflow_run:')));
    expect(workflows, isNot(matches(RegExp(r'^\s+release:', multiLine: true))));
    expect(RegExp(r'contents:\s*write').allMatches(workflows), hasLength(1));
    for (final jobName in <String>[
      'transaction-input',
      'build-fragment',
      'assemble-candidate',
      'verify-candidate',
      'aggregate-candidate',
    ]) {
      final job = _jobBlock(releaseWorkflow, jobName);
      expect(job, isNot(contains('gh release')));
      expect(job, isNot(contains('git tag')));
      expect(job, isNot(contains('git push')));
    }
  });
}

Set<String> _workflowEventNames(String workflow) {
  final onBlock = workflow.substring(
    workflow.indexOf('\non:\n') + 5,
    workflow.indexOf('\npermissions:\n'),
  );
  return <String>{
    for (final line in onBlock.split('\n'))
      if (line.startsWith('  ') &&
          !line.startsWith('   ') &&
          line.endsWith(':'))
        line.trim().substring(0, line.trim().length - 1),
  };
}

Set<String> _workflowDispatchInputNames(String workflow) {
  final onBlock = workflow.substring(
    workflow.indexOf('\non:\n') + 5,
    workflow.indexOf('\npermissions:\n'),
  );
  return <String>{
    for (final line in onBlock.split('\n'))
      if (line.startsWith('      ') &&
          !line.startsWith('       ') &&
          line.endsWith(':'))
        line.trim().substring(0, line.trim().length - 1),
  };
}

Set<String> _workflowJobNames(String workflow) {
  final jobs = workflow.substring(workflow.indexOf('\njobs:\n') + 7);
  return <String>{
    for (final line in jobs.split('\n'))
      if (line.startsWith('  ') &&
          !line.startsWith('   ') &&
          line.endsWith(':'))
        line.trim().substring(0, line.trim().length - 1),
  };
}

Set<String> _jobNeeds(String workflow, String jobName) {
  final job = _jobBlock(workflow, jobName);
  final lines = job.split('\n');
  final needsIndex = lines.indexWhere((line) => line.startsWith('    needs:'));
  if (needsIndex < 0) {
    return const <String>{};
  }
  final scalar = lines[needsIndex].substring('    needs:'.length).trim();
  if (scalar.isNotEmpty) {
    return <String>{scalar};
  }
  final dependencies = <String>{};
  for (var index = needsIndex + 1; index < lines.length; index++) {
    if (lines[index].startsWith('      - ')) {
      dependencies.add(lines[index].substring('      - '.length).trim());
      continue;
    }
    if (!lines[index].startsWith('      ')) {
      break;
    }
  }
  return dependencies;
}

String _jobBlock(String workflow, String jobName) {
  final lines = workflow.split('\n');
  final start = lines.indexOf('  $jobName:');
  if (start < 0) {
    throw StateError('Workflow job not found: $jobName');
  }
  var end = lines.length;
  for (var index = start + 1; index < lines.length; index++) {
    final line = lines[index];
    if (line.startsWith('  ') &&
        !line.startsWith('   ') &&
        line.endsWith(':')) {
      end = index;
      break;
    }
  }
  return lines.sublist(start, end).join('\n');
}
