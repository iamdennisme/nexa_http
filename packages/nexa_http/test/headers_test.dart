import 'package:nexa_http/nexa_http.dart';
import 'package:test/test.dart';

void main() {
  test('values reuses the stored immutable list across reads', () {
    final headers = Headers.of(<String, List<String>>{
      'cache-control': <String>['max-age=60'],
    });

    final first = headers.values('cache-control');
    final second = headers.values('cache-control');

    expect(identical(first, second), isTrue);
    expect(() => first.add('no-store'), throwsUnsupportedError);
  });

  test('toMultimap reuses the stored immutable multimap across reads', () {
    final headers = Headers.of(<String, List<String>>{
      'cache-control': <String>['max-age=60'],
      'accept': <String>['application/json'],
    });

    final first = headers.toMultimap();
    final second = headers.toMultimap();

    expect(identical(first, second), isTrue);
    expect(identical(first['cache-control'], second['cache-control']), isTrue);
    expect(
      () => first['cache-control'] = <String>['no-store'],
      throwsUnsupportedError,
    );
  });

  test('toMap reuses the projected single-value map across reads', () {
    final headers = Headers.of(<String, List<String>>{
      'accept': <String>['text/plain', 'application/json'],
    });

    final first = headers.toMap();
    final second = headers.toMap();

    expect(identical(first, second), isTrue);
    expect(first['accept'], 'application/json');
    expect(
      () => first['accept'] = 'application/xml',
      throwsUnsupportedError,
    );
  });
}
