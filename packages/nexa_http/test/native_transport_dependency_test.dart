import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _featurePath = 'lib/src/internal/native_transport';
const _legacyPaths = <String>[
  'lib/src/data',
  'lib/src/native_bridge',
  'lib/src/internal/transport',
  'lib/src/internal/testing',
];

void main() {
  test('native transport has one clean feature directory', () {
    for (final path in _legacyPaths) {
      expect(
        Directory(path).existsSync(),
        isFalse,
        reason: 'legacy native transport directory still exists: $path',
      );
    }

    final featureDirectory = Directory(_featurePath);
    expect(featureDirectory.existsSync(), isTrue);
    expect(
      featureDirectory.listSync(followLinks: false).whereType<Directory>(),
      isEmpty,
      reason: 'the native transport feature must stay flat',
    );
  });

  test('production code enters native transport only through its facade', () {
    final sourceDirectory = Directory('lib');
    final featureDirectory = Directory(_featurePath);
    expect(featureDirectory.existsSync(), isTrue);

    for (final file
        in sourceDirectory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final sourcePath = _portablePath(file.path);
      final source = file.readAsStringSync();
      final directives = _directives(source);
      final isFeatureFile = sourcePath.startsWith('$_featurePath/');

      if (isFeatureFile) {
        for (final directive in directives) {
          expect(
            directive.keyword,
            isNot('export'),
            reason:
                'native transport must not add a forwarding barrel: '
                '$sourcePath',
          );
          for (final uri in directive.uris) {
            final targetPath = _resolveImportPath(sourcePath, uri);
            if (targetPath == null) {
              continue;
            }
            expect(
              _isClientOrLegacyTarget(targetPath),
              isFalse,
              reason: '$sourcePath has a forbidden dependency on $uri',
            );
          }
        }
        continue;
      }

      for (final directive in directives) {
        for (final uri in directive.uris) {
          final targetPath = _resolveImportPath(sourcePath, uri);
          if (targetPath == null || !targetPath.startsWith('$_featurePath/')) {
            continue;
          }
          expect(sourcePath, 'lib/src/nexa_http_client.dart');
          expect(directive.keyword, 'import');
          expect(targetPath, '$_featurePath/nexa_http_native_transport.dart');
        }
      }
    }
  });

  test('dependency directives ignore comments and include every URI', () {
    final source = <String>[
      "// import 'ignored_line_comment.dart';",
      '/*',
      "import 'ignored_block_comment.dart';",
      '*/',
      "import 'fallback.dart'",
      "    if (dart.library.io == 'enabled') 'conditional.dart';",
      "export 'exported.dart';",
      "part 'generated.dart';",
      r'''const snippet = "${helper("import 'ignored_interpolation.dart';")}";''',
      'const multilineSnippet = """',
      "import 'ignored_multiline_string.dart';",
      '""";',
    ].join('\n');

    expect(_dependencyUris(source), <String>[
      'fallback.dart',
      'conditional.dart',
      'exported.dart',
      'generated.dart',
    ]);
  });

  test('feature dependencies reject the package root', () {
    expect(_isClientOrLegacyTarget('lib/nexa_http.dart'), isTrue);
  });
}

Iterable<String> _dependencyUris(String source) sync* {
  for (final directive in _directives(source)) {
    yield* directive.uris;
  }
}

Iterable<_DartDirective> _directives(String source) sync* {
  final tokens = _tokens(source).toList(growable: false);
  const keywords = <String>{'import', 'export', 'part'};
  var index = 0;

  while (index < tokens.length) {
    final token = tokens[index];
    if (token.kind == _TokenKind.identifier && token.value == 'library') {
      index = _indexAfterSemicolon(tokens, index + 1);
      continue;
    }
    if (token.kind != _TokenKind.identifier ||
        !keywords.contains(token.value)) {
      break;
    }

    final uris = <String>[];
    final keyword = token.value;
    var expectsUri = true;
    var conditionDepth = 0;
    var inCondition = false;
    index += 1;

    while (index < tokens.length) {
      final directiveToken = tokens[index];
      if (directiveToken.kind == _TokenKind.semicolon) {
        index += 1;
        break;
      }

      if (keyword == 'part') {
        if (directiveToken.kind == _TokenKind.string && uris.isEmpty) {
          uris.add(directiveToken.value);
        }
      } else if (directiveToken.kind == _TokenKind.identifier &&
          directiveToken.value == 'if') {
        inCondition = true;
        conditionDepth = 0;
        expectsUri = false;
      } else if (inCondition) {
        if (directiveToken.kind == _TokenKind.leftParenthesis) {
          conditionDepth += 1;
        } else if (directiveToken.kind == _TokenKind.rightParenthesis) {
          conditionDepth -= 1;
          if (conditionDepth == 0) {
            inCondition = false;
            expectsUri = true;
          }
        }
      } else if (directiveToken.kind == _TokenKind.string && expectsUri) {
        uris.add(directiveToken.value);
        expectsUri = false;
      }

      index += 1;
    }
    yield _DartDirective(keyword, uris);
  }
}

int _indexAfterSemicolon(List<_Token> tokens, int index) {
  while (index < tokens.length) {
    if (tokens[index].kind == _TokenKind.semicolon) {
      return index + 1;
    }
    index += 1;
  }
  return index;
}

