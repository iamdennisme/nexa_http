import 'package:path/path.dart' as p;

Iterable<String> walkUpDynamicLibraryCandidates(
  String seed,
  List<String> relativePaths,
) sync* {
  var current = p.normalize(seed);
  while (true) {
    for (final relativePath in relativePaths) {
      yield p.normalize(p.join(current, relativePath));
    }
    final parent = p.dirname(current);
    if (parent == current) {
      break;
    }
    current = parent;
  }
}

void addExistingDynamicLibraryCandidates(
  List<String> output,
  Iterable<String> input,
  bool Function(String path) fileExists,
) {
  for (final candidate in input) {
    final normalized = p.normalize(candidate);
    if (fileExists(normalized)) {
      output.add(normalized);
    }
  }
}

List<String> dedupeDynamicLibraryCandidates(List<String> values) {
  return values.toSet().toList(growable: false);
}
