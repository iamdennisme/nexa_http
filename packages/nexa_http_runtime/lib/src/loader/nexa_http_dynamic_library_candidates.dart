import 'dart:io';

import 'package:path/path.dart' as p;

import 'nexa_http_android_dynamic_library_candidates.dart';
import 'nexa_http_host_platform.dart';
import 'nexa_http_ios_dynamic_library_candidates.dart';
import 'nexa_http_macos_dynamic_library_candidates.dart';
import 'nexa_http_windows_dynamic_library_candidates.dart';

List<String> resolveNexaHttpDynamicLibraryCandidates({
  required NexaHttpHostPlatform platform,
  String? resolvedExecutable,
  String? currentDirectory,
  bool Function(String path)? fileExists,
}) {
  if (platform == NexaHttpHostPlatform.android) {
    return resolveNexaHttpAndroidDynamicLibraryCandidates();
  }

  final executablePath = resolvedExecutable ?? Platform.resolvedExecutable;
  final executableDirectory = p.dirname(executablePath);
  final exists = fileExists ?? ((path) => File(path).existsSync());
  final seeds = <String>{
    p.normalize(currentDirectory ?? Directory.current.path),
    p.normalize(executableDirectory),
  };

  return switch (platform) {
    NexaHttpHostPlatform.ios => resolveNexaHttpIosDynamicLibraryCandidates(
      executableDirectory: executableDirectory,
      seeds: seeds,
      fileExists: exists,
    ),
    NexaHttpHostPlatform.macos => resolveNexaHttpMacosDynamicLibraryCandidates(
      executableDirectory: executableDirectory,
      seeds: seeds,
      fileExists: exists,
    ),
    NexaHttpHostPlatform.windows =>
      resolveNexaHttpWindowsDynamicLibraryCandidates(
      executableDirectory: executableDirectory,
      seeds: seeds,
      fileExists: exists,
    ),
    NexaHttpHostPlatform.android => const <String>[],
  };
}
