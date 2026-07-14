import 'dart:convert';
import 'dart:io';

import 'release_transaction.dart';

final class ReleaseProcessResult {
  const ReleaseProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

typedef ReleaseProcessRunner =
    Future<ReleaseProcessResult> Function(
      String executable,
      List<String> arguments,
    );

final class GhReleasePublicationGateway implements ReleasePublicationGateway {
  GhReleasePublicationGateway({ReleaseProcessRunner? runProcess})
    : _runProcess = runProcess ?? _runReleaseProcess;

  final ReleaseProcessRunner _runProcess;

  @override
  Future<void> createTag({
    required String repository,
    required String tag,
    required String commitSha,
    required String transactionMarker,
  }) async {
    final tagObjectOutput = await _runGh(<String>[
      'api',
      '--method',
      'POST',
      'repos/$repository/git/tags',
      '-f',
      'tag=$tag',
      '-f',
      'message=$transactionMarker',
      '-f',
      'object=$commitSha',
      '-f',
      'type=commit',
    ]);
    final tagObject = jsonDecode(tagObjectOutput);
    if (tagObject is! Map<String, Object?> || tagObject['sha'] is! String) {
      throw StateError('Invalid GitHub annotated tag response for $tag');
    }
    final tagObjectSha = tagObject['sha']! as String;
    final createRefArguments = <String>[
      'api',
      '--method',
      'POST',
      'repos/$repository/git/refs',
      '-f',
      'ref=refs/tags/$tag',
      '-f',
      'sha=$tagObjectSha',
    ];
    final createRef = await _runProcess('gh', createRefArguments);
    if (createRef.exitCode == 0) {
      return;
    }
    final existingRef = await _runProcess('gh', <String>[
      'api',
      'repos/$repository/git/ref/tags/${Uri.encodeComponent(tag)}',
    ]);
    if (existingRef.exitCode == 0) {
      final decoded = jsonDecode(existingRef.stdout);
      if (decoded is Map<String, Object?> &&
          decoded['object'] is Map<String, Object?> &&
          (decoded['object']! as Map<String, Object?>)['sha'] == tagObjectSha) {
        return;
      }
    }
    throw ProcessException(
      'gh',
      createRefArguments,
      '${createRef.stdout}${createRef.stderr}',
      createRef.exitCode,
    );
  }

  @override
  Future<void> createRelease({
    required String repository,
    required String tag,
    required String transactionMarker,
  }) async {
    final body = '<!-- $transactionMarker -->';
    final arguments = <String>[
      'api',
      '--method',
      'POST',
      'repos/$repository/releases',
      '-f',
      'tag_name=$tag',
      '-f',
      'name=$tag',
      '-f',
      'body=$body',
      '-F',
      'draft=false',
      '-F',
      'prerelease=false',
    ];
    final result = await _runProcess('gh', arguments);
    if (result.exitCode == 0) {
      return;
    }
    final existingRelease = await _runProcess('gh', <String>[
      'api',
      'repos/$repository/releases/tags/${Uri.encodeComponent(tag)}',
    ]);
    if (existingRelease.exitCode == 0) {
      final decoded = jsonDecode(existingRelease.stdout);
      if (decoded is Map<String, Object?> && decoded['body'] == body) {
        return;
      }
    }
    throw ProcessException(
      'gh',
      arguments,
      '${result.stdout}${result.stderr}',
      result.exitCode,
    );
  }

  @override
  Future<bool> ownsTag({
    required String repository,
    required String tag,
    required String commitSha,
    required String transactionMarker,
  }) async {
    final refResult = await _runProcess('gh', <String>[
      'api',
      'repos/$repository/git/ref/tags/${Uri.encodeComponent(tag)}',
    ]);
    if (_isNotFound(refResult)) {
      return false;
    }
    if (refResult.exitCode != 0) {
      throw ProcessException(
        'gh',
        const <String>['api'],
        '${refResult.stdout}${refResult.stderr}',
        refResult.exitCode,
      );
    }
    final ref = jsonDecode(refResult.stdout);
    if (ref is! Map<String, Object?> ||
        ref['object'] is! Map<String, Object?> ||
        (ref['object']! as Map<String, Object?>)['sha'] is! String) {
      throw StateError('Invalid GitHub tag ref response for $tag');
    }
    final tagObjectSha =
        (ref['object']! as Map<String, Object?>)['sha']! as String;
    final tagResult = await _runProcess('gh', <String>[
      'api',
      'repos/$repository/git/tags/$tagObjectSha',
    ]);
    if (_isNotFound(tagResult)) {
      return false;
    }
    if (tagResult.exitCode != 0) {
      throw ProcessException(
        'gh',
        const <String>['api'],
        '${tagResult.stdout}${tagResult.stderr}',
        tagResult.exitCode,
      );
    }
    final tagObject = jsonDecode(tagResult.stdout);
    return tagObject is Map<String, Object?> &&
        tagObject['tag'] == tag &&
        tagObject['message'] == transactionMarker &&
        tagObject['object'] is Map<String, Object?> &&
        (tagObject['object']! as Map<String, Object?>)['sha'] == commitSha;
  }

