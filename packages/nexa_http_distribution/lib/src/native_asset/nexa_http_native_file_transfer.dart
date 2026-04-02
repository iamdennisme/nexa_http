import 'dart:async';
import 'dart:convert';
import 'dart:io';

const httpConnectTimeout = Duration(seconds: 15);
const httpRequestTimeout = Duration(seconds: 60);
const httpTransferTimeout = Duration(minutes: 5);

Future<void> copyUriToFile(Uri sourceUri, File destination) async {
  switch (sourceUri.scheme) {
    case 'file':
    case '':
      final source = File.fromUri(
        sourceUri.scheme.isEmpty
            ? sourceUri.replace(scheme: 'file')
            : sourceUri,
      );
      await destination.parent.create(recursive: true);
      await source.copy(destination.path);
      return;
    case 'http':
    case 'https':
      final client = newHttpClient();
      try {
        final request =
            await client.getUrl(sourceUri).timeout(httpRequestTimeout);
        final response = await request.close().timeout(httpRequestTimeout);
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Failed to download $sourceUri: ${response.statusCode}',
            uri: sourceUri,
          );
        }
        await destination.parent.create(recursive: true);
        await response
            .pipe(destination.openWrite())
            .timeout(httpTransferTimeout);
      } on TimeoutException catch (error) {
        throw HttpException(
          'Timed out downloading $sourceUri '
          '(connect=${httpConnectTimeout.inSeconds}s, '
          'request=${httpRequestTimeout.inSeconds}s, '
          'transfer=${httpTransferTimeout.inSeconds}s): $error',
          uri: sourceUri,
        );
      } finally {
        client.close(force: true);
      }
      return;
    default:
      throw UnsupportedError(
        'Unsupported native asset URI scheme: ${sourceUri.scheme}',
      );
  }
}

Future<String> readUriAsString(Uri uri) async {
  switch (uri.scheme) {
    case 'file':
    case '':
      return File.fromUri(
        uri.scheme.isEmpty ? uri.replace(scheme: 'file') : uri,
      ).readAsString();
    case 'http':
    case 'https':
      final client = newHttpClient();
      try {
        final request = await client.getUrl(uri).timeout(httpRequestTimeout);
        final response = await request.close().timeout(httpRequestTimeout);
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'Failed to download $uri: ${response.statusCode}',
            uri: uri,
          );
        }
        final body = await response.fold<List<int>>(
          <int>[],
          (buffer, chunk) => buffer..addAll(chunk),
        ).timeout(httpTransferTimeout);
        return utf8.decode(body);
      } on TimeoutException catch (error) {
        throw HttpException(
          'Timed out downloading $uri '
          '(connect=${httpConnectTimeout.inSeconds}s, '
          'request=${httpRequestTimeout.inSeconds}s, '
          'transfer=${httpTransferTimeout.inSeconds}s): $error',
          uri: uri,
        );
      } finally {
        client.close(force: true);
      }
    default:
      throw UnsupportedError('Unsupported manifest URI scheme: ${uri.scheme}');
  }
}

HttpClient newHttpClient() {
  final client = HttpClient();
  client.connectionTimeout = httpConnectTimeout;
  return client;
}
