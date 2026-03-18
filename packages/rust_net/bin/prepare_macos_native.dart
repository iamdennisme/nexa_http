import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  try {
    final options = _CliOptions.parse(args);
    if (options.showHelp) {
      stdout.writeln(_CliOptions.usage);
      return;
    }

    final exitCode = await _run(options);
    if (exitCode != 0) {
      exit(exitCode);
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_CliOptions.usage);
    exit(64);
  }
}

Future<int> _run(_CliOptions options) async {
  if (!Platform.isMacOS) {
    stderr.writeln(
      'prepare_macos_native currently only supports macOS hosts.',
    );
    return 64;
  }

  final packageRoot = await _resolvePackageRoot();
  final cargoManifestPath = p.join(
    packageRoot,
    'native',
    'rust_net_native',
    'Cargo.toml',
  );
  final outputPath = options.outputPath ??
      p.join(packageRoot, 'macos', 'Libraries', 'librust_net_native.dylib');

  final cargoArgs = <String>[
    'build',
    '--manifest-path',
    cargoManifestPath,
    if (options.configuration == _BuildConfiguration.release) '--release',
  ];

  stdout.writeln(
    'Building rust_net native library (${options.configuration.name})...',
  );

  Process process;
  try {
    process = await Process.start(
      'cargo',
      cargoArgs,
      workingDirectory: packageRoot,
      runInShell: true,
    );
  } on ProcessException catch (error) {
    stderr.writeln('Failed to start cargo: $error');
    return 127;
  }

  await Future.wait<void>(<Future<void>>[
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);

  final cargoExitCode = await process.exitCode;
  if (cargoExitCode != 0) {
    return cargoExitCode;
  }

  final builtLibraryPath = p.join(
    packageRoot,
    'native',
    'rust_net_native',
    'target',
    options.configuration.name,
    'librust_net_native.dylib',
  );
  final builtLibrary = File(builtLibraryPath);
  if (!builtLibrary.existsSync()) {
    stderr.writeln(
      'Expected native library at $builtLibraryPath, but it was not found.',
    );
    return 1;
  }

  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  if (outputFile.existsSync()) {
    outputFile.deleteSync();
  }
  await builtLibrary.copy(outputPath);

  stdout.writeln('Prepared macOS dylib at ${p.normalize(outputPath)}');
  stdout.writeln(
    'Consumer apps can now build with the packaged rust_net macOS library.',
  );
  return 0;
}

Future<String> _resolvePackageRoot() async {
  final libraryUri = await Isolate.resolvePackageUri(
    Uri.parse('package:rust_net/rust_net.dart'),
  );
  if (libraryUri == null) {
    throw StateError('Unable to resolve package:rust_net/rust_net.dart.');
  }

  return p.normalize(
    p.dirname(
      p.dirname(
        libraryUri.toFilePath(),
      ),
    ),
  );
}

enum _BuildConfiguration {
  debug,
  release,
}

final class _CliOptions {
  const _CliOptions({
    required this.configuration,
    required this.outputPath,
    required this.showHelp,
  });

  static const usage = '''
Usage: dart run rust_net:prepare_macos_native [options]

Options:
  --configuration <debug|release>   Build mode for the packaged dylib.
  --output <path>                   Override the packaged dylib output path.
  --help                            Show this help message.
''';

  final _BuildConfiguration configuration;
  final String? outputPath;
  final bool showHelp;

  static _CliOptions parse(List<String> args) {
    var configuration = _BuildConfiguration.debug;
    String? outputPath;
    var showHelp = false;

    for (var index = 0; index < args.length; index++) {
      final argument = args[index];
      if (argument == '--help' || argument == '-h') {
        showHelp = true;
        continue;
      }
      if (argument == '--configuration') {
        configuration =
            _parseConfiguration(_readValue(args, ++index, argument));
        continue;
      }
      if (argument.startsWith('--configuration=')) {
        configuration = _parseConfiguration(
          argument.substring('--configuration='.length),
        );
        continue;
      }
      if (argument == '--output') {
        outputPath = _readValue(args, ++index, argument);
        continue;
      }
      if (argument.startsWith('--output=')) {
        outputPath = argument.substring('--output='.length);
        continue;
      }
      throw FormatException('Unknown argument: $argument');
    }

    return _CliOptions(
      configuration: configuration,
      outputPath: outputPath == null || outputPath.isEmpty ? null : outputPath,
      showHelp: showHelp,
    );
  }

  static _BuildConfiguration _parseConfiguration(String value) {
    switch (value.toLowerCase()) {
      case 'debug':
        return _BuildConfiguration.debug;
      case 'release':
        return _BuildConfiguration.release;
      default:
        throw FormatException(
          'Unsupported configuration "$value". Use debug or release.',
        );
    }
  }

  static String _readValue(List<String> args, int index, String option) {
    if (index >= args.length) {
      throw FormatException('Missing value for $option.');
    }
    return args[index];
  }
}
