## Context

The repository currently has a split release-governance model. The release workflow is already fundamentally tag-driven: it triggers on version tags, derives the manifest version from `TAG_NAME`, publishes GitHub release assets under the tag URL, and validates external consumer behavior against tag-based refs. At the same time, `scripts/workspace_tools.dart` still treats aligned `pubspec.yaml` versions as a second release authority and hard-fails publication when a tag does not match the workspace package versions.

That dual-authority model no longer matches the actual release pipeline. It increases release friction, causes valid tag-driven releases to fail for metadata drift that does not affect artifact correctness, and obscures which identifier external consumers should treat as authoritative. The current failure mode on `v1.0.2` illustrated the mismatch clearly: native assets built successfully, but publication stopped because package metadata remained on `1.0.1`.

The release workflow should instead have one release authority: the Git tag that triggered the run. Package versions can remain as package metadata for development and package inspection, but they should not block tag-based publication unless a separate governance rule intentionally requires that in the future.

## Goals / Non-Goals

**Goals:**
- Make Git tags the single authoritative release identity for release publication.
- Remove hard release gating that requires tag and aligned package versions to match.
- Keep artifact-consistency and external-consumer verification as the real publication guards.
- Preserve tag-derived manifest versioning and release URL generation.
- Update workflow tests and specs so repository policy reflects tag-authoritative release governance.

**Non-Goals:**
- Removing `version` fields from `pubspec.yaml` files.
- Redesigning native asset packaging, manifest schema, or consumer dependency shape.
- Changing normal CI merge-blocking verification for development-path, artifact-consistency, or external-consumer flows.
- Changing how tags are named beyond the existing `v*` convention.

## Decisions

### 1. Git tag becomes the sole release authority
The release workflow will treat `github.ref_name` as the single release identity for publication. Manifest versioning, GitHub release URLs, and tag-consumer verification already derive from the tag, so the workflow should stop requiring package metadata to act as a second release authority.

**Why this over keeping dual authority?**
Dual authority has already drifted from actual release mechanics. The workflow trusts the tag for artifact publication but still blocks on package metadata mismatch, which creates failures unrelated to release correctness.

### 2. Release publication keeps contract verification, not metadata gating
The release workflow will continue running artifact-consistency and consumer-path verification before publishing assets. The hard gate that compares tag version to aligned package versions will be removed or downgraded so only contract-relevant checks block publication.

**Why this over removing all checks?**
The problem is not that release verification exists; the problem is that metadata alignment is currently treated as if it were equivalent to contract correctness. Artifact and consumer verification still protect real user-facing behavior.

### 3. Workspace version alignment becomes advisory instead of release-blocking
The repository may still keep utilities or documentation that inspect workspace version alignment, but they should no longer define release success for tag-triggered publication.

**Why this over deleting alignment logic entirely?**
Aligned versions may still be useful for housekeeping, package metadata review, or future release-train reporting. The key change is that they stop blocking tag-based publication.

### 4. Specs and workflow tests must say the same thing as the pipeline
OpenSpec requirements, workflow assertions, and script tests must be updated together so the repository no longer encodes a hidden dual-authority model.

**Why this over only changing the workflow?**
If tests and specs continue to require tag-version equality, the repository will drift again and future maintainers will reintroduce the same release friction.

## Risks / Trade-offs

- **[Risk]** Package versions may drift for longer and create confusion for maintainers reading `pubspec.yaml`.  
  **Mitigation:** keep package versions as metadata and document that release authority is the Git tag.

- **[Risk]** Some tooling may still implicitly assume package version equals release tag.  
  **Mitigation:** audit workflow tests and release-governance scripts for those assumptions as part of the change.

- **[Risk]** Removing the hard gate could hide a useful signal about release-train hygiene.  
  **Mitigation:** keep version-alignment logic as advisory or separate diagnostics rather than publication gating.

- **[Risk]** Consumers or maintainers may misread the change as allowing arbitrary tag publication without verification.  
  **Mitigation:** preserve artifact-consistency and consumer-path checks as mandatory release gates and make that explicit in specs.

## Migration Plan

1. Update release-governance specs to define tag-authoritative publication and remove package-version release gating as a required release contract.
2. Update `scripts/workspace_tools.dart` so `check-release-train` no longer blocks tag-triggered publication on package-version mismatch.
3. Update `.github/workflows/release-native-assets.yml` to stop using version-alignment as a required publish gate while keeping artifact and consumer verification.
4. Update workflow and script tests to reflect tag-first release governance.
5. Validate a tagged release path to confirm publication still derives manifest metadata and release URLs from the tag.

Rollback is straightforward before merge: restore the workflow gate and matching spec/test expectations. After merge, rollback should only happen if another part of the release system is discovered to require package-version equality for correctness rather than metadata hygiene.

## Open Questions

- Should `check-release-train` be removed entirely, or kept as a non-blocking diagnostic command?
- Should documentation explicitly say “Git tag is authoritative; package versions are metadata,” or is it enough to encode that in workflow/spec behavior?
- Do any downstream scripts outside this repository consume package version as if it were the release identity?
