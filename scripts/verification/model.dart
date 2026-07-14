import 'dart:io';

import 'package:nexa_http_native_internal/nexa_http_native_internal.dart';

final class VerificationCheckId {
  const VerificationCheckId(this.value);

  final String value;

  @override
  bool operator ==(Object other) {
    return other is VerificationCheckId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class VerificationSuiteId {
  const VerificationSuiteId(this.value);

  static const verifyStatic = VerificationSuiteId('verify-static');
  static const verifyIntegration = VerificationSuiteId('verify-integration');
  static const verifyReleaseCandidate = VerificationSuiteId(
    'verify-release-candidate',
  );

  final String value;

  @override
  bool operator ==(Object other) {
    return other is VerificationSuiteId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

const supportedVerificationSuiteIds = <VerificationSuiteId>[
  VerificationSuiteId.verifyStatic,
  VerificationSuiteId.verifyIntegration,
  VerificationSuiteId.verifyReleaseCandidate,
];

final class VerificationExecutionId {
  const VerificationExecutionId(this.value);

  final String value;

  @override
  bool operator ==(Object other) {
    return other is VerificationExecutionId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class VerificationRunner {
  const VerificationRunner(this.value);

  final String value;

  @override
  bool operator ==(Object other) {
    return other is VerificationRunner && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class VerificationExecutionKey {
  const VerificationExecutionKey({
    required this.checkId,
    required this.executionId,
  });

  final VerificationCheckId checkId;
  final VerificationExecutionId executionId;

  String get value => '${checkId.value}@${executionId.value}';

  @override
  bool operator ==(Object other) {
    return other is VerificationExecutionKey &&
        other.checkId == checkId &&
        other.executionId == executionId;
  }

  @override
  int get hashCode => Object.hash(checkId, executionId);

  @override
  String toString() => value;
}

final class VerificationResourceKey {
  const VerificationResourceKey(this.value);

  final String value;

  @override
  bool operator ==(Object other) {
    return other is VerificationResourceKey && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class VerificationRunContext {
  VerificationRunContext(this.executionId);

  final VerificationExecutionId executionId;
  final Map<VerificationResourceKey, Future<Object?>> _resources =
      <VerificationResourceKey, Future<Object?>>{};

  static const _preparedArtifactIdentitiesKey = VerificationResourceKey(
    'prepared-native-artifact-identities',
  );
  static const _runtimePayloadProofsKey = VerificationResourceKey(
    'runtime-native-payload-proofs',
  );

  Future<T> memoize<T>(
    VerificationResourceKey key,
    Future<T> Function() producer,
  ) {
    final existing = _resources[key];
    if (existing != null) {
      return existing.then((value) => value as T);
    }

    final created = producer();
    _resources[key] = created;
    return created;
  }

  Future<List<VerifiedNativeArtifactIdentity>>
  producePreparedArtifactIdentities(
    Future<List<VerifiedNativeArtifactIdentity>> Function() producer,
  ) {
    return memoize(
      _preparedArtifactIdentitiesKey,
      () async =>
          List<VerifiedNativeArtifactIdentity>.unmodifiable(await producer()),
    );
  }

  Future<List<VerifiedNativeArtifactIdentity>>
  requirePreparedArtifactIdentities() {
    final prepared = _resources[_preparedArtifactIdentitiesKey];
    if (prepared == null) {
      throw StateError(
        'Prepared native artifact identities are not available for '
        '$executionId',
      );
    }
    return prepared.then(
      (value) => value! as List<VerifiedNativeArtifactIdentity>,
    );
  }

  Future<List<VerifiedNativeArtifactIdentity>>
  preparedArtifactIdentitiesOrEmpty() async {
    final prepared = _resources[_preparedArtifactIdentitiesKey];
    if (prepared == null) {
      return const <VerifiedNativeArtifactIdentity>[];
    }
    return List<VerifiedNativeArtifactIdentity>.unmodifiable(
      await prepared as List<VerifiedNativeArtifactIdentity>,
    );
  }

  Future<List<T>> produceRuntimePayloadProofs<T>(
    Future<List<T>> Function() producer,
  ) {
    return memoize(
      _runtimePayloadProofsKey,
      () async => List<T>.unmodifiable(await producer()),
    );
  }

  Future<List<T>> runtimePayloadProofsOrEmpty<T>() async {
    final proofs = _resources[_runtimePayloadProofsKey];
    if (proofs == null) {
      return List<T>.empty(growable: false);
    }
    return List<T>.unmodifiable(await proofs as List<T>);
  }
}

final class VerifiedNativeArtifactIdentity {
  const VerifiedNativeArtifactIdentity({
    required this.target,
    required this.file,
    required this.sha256,
    required this.identitySha256,
    required this.sourceIdentity,
  });

  final NexaHttpNativeTarget target;
  final File file;
  final String sha256;
  final String identitySha256;
  final String sourceIdentity;

  String get nativeAssetId => target.nativeAssetId;
}

typedef VerificationCheckAction =
    Future<void> Function(VerificationRunContext context);

final class VerificationCheckDefinition {
  const VerificationCheckDefinition({
    required this.id,
    this.suites = const <VerificationSuiteId>[],
    this.supportedExecutions = const <VerificationExecutionId>[],
    this.dependencies = const <VerificationCheckId>[],
    this.action,
  });

  final VerificationCheckId id;
  final List<VerificationSuiteId> suites;
  final List<VerificationExecutionId> supportedExecutions;
  final List<VerificationCheckId> dependencies;
  final VerificationCheckAction? action;
}
