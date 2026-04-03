import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('carrier packages import the dedicated native runtime package',
      () async {
    final packageRoot = Directory.current.parent.path;
    final pluginFiles = <String>[
      p.join(
        packageRoot,
        'nexa_http_native_android',
        'lib',
        'src',
        'nexa_http_native_android_plugin.dart',
      ),
      p.join(
        packageRoot,
        'nexa_http_native_ios',
        'lib',
        'src',
        'nexa_http_native_ios_plugin.dart',
      ),
      p.join(
        packageRoot,
        'nexa_http_native_macos',
        'lib',
        'src',
        'nexa_http_native_macos_plugin.dart',
      ),
      p.join(
        packageRoot,
        'nexa_http_native_windows',
        'lib',
        'src',
        'nexa_http_native_windows_plugin.dart',
      ),
    ];

    for (final filePath in pluginFiles) {
      final contents = await File(filePath).readAsString();
      expect(
        contents,
        contains("package:nexa_http_runtime/nexa_http_runtime.dart"),
      );
      expect(
        contents,
        isNot(contains("package:nexa_http/nexa_http_native_runtime.dart")),
      );
    }
  });

  test('carrier packages do not embed generic packaged or workspace discovery',
      () async {
    final packageRoot = Directory.current.parent.path;
    final pluginFiles = <String>[
      p.join(
        packageRoot,
        'nexa_http_native_macos',
        'lib',
        'src',
        'nexa_http_native_macos_plugin.dart',
      ),
      p.join(
        packageRoot,
        'nexa_http_native_windows',
        'lib',
        'src',
        'nexa_http_native_windows_plugin.dart',
      ),
    ];

    for (final filePath in pluginFiles) {
      final contents = await File(filePath).readAsString();
      expect(contents, isNot(contains('walkUpDynamicLibraryCandidates')));
      expect(contents, isNot(contains('windows/Libraries')));
      expect(contents, isNot(contains('macos/Libraries')));
      expect(contents, isNot(contains(r"'target'")));
      expect(contents, isNot(contains(r'"target"')));
    }
  });

  test('carrier build hooks resolve artifact mode explicitly', () async {
    final packageRoot = Directory.current.parent.path;
    final hookFiles = <String>[
      p.join(packageRoot, 'nexa_http_native_android', 'hook', 'build.dart'),
      p.join(packageRoot, 'nexa_http_native_ios', 'hook', 'build.dart'),
      p.join(packageRoot, 'nexa_http_native_macos', 'hook', 'build.dart'),
      p.join(packageRoot, 'nexa_http_native_windows', 'hook', 'build.dart'),
    ];

    for (final filePath in hookFiles) {
      final contents = await File(filePath).readAsString();
      expect(
        contents,
        contains('final mode = resolveNexaHttpNativeArtifactResolutionMode('),
      );
      expect(
        contents,
        contains('defaultMode: defaultNexaHttpNativeArtifactResolutionMode('),
      );
      expect(contents, contains('mode: mode'));
    }
  });

  test('macOS hook avoids universal-binary assembly from workspace outputs',
      () async {
    final packageRoot = Directory.current.parent.path;
    final contents = await File(
      p.join(packageRoot, 'nexa_http_native_macos', 'hook', 'build.dart'),
    ).readAsString();

    expect(
      contents,
      contains('packagedRelativePath: target.packagedRelativePath'),
    );
    expect(contents, isNot(contains('lipo')));
    expect(contents, isNot(contains('universal')));
  });
}
