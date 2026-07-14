import 'model.dart';

final class VerificationCatalog {
  VerificationCatalog(Iterable<VerificationCheckDefinition> checks) {
    final registeredChecks = checks.toList(growable: false);
    final checkIds = <VerificationCheckId>{};
    for (final check in registeredChecks) {
      if (!checkIds.add(check.id)) {
        throw StateError('Duplicate verification check ID: ${check.id}');
      }
      final suiteIds = <VerificationSuiteId>{};
      for (final suiteId in check.suites) {
        if (!supportedVerificationSuiteIds.contains(suiteId)) {
          throw StateError(
            'Unknown verification suite ID: $suiteId for check ${check.id}',
          );
        }
        if (!suiteIds.add(suiteId)) {
          throw StateError(
            'Duplicate suite membership: ${check.id} in $suiteId',
          );
        }
      }
      if (check.suites.isNotEmpty && check.supportedExecutions.isEmpty) {
        throw StateError(
          'No execution coverage for check ${check.id} in ${check.suites.first}',
        );
      }
    }
    for (final check in registeredChecks) {
      for (final dependencyId in check.dependencies) {
        if (!checkIds.contains(dependencyId)) {
          throw StateError(
            'Unknown verification check dependency: ${check.id} -> $dependencyId',
          );
        }
      }
    }
    _validateDependencyGraph(registeredChecks);

    final sortedChecks = registeredChecks.toList()
      ..sort((left, right) => left.id.value.compareTo(right.id.value));
    this.checks = List<VerificationCheckDefinition>.unmodifiable(sortedChecks);
    _checksById = <VerificationCheckId, VerificationCheckDefinition>{
      for (final check in sortedChecks) check.id: check,
    };
    _checksBySuite = <VerificationSuiteId, List<VerificationCheckDefinition>>{
      for (final suiteId in supportedVerificationSuiteIds)
        suiteId: List<VerificationCheckDefinition>.unmodifiable(
          sortedChecks.where((check) => check.suites.contains(suiteId)),
        ),
    };
  }

  late final List<VerificationCheckDefinition> checks;
  late final Map<VerificationCheckId, VerificationCheckDefinition> _checksById;
  late final Map<VerificationSuiteId, List<VerificationCheckDefinition>>
  _checksBySuite;

  VerificationCheckDefinition checkById(VerificationCheckId checkId) {
    final check = _checksById[checkId];
    if (check == null) {
      throw StateError('Unknown verification check ID: $checkId');
    }
    return check;
  }

  bool containsCheck(VerificationCheckId checkId) =>
      _checksById.containsKey(checkId);

  List<VerificationCheckDefinition> checksForSuite(
    VerificationSuiteId suiteId,
  ) {
    return _checksBySuite[suiteId] ?? const <VerificationCheckDefinition>[];
  }
}

enum _DependencyVisitState { visiting, visited }

void _validateDependencyGraph(List<VerificationCheckDefinition> checks) {
  final checksById = <VerificationCheckId, VerificationCheckDefinition>{
    for (final check in checks) check.id: check,
  };
  final states = <VerificationCheckId, _DependencyVisitState>{};
  final path = <VerificationCheckId>[];

  void visit(VerificationCheckId checkId) {
    final state = states[checkId];
    if (state == _DependencyVisitState.visited) {
      return;
    }
    if (state == _DependencyVisitState.visiting) {
      final cycleStart = path.indexOf(checkId);
      final cycle = <VerificationCheckId>[...path.sublist(cycleStart), checkId];
      throw StateError(
        'Verification check dependency cycle: ${cycle.join(' -> ')}',
      );
    }

    states[checkId] = _DependencyVisitState.visiting;
    path.add(checkId);
    for (final dependencyId in checksById[checkId]!.dependencies) {
      visit(dependencyId);
    }
    path.removeLast();
    states[checkId] = _DependencyVisitState.visited;
  }

  for (final check in checks) {
    visit(check.id);
  }
}
