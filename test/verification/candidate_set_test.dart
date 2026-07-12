import 'dart:convert';
import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';
import 'package:test/test.dart';

import '../../scripts/verification/candidate_set.dart';

void main() {
  test('streams one candidate artifact digest once per run', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'nexa_http_candidate_digest_',
    );
    addTearDown(() async {
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final artifact = File('${tempDirectory.path}/artifact.bin');
    await artifact.writeAsBytes(<int>[1, 2, 3, 4]);
    var readRuns = 0;
    final cache = CandidateDigestCache(
      openRead: (file) {
        readRuns += 1;
        return file.openRead();
      },
    );

    final first = await cache.digest(artifact);
    final second = await cache.digest(artifact);

    expect(first, second);
    expect(readRuns, 1);
  });

  test('rejects a candidate missing a canonical target artifact', () async {
    final candidateDirectory = await Directory.systemTemp.createTemp(
      'nexa_http_candidate_missing_',
    );
    addTearDown(() async {
      if (candidateDirectory.existsSync()) {
        await candidateDirectory.delete(recursive: true);
      }
    });
    for (final target in nexaHttpSupportedNativeTargets.skip(1)) {
      await File(
        '${candidateDirectory.path}/${target.releaseAssetFileName}',
      ).writeAsString('artifact');
    }

    await expectLater(
      () => validateCandidateArtifactCompleteness(candidateDirectory),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(nexaHttpSupportedNativeTargets.first.releaseAssetFileName),
        ),
      ),
    );
  });

  test('rejects an unknown candidate artifact', () async {
    final candidateDirectory = await Directory.systemTemp.createTemp(
      'nexa_http_candidate_extra_',
    );
    addTearDown(() async {
      if (candidateDirectory.existsSync()) {
        await candidateDirectory.delete(recursive: true);
      }
    });
    for (final target in nexaHttpSupportedNativeTargets) {
      await File(
        '${candidateDirectory.path}/${target.releaseAssetFileName}',
      ).writeAsString('artifact');
    }
    await File('${candidateDirectory.path}/unknown.dll').writeAsString('extra');

    expect(
      () => validateCandidateArtifactCompleteness(candidateDirectory),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('unknown.dll'),
        ),
      ),
    );
  });

  test('rejects a checksum that does not match candidate bytes', () async {
    final candidateDirectory = await Directory.systemTemp.createTemp(
      'nexa_http_candidate_checksum_',
    );
    addTearDown(() async {
      if (candidateDirectory.existsSync()) {
        await candidateDirectory.delete(recursive: true);
      }
    });
    for (final target in nexaHttpSupportedNativeTargets) {
      await File(
        '${candidateDirectory.path}/${target.releaseAssetFileName}',
      ).writeAsString('artifact:${target.releaseAssetFileName}');
    }
    final bundle = await buildNexaHttpNativeReleaseManifest(
      distDirectory: candidateDirectory.path,
    );
    await File(
      '${candidateDirectory.path}/nexa_http_native_assets_manifest.json',
    ).writeAsString(jsonEncode(bundle.manifest));
    final checksumLines = bundle.sha256Lines.toList();
    checksumLines[0] = checksumLines[0].replaceFirst(
      RegExp(r'^[0-9a-f]{64}'),
      List<String>.filled(64, '0').join(),
    );
    await File(
      '${candidateDirectory.path}/SHA256SUMS',
    ).writeAsString('${checksumLines.join('\n')}\n');

    await expectLater(
      () => verifyCandidateManifestAndChecksums(candidateDirectory),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('checksum mismatch'),
        ),
      ),
    );
  });

  test('rejects an unexpected candidate-set digest', () async {
    final candidateDirectory = await Directory.systemTemp.createTemp(
      'nexa_http_candidate_identity_',
    );
    addTearDown(() async {
      if (candidateDirectory.existsSync()) {
        await candidateDirectory.delete(recursive: true);
      }
    });
    for (final target in nexaHttpSupportedNativeTargets) {
      await File(
        '${candidateDirectory.path}/${target.releaseAssetFileName}',
      ).writeAsString('artifact:${target.releaseAssetFileName}');
    }
    final bundle = await buildNexaHttpNativeReleaseManifest(
      distDirectory: candidateDirectory.path,
    );
    await File(
      '${candidateDirectory.path}/nexa_http_native_assets_manifest.json',
    ).writeAsString(jsonEncode(bundle.manifest));
    await File(
      '${candidateDirectory.path}/SHA256SUMS',
    ).writeAsString('${bundle.sha256Lines.join('\n')}\n');

    await expectLater(
      () => verifyCandidateSet(
        candidateDirectory,
        candidateId: 'candidate-42',
        expectedDigest: List<String>.filled(64, '0').join(),
        sdkRef: '20c3786',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('candidate-set digest mismatch'),
        ),
      ),
    );
  });
}
