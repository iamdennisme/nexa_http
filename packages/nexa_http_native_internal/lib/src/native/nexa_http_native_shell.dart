import 'dart:io';

import 'package:path/path.dart' as p;

typedef NexaHttpNativeShellProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);
typedef NexaHttpNativeFileExists = bool Function(String path);
typedef NexaHttpNativeBashResolver = Future<String> Function();

Future<String> resolveNexaHttpNativeBashExecutable({
  bool? isWindows,
  Map<String, String>? environment,
  NexaHttpNativeFileExists fileExists = _fileExists,
  NexaHttpNativeShellProcessRunner runProcess = _runProcess,
}) async {
  if (!(isWindows ?? Platform.isWindows)) {
    return 'bash';
  }

  final resolvedEnvironment = environment ?? Platform.environment;
  final candidates = <String>{};
  void addGitRoot(String? root) {
    final normalized = root?.trim() ?? '';
    if (normalized.isNotEmpty) {
      candidates.add(p.join(normalized, 'bin', 'bash.exe'));
    }
  }

  addGitRoot(resolvedEnvironment['GIT_INSTALL_ROOT']);
  for (final key in const <String>['ProgramFiles', 'ProgramW6432']) {
    final programFiles = resolvedEnvironment[key]?.trim() ?? '';
    if (programFiles.isNotEmpty) {
      addGitRoot(p.join(programFiles, 'Git'));
    }
  }

  try {
    final result = await runProcess('where.exe', const <String>['git.exe']);
    if (result.exitCode == 0) {
      for (final line in '${result.stdout}'.split(RegExp(r'[\r\n]+'))) {
        final gitPath = line.trim();
        if (gitPath.isEmpty) {
          continue;
        }
        final parentName = p.basename(p.dirname(gitPath)).toLowerCase();
        if (parentName == 'cmd' || parentName == 'bin') {
          addGitRoot(p.dirname(p.dirname(gitPath)));
        }
      }
    }
  } on ProcessException {
    // The explicit Git roots above remain authoritative candidates.
  }

  for (final candidate in candidates) {
    if (fileExists(candidate)) {
      return candidate;
    }
  }

  throw StateError(
    'stage=native build toolchain resolution platform=windows '
    'expected_action=Install Git for Windows with Git Bash and rerun the '
    'Flutter build or verification suite. underlying_error=Unable to locate '
    'Git\\bin\\bash.exe; checked ${candidates.join(', ')}',
  );
}

bool _fileExists(String path) => File(path).existsSync();

Future<ProcessResult> _runProcess(String executable, List<String> arguments) {
  return Process.run(executable, arguments);
}
