import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'Trellis discovers every real package owner without a default',
    () async {
      final result = await Process.run('python3', <String>[
        '.trellis/scripts/get_context.py',
        '--mode',
        'packages',
        '--json',
      ]);

      expect(result.exitCode, 0, reason: '${result.stderr}');

      final discovery = jsonDecode('${result.stdout}') as Map<String, dynamic>;
      final discoveredPackages = (discovery['packages'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final packages = discoveredPackages
          .map(
            (package) => <String, Object?>{
              'name': package['name'],
              'path': package['path'],
              'specLayers': package['specLayers'],
              'default': package['default'],
            },
          )
          .toList();

      for (final package in discoveredPackages) {
        final name = package['name'] as String;
        final path = package['path'] as String;
        expect(Directory(path).existsSync(), isTrue, reason: '$name -> $path');
        for (final layer
            in (package['specLayers'] as List<dynamic>).cast<String>()) {
          final index = '.trellis/spec/$name/$layer/index.md';
          expect(File(index).existsSync(), isTrue, reason: index);
        }
      }

      expect(discovery['defaultPackage'], isNull);
      expect(packages, <Map<String, Object?>>[
        <String, Object?>{
          'name': 'nexa_http_workspace',
          'path': '.',
          'specLayers': <String>['tooling'],
          'default': false,
        },
        <String, Object?>{
          'name': 'nexa_http',
          'path': 'packages/nexa_http',
          'specLayers': <String>['dart'],
          'default': false,
        },
        <String, Object?>{
          'name': 'nexa_http_native_internal',
          'path': 'packages/nexa_http_native_internal',
          'specLayers': <String>['dart'],
          'default': false,
        },
        <String, Object?>{
          'name': 'nexa_http_native_android',
          'path': 'packages/nexa_http_native_android',
          'specLayers': <String>['flutter'],
          'default': false,
        },
        <String, Object?>{
          'name': 'nexa_http_native_ios',
          'path': 'packages/nexa_http_native_ios',
          'specLayers': <String>['flutter'],
          'default': false,
        },
        <String, Object?>{
          'name': 'nexa_http_native_macos',
          'path': 'packages/nexa_http_native_macos',
          'specLayers': <String>['flutter'],
          'default': false,
        },
        <String, Object?>{
          'name': 'nexa_http_native_windows',
          'path': 'packages/nexa_http_native_windows',
          'specLayers': <String>['flutter'],
          'default': false,
        },
        <String, Object?>{
          'name': 'nexa_http_native_core',
          'path': 'native/nexa_http_native_core',
          'specLayers': <String>['rust'],
          'default': false,
        },
        <String, Object?>{
          'name': 'nexa_http_native_apple_proxy',
          'path': 'native/nexa_http_native_apple_proxy',
          'specLayers': <String>['rust'],
          'default': false,
        },
        <String, Object?>{
          'name': 'nexa_http_native_android_ffi',
          'path':
              'packages/nexa_http_native_android/native/'
              'nexa_http_native_android_ffi',
          'specLayers': <String>['rust'],
          'default': false,
        },
        <String, Object?>{
          'name': 'nexa_http_native_ios_ffi',
          'path':
              'packages/nexa_http_native_ios/native/nexa_http_native_ios_ffi',
          'specLayers': <String>['rust'],
          'default': false,
        },
        <String, Object?>{
          'name': 'nexa_http_native_macos_ffi',
          'path':
              'packages/nexa_http_native_macos/native/'
              'nexa_http_native_macos_ffi',
          'specLayers': <String>['rust'],
          'default': false,
        },
        <String, Object?>{
          'name': 'nexa_http_native_windows_ffi',
          'path':
              'packages/nexa_http_native_windows/native/'
              'nexa_http_native_windows_ffi',
          'specLayers': <String>['rust'],
          'default': false,
        },
      ]);
    },
  );

  test('Rust specs have one current layer and no thin template files', () async {
    final specFiles = Directory('.trellis/spec')
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path)
        .toList();
    final thinSpecs = specFiles
        .where(
          (path) => const <String>{
            'database-guidelines.md',
            'logging-guidelines.md',
          }.contains(p.basename(path)),
        )
        .toList();

    expect(thinSpecs, isEmpty, reason: 'Rules must live with their real owner');

    final projectRustBackendPath = RegExp(
      r'nexa_http_native_(?:core|apple_proxy|android_ffi|ios_ffi|macos_ffi|windows_ffi)/backend/',
    );
    final oldPathReferences = <String>[];
    for (final file in await _repositoryTextFiles()) {
      final contents = await file.readAsString();
      if (projectRustBackendPath.hasMatch(contents)) {
        oldPathReferences.add(file.path);
      }
    }

    expect(
      oldPathReferences,
      isEmpty,
      reason: 'Every live and historical project path must use the rust layer',
    );
  });

  test('Every package route has a complete navigable spec', () {
    const requiredSpecFiles = <String>{
      '.trellis/spec/nexa_http_workspace/tooling/index.md',
      '.trellis/spec/nexa_http_workspace/tooling/verification-and-release.md',
      '.trellis/spec/nexa_http/dart/index.md',
      '.trellis/spec/nexa_http/dart/public-api.md',
      '.trellis/spec/nexa_http/dart/native-transport.md',
      '.trellis/spec/nexa_http_native_internal/dart/index.md',
      '.trellis/spec/nexa_http_native_internal/dart/artifact-lifecycle.md',
      '.trellis/spec/nexa_http_native_internal/dart/bindings-registry.md',
      '.trellis/spec/nexa_http_native_android/flutter/index.md',
      '.trellis/spec/nexa_http_native_ios/flutter/index.md',
      '.trellis/spec/nexa_http_native_macos/flutter/index.md',
      '.trellis/spec/nexa_http_native_windows/flutter/index.md',
    };
    final missingSpecs = requiredSpecFiles
        .where((path) => !File(path).existsSync())
        .toList();

    expect(missingSpecs, isEmpty);

    final brokenIndexLinks = <String>[];
    final indexes = Directory('.trellis/spec')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => p.basename(file.path) == 'index.md');
    final markdownLink = RegExp(r'\[[^\]]+\]\(([^)]+)\)');
    for (final index in indexes) {
      for (final match in markdownLink.allMatches(index.readAsStringSync())) {
        final target = match.group(1)!;
        if (target.startsWith('#') || target.contains('://')) {
          continue;
        }
        final path = p.normalize(
          p.join(p.dirname(index.path), target.split('#').first),
        );
        if (!File(path).existsSync() && !Directory(path).existsSync()) {
          brokenIndexLinks.add('${index.path} -> $target');
        }
      }
    }

    expect(brokenIndexLinks, isEmpty);
  });

  test('Architecture authority is current and discoverable', () {
    final architecture = File('docs/architecture.md');
    expect(architecture.existsSync(), isTrue);
    final architectureSource = architecture.readAsStringSync();

    for (final entrypoint in <String>[
      'README.md',
      'README.zh-CN.md',
      'CONTEXT-MAP.md',
      '.trellis/spec/guides/index.md',
    ]) {
      expect(
        File(entrypoint).readAsStringSync(),
        contains('architecture.md'),
        reason: '$entrypoint must link to the architecture index',
      );
    }

    for (var number = 1; number <= 10; number++) {
      final id = 'ADR-${number.toString().padLeft(4, '0')}';
      expect(architectureSource, contains(id));
      final adr = Directory('docs/adr')
          .listSync()
          .whereType<File>()
          .singleWhere(
            (file) => p.basename(file.path).startsWith(id.substring(4)),
          );
      final adrSource = adr.readAsStringSync();
      expect(adrSource, contains('## 当前来源'), reason: adr.path);
      expect(adrSource, contains('.trellis/spec/'), reason: adr.path);
    }

    for (final context in <String>[
      'HTTP API',
      'Native Transport',
      'Platform Capability',
      'Artifact Integration',
    ]) {
      expect(architectureSource, contains(context));
    }
    expect(architectureSource, contains('v2.0.1'));
    expect(architectureSource, contains('权威'));
    expect(architectureSource, contains('取代'));

    expect(
      File(
        'packages/nexa_http_native_internal/pubspec.yaml',
      ).readAsStringSync(),
      isNot(contains('Internal merged native layer')),
    );
    final layering = File(
      '.trellis/spec/guides/project-layering-contract.md',
    ).readAsStringSync();
    expect(layering, isNot(contains('ref: v1.0.2')));
    expect(layering, contains('ref: v2.0.3'));

    for (final platform in <String>['android', 'ios', 'macos', 'windows']) {
      final readme = File(
        'packages/nexa_http_native_$platform/README.md',
      ).readAsStringSync();
      expect(readme, contains('plugin registration'), reason: platform);
      expect(readme, contains('hook adapter'), reason: platform);
      expect(readme, contains('bindings factory'), reason: platform);
      expect(readme, contains('does not expose public Dart runtime APIs'));
    }

    final workspaceIndex = File(
      '.trellis/workspace/index.md',
    ).readAsStringSync();
    expect(workspaceIndex, isNot(contains('## Active Developers')));
    expect(workspaceIndex, isNot(contains('| Sessions |')));
  });

  test('Tracked Markdown local links resolve in the current tree', () async {
    final brokenLinks = <String>[];
    final markdownFiles = (await _repositoryTextFiles()).where(
      (file) => file.path.endsWith('.md'),
    );

    for (final file in markdownFiles) {
      final directory = p.dirname(file.path);
      for (final target in _markdownLinkTargets(file.readAsStringSync())) {
        final decodedTarget = Uri.decodeComponent(target);
        final resolved = p.normalize(p.join(directory, decodedTarget));
        if (!File(resolved).existsSync() && !Directory(resolved).existsSync()) {
          brokenLinks.add('${file.path} -> $target');
        }
      }
    }

    expect(brokenLinks, isEmpty);
  });

  test('Package specs contain current code-backed rules only', () {
    final packageSpecFiles = Directory('.trellis/spec')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.md') &&
              !p.isWithin(p.join('.trellis', 'spec', 'guides'), file.path),
        );
    final templateTerms = RegExp(
      r'To be filled|TODO: fill|placeholder|PLACEHOLDER|\bTBD\b',
    );
    final templateSpecs = <String>[];
    for (final file in packageSpecFiles) {
      if (templateTerms.hasMatch(file.readAsStringSync())) {
        templateSpecs.add(file.path);
      }
    }
    expect(templateSpecs, isEmpty);

    final misplacedQualityRules = <String>[];
    final crossOwnerRule = RegExp(
      r'carrier hook|CodeAsset|CI runner|clean-host|APK lifecycle|release orchestration|Flutter packaging',
    );
    for (final platform in <String>['android', 'ios', 'macos', 'windows']) {
      final file = File(
        '.trellis/spec/nexa_http_native_${platform}_ffi/'
        'rust/quality-guidelines.md',
      );
      if (crossOwnerRule.hasMatch(file.readAsStringSync())) {
        misplacedQualityRules.add(file.path);
      }
    }
    expect(misplacedQualityRules, isEmpty);

    final currentSources = <String>[
      File('README.md').readAsStringSync(),
      File('README.zh-CN.md').readAsStringSync(),
      File('CONTEXT-MAP.md').readAsStringSync(),
      File(
        'packages/nexa_http_native_internal/pubspec.yaml',
      ).readAsStringSync(),
      File(
        '.trellis/spec/guides/project-layering-contract.md',
      ).readAsStringSync(),
    ].join('\n');
    expect(currentSources, isNot(contains('Internal merged native layer')));
    expect(currentSources, isNot(contains('ref: v1.0.2')));
  });
}