Iterable<_Token> _tokens(String source) sync* {
  var index = 0;
  while (index < source.length) {
    final character = source[index];
    if (_isWhitespace(character)) {
      index += 1;
      continue;
    }
    if (source.startsWith('//', index)) {
      final lineEnd = source.indexOf('\n', index + 2);
      index = lineEnd == -1 ? source.length : lineEnd + 1;
      continue;
    }
    if (source.startsWith('/*', index)) {
      index = _skipBlockComment(source, index);
      continue;
    }

    final isRawString =
        (character == 'r' || character == 'R') &&
        index + 1 < source.length &&
        _isQuote(source[index + 1]);
    if (isRawString || _isQuote(character)) {
      final string = _readString(
        source,
        isRawString ? index + 1 : index,
        raw: isRawString,
      );
      yield _Token(_TokenKind.string, string.value);
      index = string.end;
      continue;
    }

    if (_isIdentifierStart(character)) {
      final start = index;
      index += 1;
      while (index < source.length && _isIdentifierPart(source[index])) {
        index += 1;
      }
      yield _Token(_TokenKind.identifier, source.substring(start, index));
      continue;
    }

    if (character == ';') {
      yield const _Token(_TokenKind.semicolon, ';');
    } else if (character == '(') {
      yield const _Token(_TokenKind.leftParenthesis, '(');
    } else if (character == ')') {
      yield const _Token(_TokenKind.rightParenthesis, ')');
    }
    index += 1;
  }
}

int _skipBlockComment(String source, int start) {
  var depth = 1;
  var index = start + 2;
  while (index < source.length && depth > 0) {
    if (source.startsWith('/*', index)) {
      depth += 1;
      index += 2;
    } else if (source.startsWith('*/', index)) {
      depth -= 1;
      index += 2;
    } else {
      index += 1;
    }
  }
  return index;
}

_StringToken _readString(String source, int quoteIndex, {required bool raw}) {
  final quote = source[quoteIndex];
  final triple = source.startsWith('$quote$quote$quote', quoteIndex);
  final delimiter = triple ? '$quote$quote$quote' : quote;
  final value = StringBuffer();
  var index = quoteIndex + delimiter.length;

  while (index < source.length) {
    if (source.startsWith(delimiter, index)) {
      return _StringToken(value.toString(), index + delimiter.length);
    }
    if (!raw && source[index] == r'\') {
      final escape = _readEscape(source, index);
      value.write(escape.value);
      index = escape.end;
      continue;
    }
    value.write(source[index]);
    index += 1;
  }

  return _StringToken(value.toString(), source.length);
}

_StringToken _readEscape(String source, int slashIndex) {
  if (slashIndex + 1 >= source.length) {
    return _StringToken(r'\', source.length);
  }

  final marker = source[slashIndex + 1];
  const simpleEscapes = <String, String>{
    'b': '\b',
    'f': '\f',
    'n': '\n',
    'r': '\r',
    't': '\t',
    'v': '\v',
  };
  final simple = simpleEscapes[marker];
  if (simple != null) {
    return _StringToken(simple, slashIndex + 2);
  }

  if (marker == 'x') {
    return _readHexEscape(source, slashIndex, digits: 2, prefixLength: 2);
  }
  if (marker == 'u') {
    if (slashIndex + 2 < source.length && source[slashIndex + 2] == '{') {
      final endBrace = source.indexOf('}', slashIndex + 3);
      if (endBrace != -1) {
        final hex = source.substring(slashIndex + 3, endBrace);
        final codePoint = int.tryParse(hex, radix: 16);
        if (codePoint != null) {
          return _StringToken(String.fromCharCode(codePoint), endBrace + 1);
        }
      }
    }
    return _readHexEscape(source, slashIndex, digits: 4, prefixLength: 2);
  }

  return _StringToken(marker, slashIndex + 2);
}

_StringToken _readHexEscape(
  String source,
  int slashIndex, {
  required int digits,
  required int prefixLength,
}) {
  final digitsStart = slashIndex + prefixLength;
  final digitsEnd = digitsStart + digits;
  if (digitsEnd <= source.length) {
    final codePoint = int.tryParse(
      source.substring(digitsStart, digitsEnd),
      radix: 16,
    );
    if (codePoint != null) {
      return _StringToken(String.fromCharCode(codePoint), digitsEnd);
    }
  }
  return _StringToken(source[slashIndex + 1], slashIndex + 2);
}

bool _isClientOrLegacyTarget(String targetPath) {
  return targetPath == 'lib/nexa_http.dart' ||
      targetPath == 'lib/src/nexa_http_client.dart' ||
      targetPath.startsWith('lib/src/client/') ||
      _legacyPaths.any(
        (path) => targetPath == path || targetPath.startsWith('$path/'),
      );
}

String _portablePath(String path) => path.replaceAll('\\', '/');

String? _resolveImportPath(String sourcePath, String uri) {
  const packagePrefix = 'package:nexa_http/';
  if (uri.startsWith(packagePrefix)) {
    return _portablePath(
      p.normalize(p.join('lib', uri.substring(packagePrefix.length))),
    );
  }
  if (uri.startsWith('package:') || uri.startsWith('dart:')) {
    return null;
  }
  return _portablePath(p.normalize(p.join(p.dirname(sourcePath), uri)));
}

bool _isWhitespace(String character) =>
    character == ' ' ||
    character == '\t' ||
    character == '\r' ||
    character == '\n' ||
    character == '\f';

bool _isQuote(String character) => character == "'" || character == '"';

bool _isIdentifierStart(String character) =>
    RegExp(r'[A-Za-z_$]').hasMatch(character);

bool _isIdentifierPart(String character) =>
    RegExp(r'[A-Za-z0-9_$]').hasMatch(character);

enum _TokenKind {
  identifier,
  string,
  semicolon,
  leftParenthesis,
  rightParenthesis,
}

final class _Token {
  const _Token(this.kind, this.value);

  final _TokenKind kind;
  final String value;
}

final class _DartDirective {
  const _DartDirective(this.keyword, this.uris);

  final String keyword;
  final List<String> uris;
}

final class _StringToken {
  const _StringToken(this.value, this.end);

  final String value;
  final int end;
}
