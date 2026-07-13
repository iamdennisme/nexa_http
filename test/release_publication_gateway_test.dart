import 'dart:convert';

import 'package:test/test.dart';

import '../scripts/release/release_publication_gateway.dart';

void main() {
  test('GitHub gateway normalizes release asset SHA-256 proof', () async {
    final gateway = GhReleasePublicationGateway(
      runProcess: (executable, arguments) async {
        return ReleaseProcessResult(
          exitCode: 0,
          stdout: jsonEncode(<String, Object?>{
            'assets': <Object?>[
              <String, Object?>{
                'name': 'asset.so',
                'digest':
                    'sha256:'
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              },
            ],
          }),
          stderr: '',
        );
      },
    );

    final digests = await gateway.fetchReleaseAssetDigests(
      repository: 'iamdennisme/nexa_http',
      tag: 'v2.0.0',
    );

    expect(digests, <String, String>{
      'asset.so':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    });
  });

  test('GitHub gateway creates marker-owned tag and release state', () async {
    final commands = <List<String>>[];
    final gateway = GhReleasePublicationGateway(
      runProcess: (executable, arguments) async {
        commands.add(arguments);
        if (arguments.contains('repos/iamdennisme/nexa_http/git/tags')) {
          return const ReleaseProcessResult(
            exitCode: 0,
            stdout: '{"sha":"tag-object-sha"}',
            stderr: '',
          );
        }
        return const ReleaseProcessResult(
          exitCode: 0,
          stdout: '{}',
          stderr: '',
        );
      },
    );

    await gateway.createTag(
      repository: 'iamdennisme/nexa_http',
      tag: 'v2.0.0',
      commitSha: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      transactionMarker: 'candidate=gha:42:314;digest=abc',
    );
    await gateway.createRelease(
      repository: 'iamdennisme/nexa_http',
      tag: 'v2.0.0',
      transactionMarker: 'candidate=gha:42:314;digest=abc',
    );

    final commandText = commands.map((command) => command.join(' ')).join('\n');
    expect(commandText, contains('git/tags'));
    expect(commandText, contains('message=candidate=gha:42:314;digest=abc'));
    expect(commandText, contains('ref=refs/tags/v2.0.0'));
    expect(commandText, contains('repos/iamdennisme/nexa_http/releases'));
    expect(
      commandText,
      contains('body=<!-- candidate=gha:42:314;digest=abc -->'),
    );
    expect(commandText, isNot(contains('release create')));
  });
}