Iterable<String> _markdownLinkTargets(String source) sync* {
  final markdownLink = RegExp(r'!?\[[^\]]*\]\(([^)\n]+)\)');
  var inFence = false;

  for (final line in const LineSplitter().convert(source)) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      continue;
    }

    for (final match in markdownLink.allMatches(line)) {
      var target = match.group(1)!.trim();
      if (target.startsWith('<') && target.endsWith('>')) {
        target = target.substring(1, target.length - 1);
      }
      final title = RegExp(r'''\s+["']''').firstMatch(target);
      if (title != null) {
        target = target.substring(0, title.start);
      }
      if (target.isEmpty ||
          target.startsWith('#') ||
          target.startsWith('/') ||
          RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(target) ||
          RegExp(r'[<>{}*]').hasMatch(target) ||
          target.contains('...')) {
        continue;
      }

      target = target.split('#').first.split('?').first;
      if (target.isNotEmpty) {
        yield target;
      }
    }
  }
}

Future<List<File>> _repositoryTextFiles() async {
  final result = await Process.run('git', <String>[
    'ls-files',
    '--cached',
    '--others',
    '--exclude-standard',
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');

  const extensions = <String>{'.json', '.jsonl', '.md', '.yaml', '.yml'};
  return const LineSplitter()
      .convert('${result.stdout}')
      .where((path) => extensions.any(path.endsWith))
      .map(File.new)
      .where((file) => file.existsSync())
      .toList();
}