  @override
  Future<bool> ownsRelease({
    required String repository,
    required String tag,
    required String transactionMarker,
  }) async {
    final result = await _runProcess('gh', <String>[
      'api',
      'repos/$repository/releases/tags/${Uri.encodeComponent(tag)}',
    ]);
    if (_isNotFound(result)) {
      return false;
    }
    if (result.exitCode != 0) {
      throw ProcessException(
        'gh',
        const <String>['api'],
        '${result.stdout}${result.stderr}',
        result.exitCode,
      );
    }
    final release = jsonDecode(result.stdout);
    return release is Map<String, Object?> &&
        release['body'] == '<!-- $transactionMarker -->';
  }

  @override
  Future<void> uploadAssets({
    required String repository,
    required String tag,
    required List<File> files,
  }) async {
    await _runGh(<String>[
      'release',
      'upload',
      tag,
      '--repo',
      repository,
      ...files.map((file) => file.absolute.path),
    ]);
  }

  @override
  Future<Map<String, String>> fetchReleaseAssetDigests({
    required String repository,
    required String tag,
  }) async {
    final output = await _runGh(<String>[
      'api',
      'repos/$repository/releases/tags/${Uri.encodeComponent(tag)}',
    ]);
    final decoded = jsonDecode(output);
    if (decoded is! Map<String, Object?> ||
        decoded['assets'] is! List<Object?>) {
      throw StateError('Invalid GitHub Release asset response for $tag');
    }
    final digests = <String, String>{};
    for (final rawAsset in decoded['assets']! as List<Object?>) {
      if (rawAsset is! Map<String, Object?> ||
          rawAsset['name'] is! String ||
          rawAsset['digest'] is! String) {
        throw StateError(
          'GitHub Release asset is missing name/digest for $tag',
        );
      }
      final name = rawAsset['name']! as String;
      final digest = rawAsset['digest']! as String;
      final match = RegExp(r'^sha256:([0-9a-f]{64})$').firstMatch(digest);
      if (match == null || digests.containsKey(name)) {
        throw StateError(
          'Invalid or duplicate GitHub Release asset digest for $name: $digest',
        );
      }
      digests[name] = match.group(1)!;
    }
    return Map<String, String>.unmodifiable(digests);
  }

  @override
  Future<void> deleteRelease({
    required String repository,
    required String tag,
  }) async {
    await _runGh(<String>[
      'release',
      'delete',
      tag,
      '--repo',
      repository,
      '--yes',
    ]);
  }

  @override
  Future<void> deleteTag({
    required String repository,
    required String tag,
  }) async {
    await _runGh(<String>[
      'api',
      '--method',
      'DELETE',
      'repos/$repository/git/refs/tags/${Uri.encodeComponent(tag)}',
    ]);
  }

  Future<String> _runGh(List<String> arguments) async {
    final result = await _runProcess('gh', arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        'gh',
        arguments,
        '${result.stdout}${result.stderr}',
        result.exitCode,
      );
    }
    return result.stdout;
  }
}

bool _isNotFound(ReleaseProcessResult result) {
  if (result.exitCode == 0) {
    return false;
  }
  final diagnostics = '${result.stdout}${result.stderr}';
  return diagnostics.contains('HTTP 404') || diagnostics.contains('Not Found');
}

Future<ReleaseProcessResult> _runReleaseProcess(
  String executable,
  List<String> arguments,
) async {
  final result = await Process.run(executable, arguments);
  return ReleaseProcessResult(
    exitCode: result.exitCode,
    stdout: '${result.stdout}',
    stderr: '${result.stderr}',
  );
}
