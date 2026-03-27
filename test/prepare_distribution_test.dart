import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../scripts/prepare_distribution.dart';

void main() {
  test('runs matching build scripts before materializing selected carrier packages', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'rust_net_prepare_distribution_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final invokedScripts = <String>[];
    var materialized = false;

    await prepareDistributionWorkspace(
      workspaceRoot: tempDir.path,
      outputDirectory: p.join(tempDir.path, '.dist', 'workspace'),
      requestedPackages: {
        'rust_net',
        'rust_net_native_android',
        'rust_net_native_macos',
      },
      runBuildScript: (scriptPath, profile) async {
        invokedScripts.add('${p.basename(scriptPath)}:$profile');
      },
      materializeWorkspace: ({
        required String workspaceRoot,
        required String outputDirectory,
        Set<String>? requestedPackages,
      }) async {
        materialized = true;
        expect(requestedPackages, {
          'rust_net',
          'rust_net_native_android',
          'rust_net_native_macos',
        });
      },
    );

    expect(materialized, isTrue);
    expect(
      invokedScripts,
      <String>[
        'build_native_android.sh:release',
        'build_native_macos.sh:release',
      ],
    );
  });

  test('runs the linux build script when the linux carrier package is selected', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'rust_net_prepare_distribution_linux_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final invokedScripts = <String>[];

    await prepareDistributionWorkspace(
      workspaceRoot: tempDir.path,
      outputDirectory: p.join(tempDir.path, '.dist', 'workspace'),
      requestedPackages: {'rust_net_native_linux'},
      runBuildScript: (scriptPath, profile) async {
        invokedScripts.add('${p.basename(scriptPath)}:$profile');
      },
      materializeWorkspace: ({
        required String workspaceRoot,
        required String outputDirectory,
        Set<String>? requestedPackages,
      }) async {},
    );

    expect(
      invokedScripts,
      <String>['build_native_linux.sh:release'],
    );
  });

  test('skips build scripts when skipBuild is enabled', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'rust_net_prepare_distribution_skip_',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    var buildCalled = false;
    var materialized = false;

    await prepareDistributionWorkspace(
      workspaceRoot: tempDir.path,
      outputDirectory: p.join(tempDir.path, '.dist', 'workspace'),
      requestedPackages: {'rust_net_native_windows'},
      skipBuild: true,
      runBuildScript: (scriptPath, profile) async {
        buildCalled = true;
      },
      materializeWorkspace: ({
        required String workspaceRoot,
        required String outputDirectory,
        Set<String>? requestedPackages,
      }) async {
        materialized = true;
      },
    );

    expect(buildCalled, isFalse);
    expect(materialized, isTrue);
  });
}
