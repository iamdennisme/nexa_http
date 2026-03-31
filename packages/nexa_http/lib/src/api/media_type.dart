import 'dart:convert';

final class MediaType {
  MediaType._({
    required this.type,
    required this.subtype,
    required Map<String, String> parameters,
  }) : parameters = Map.unmodifiable(parameters);

  final String type;
  final String subtype;
  final Map<String, String> parameters;

  factory MediaType.parse(String value) {
    final segments = value
        .split(';')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      throw FormatException('Invalid media type: $value');
    }

    final typeParts = segments.first.split('/');
    if (typeParts.length != 2 ||
        typeParts[0].trim().isEmpty ||
        typeParts[1].trim().isEmpty) {
      throw FormatException('Invalid media type: $value');
    }

    final parameters = <String, String>{};
    for (final segment in segments.skip(1)) {
      final separatorIndex = segment.indexOf('=');
      if (separatorIndex <= 0 || separatorIndex == segment.length - 1) {
        throw FormatException('Invalid media type parameter: $segment');
      }
      final name = segment.substring(0, separatorIndex).trim().toLowerCase();
      final rawValue = segment.substring(separatorIndex + 1).trim();
      parameters[name] = _stripQuotes(rawValue);
    }

    return MediaType._(
      type: typeParts[0].trim().toLowerCase(),
      subtype: typeParts[1].trim().toLowerCase(),
      parameters: parameters,
    );
  }

  Encoding get encoding {
    final charset = parameters['charset'];
    if (charset == null) {
      return utf8;
    }
    return Encoding.getByName(charset) ?? utf8;
  }

  @override
  String toString() {
    if (parameters.isEmpty) {
      return '$type/$subtype';
    }
    final buffer = StringBuffer('$type/$subtype');
    for (final entry in parameters.entries) {
      buffer.write('; ${entry.key}=${entry.value}');
    }
    return buffer.toString();
  }

  static String _stripQuotes(String value) {
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}
