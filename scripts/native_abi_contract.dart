const List<String> nexaHttpPublicNativeAbiSymbols = <String>[
  'nexa_http_client_create',
  'nexa_http_take_last_error_json',
  'nexa_http_string_free',
  'nexa_http_request_body_alloc',
  'nexa_http_request_body_free',
  'nexa_http_client_execute_async',
  'nexa_http_client_cancel_request',
  'nexa_http_client_close',
  'nexa_http_binary_result_free',
];

Set<String> cHeaderNexaHttpFunctionNames(String source) {
  return RegExp(
    r'\b(nexa_http_[a-z0-9_]+)\s*\(',
  ).allMatches(source).map((match) => match.group(1)!).toSet();
}

Set<String> quotedNexaHttpSymbolNames(String source) {
  return RegExp(
    r'''['"](nexa_http_[a-z0-9_]+)['"]''',
  ).allMatches(source).map((match) => match.group(1)!).toSet();
}

Set<String> nexaHttpSymbolsFromToolOutput(String output) {
  final symbolAtEndOfLine = RegExp(r'\b_?(nexa_http_[a-z0-9_]+)\s*$');
  return output
      .split(RegExp(r'[\r\n]+'))
      .map(symbolAtEndOfLine.firstMatch)
      .whereType<RegExpMatch>()
      .map((match) => match.group(1)!)
      .toSet();
}

NexaHttpNativeAbiDifference compareNexaHttpPublicNativeAbiSymbols(
  Iterable<String> exportedSymbols,
) {
  final expected = nexaHttpPublicNativeAbiSymbols.toSet();
  final actual = exportedSymbols
      .where(
        (symbol) =>
            symbol.startsWith('nexa_http_') &&
            !symbol.startsWith('nexa_http_test_'),
      )
      .toSet();

  return NexaHttpNativeAbiDifference(
    missing: Set<String>.unmodifiable(expected.difference(actual)),
    unexpected: Set<String>.unmodifiable(actual.difference(expected)),
  );
}

final class NexaHttpNativeAbiDifference {
  const NexaHttpNativeAbiDifference({
    required this.missing,
    required this.unexpected,
  });

  final Set<String> missing;
  final Set<String> unexpected;

  bool get matches => missing.isEmpty && unexpected.isEmpty;
}
