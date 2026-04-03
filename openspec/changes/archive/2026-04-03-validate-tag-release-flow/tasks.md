## 1. Define Governed Tag Validation Workflow

- [x] 1.1 Identify the exact repository-owned commands, workflows, and remote operations that participate in test-tag validation from `develop`.
- [x] 1.2 Document which steps are local-only versus shared-state mutations, including push, remote tag deletion, and tag republish.
- [x] 1.3 Define the success criteria for a governed test tag, including which tag-triggered GitHub Actions must complete successfully before consumer verification begins.

## 2. Implement Retryable Tag Validation Flow

- [x] 2.1 Add or update repository automation/instructions so a maintainer can publish a governed release tag (for example `v1.0.1`), inspect the triggered workflows, and detect success or failure deterministically.
- [x] 2.2 Implement the repair-and-retry path so a failed tag run can be fixed, the governed local/remote tag can be deleted, and the same governed tag can be recreated at the corrected commit.
- [x] 2.3 Ensure the workflow stops retrying only when required tag-triggered workflows succeed or the maintainer explicitly stops the run.

## 3. Add External Tag Consumer Verification

- [x] 3.1 Define and automate creation of a temporary external Flutter demo outside the repository for tag validation.
- [x] 3.2 Configure the temporary demo to depend on `packages/nexa_http` through `pubspec.yaml` using the repository git+ssh URL, `ref` set to the governed release tag, and `path: packages/nexa_http`.
- [x] 3.3 Run the minimum governed external-consumer verification step for that temporary demo and delete the demo after verification completes.

## 4. Finalize Contract And Validate End To End

- [x] 4.1 Update repository-owned documentation or scripts so the governed tag-validation flow is discoverable and repeatable.
- [x] 4.2 Execute the governed release-tag validation loop end to end, including workflow observation, retry if needed, and external consumer proof.
