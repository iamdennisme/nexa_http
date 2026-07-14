import 'dart:io';

import 'package:test/test.dart';

void main() {
  final fixtureDirectory = Directory(
    '.dart_tool/public_api_contract_test',
  );

  setUp(() {
    fixtureDirectory.createSync(recursive: true);
  });

  tearDown(() {
    if (fixtureDirectory.existsSync()) {
      fixtureDirectory.deleteSync(recursive: true);
    }
  });

  test('the package root exposes only the supported HTTP library', () {
    final rootLibraries =
        Directory('lib')
            .listSync(followLinks: false)
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .toList(growable: false)
          ..sort();

    expect(rootLibraries, const <String>['nexa_http.dart']);
  });

  test('the generated bindings are unavailable from the package root', () async {
    final positive = File('${fixtureDirectory.path}/positive.dart')
      ..writeAsStringSync('''
import 'package:nexa_http/nexa_http.dart';

void main() {
  NexaHttpClient();
}
''');
    final negative = File('${fixtureDirectory.path}/negative.dart')
      ..writeAsStringSync('''
import 'package:nexa_http/nexa_http_bindings_generated.dart';

void main() {}
''');

    final positiveResult = await _analyze(positive);
    expect(
      positiveResult.exitCode,
      0,
      reason: '${positiveResult.stdout}\n${positiveResult.stderr}',
    );

    final negativeResult = await _analyze(negative);
    expect(negativeResult.exitCode, isNot(0));
    expect(
      '${negativeResult.stdout}\n${negativeResult.stderr}',
      contains('nexa_http_bindings_generated.dart'),
    );
  });

  test('legacy HTTP Failure fields are unavailable', () async {
    final negative = File(
      '${fixtureDirectory.path}/exception_fields.dart',
    )..writeAsStringSync('''
import 'package:nexa_http/nexa_http.dart';

Object? readCode(NexaHttpException error) => error.code;
Object? readStatusCode(NexaHttpException error) => error.statusCode;
Object? readIsTimeout(NexaHttpException error) => error.isTimeout;
Object? readDetails(NexaHttpException error) => error.details;
''');

    final result = await _analyze(negative);
    expect(result.exitCode, isNot(0));
    final output = '${result.stdout}\n${result.stderr}';
    for (final field in const <String>[
      'code',
      'statusCode',
      'isTimeout',
      'details',
    ]) {
      expect(
        output,
        contains(field),
      );
    }
  });

  test('the public Callback type is unavailable', () async {
    final negative = File(
      '${fixtureDirectory.path}/callback.dart',
    )..writeAsStringSync('''
import 'package:nexa_http/nexa_http.dart';

Callback? callback;
''');

    final result = await _analyze(negative);
    expect(result.exitCode, isNot(0));
    expect(
      '${result.stdout}\n${result.stderr}',
      contains('Callback'),
    );
  });

  test('Call.enqueue is unavailable', () async {
    final negative = File(
      '${fixtureDirectory.path}/call_enqueue.dart',
    )..writeAsStringSync('''
import 'package:nexa_http/nexa_http.dart';

void enqueue(Call call) => call.enqueue(null);
''');

    final result = await _analyze(negative);
    expect(result.exitCode, isNot(0));
    expect('${result.stdout}\n${result.stderr}', contains('enqueue'));
  });

  test('Call.clone is unavailable', () async {
    final negative = File(
      '${fixtureDirectory.path}/call_clone.dart',
    )..writeAsStringSync('''
import 'package:nexa_http/nexa_http.dart';

Call clone(Call call) => call.clone();
''');

    final result = await _analyze(negative);
    expect(result.exitCode, isNot(0));
    expect('${result.stdout}\n${result.stderr}', contains('clone'));
  });

  test('NexaHttpClient.execute is unavailable', () async {
    final negative = File(
      '${fixtureDirectory.path}/client_execute.dart',
    )..writeAsStringSync('''
import 'package:nexa_http/nexa_http.dart';

Future<Response> execute(NexaHttpClient client, Request request) =>
    client.execute(request);
''');

    final result = await _analyze(negative);
    expect(result.exitCode, isNot(0));
    expect('${result.stdout}\n${result.stderr}', contains('execute'));
  });

  test('legacy RequestBody factory and read surface are unavailable', () async {
    final negative = File(
      '${fixtureDirectory.path}/request_body_legacy.dart',
    )..writeAsStringSync('''
import 'dart:typed_data';

import 'package:nexa_http/nexa_http.dart';

final body = RequestBody.takeBytes(Uint8List(0));
final legacyFactory = RequestBody.bytes(Uint8List(0));
final legacyBytes = body.bytes();
final legacyStream = body.byteStream();
final legacyPayload = body.payloadBytes;
''');

    final result = await _analyze(negative);
    expect(result.exitCode, isNot(0));
    final output = '${result.stdout}\n${result.stderr}';
    for (final symbol in const <String>[
      'bytes',
      'byteStream',
      'payloadBytes',
    ]) {
      expect(output, contains(symbol));
    }
  });

  test('RequestBody transport access is unavailable from the root API', () async {
    final negative = File(
      '${fixtureDirectory.path}/request_body_transport_access.dart',
    )..writeAsStringSync('''
import 'package:nexa_http/nexa_http.dart';

RequestBodyTransportAccess? access;
''');

    final result = await _analyze(negative);
    expect(result.exitCode, isNot(0));
    expect(
      '${result.stdout}\n${result.stderr}',
      contains('RequestBodyTransportAccess'),
    );
  });

  test('legacy ResponseBody streaming and adoption are unavailable', () async {
    final negative = File(
      '${fixtureDirectory.path}/response_body_legacy.dart',
    )..writeAsStringSync('''
import 'package:nexa_http/nexa_http.dart';

final body = ResponseBody.bytes(const <int>[]);
final legacyStream = body.byteStream();
final legacyAdoption = adoptResponseBodyBytes(const <int>[]);
''');

    final result = await _analyze(negative);
    expect(result.exitCode, isNot(0));
    final output = '${result.stdout}\n${result.stderr}';
    expect(output, contains('byteStream'));
    expect(output, contains('adoptResponseBodyBytes'));
  });

  test('ResponseBody transport access is unavailable from the root API', () async {
    final negative = File(
      '${fixtureDirectory.path}/response_body_transport_access.dart',
    )..writeAsStringSync('''
import 'package:nexa_http/nexa_http.dart';

ResponseBodyTransportAccess? access;
''');

    final result = await _analyze(negative);
    expect(result.exitCode, isNot(0));
    expect(
      '${result.stdout}\n${result.stderr}',
      contains('ResponseBodyTransportAccess'),
    );
  });
}

Future<ProcessResult> _analyze(File fixture) {
  return Process.run(
    'dart',
    <String>['analyze', fixture.path],
    workingDirectory: Directory.current.path,
  );
}
