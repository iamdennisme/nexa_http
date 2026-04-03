#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/build_native_common.sh"

require_command git
require_command gh
require_command python3

REMOTE='origin'
BRANCH='develop'
WORKFLOW='release-native-assets.yml'
TIMEOUT_SECONDS=1800
POLL_SECONDS=5
PUSH_BRANCH=1
RESET_TAG=0
TAG=''
COMMAND='run'

usage() {
  cat <<'EOF'
Usage: ./scripts/tag_release_validation.sh <run|publish|wait|delete-tag> --tag <tag> [options]

Commands:
  run         Push branch (default), recreate tag if requested, push tag, then wait for workflow
  publish     Push branch (default), recreate tag if requested, and push tag
  wait        Wait for the tag-triggered workflow run for the tag's current commit
  delete-tag  Delete the tag locally and on the remote if present

Options:
  --tag <tag>                 Required. Example: v1.0.1
  --remote <remote>           Git remote to use (default: origin)
  --branch <branch>           Branch to push before tagging (default: develop)
  --workflow <workflow>       Workflow file/name to watch (default: release-native-assets.yml)
  --timeout-seconds <n>       Wait timeout for workflow detection/completion (default: 1800)
  --poll-seconds <n>          Poll interval while locating workflow run (default: 5)
  --skip-branch-push          Do not push branch before tagging
  --reset-tag                 Delete local/remote copies of the tag before recreating it
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    run|publish|wait|delete-tag)
      COMMAND="$1"
      shift
      ;;
    --tag)
      TAG="${2:?missing tag value}"
      shift 2
      ;;
    --remote)
      REMOTE="${2:?missing remote value}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:?missing branch value}"
      shift 2
      ;;
    --workflow)
      WORKFLOW="${2:?missing workflow value}"
      shift 2
      ;;
    --timeout-seconds)
      TIMEOUT_SECONDS="${2:?missing timeout value}"
      shift 2
      ;;
    --poll-seconds)
      POLL_SECONDS="${2:?missing poll value}"
      shift 2
      ;;
    --skip-branch-push)
      PUSH_BRANCH=0
      shift
      ;;
    --reset-tag)
      RESET_TAG=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "${TAG}" ]] || {
  usage >&2
  die 'Missing required --tag <tag>.'
}

current_branch() {
  git rev-parse --abbrev-ref HEAD
}

tag_commit_sha() {
  git rev-list -n 1 "${TAG}"
}

push_branch_if_needed() {
  if [[ "${PUSH_BRANCH}" -eq 1 ]]; then
    log "Pushing ${BRANCH} to ${REMOTE}"
    git push "${REMOTE}" "${BRANCH}"
  else
    log "Skipping branch push"
  fi
}

delete_tag_if_present() {
  if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    log "Deleting local tag ${TAG}"
    git tag -d "${TAG}"
  fi

  if git ls-remote --tags "${REMOTE}" "refs/tags/${TAG}" | grep -q .; then
    log "Deleting remote tag ${TAG} from ${REMOTE}"
    git push "${REMOTE}" ":refs/tags/${TAG}"
  fi
}

create_and_push_tag() {
  local head_sha
  head_sha="$(git rev-parse HEAD)"
  log "Creating annotated tag ${TAG} at ${head_sha}"
  git tag -a "${TAG}" -m "Validate ${TAG}"
  log "Pushing tag ${TAG} to ${REMOTE}"
  git push "${REMOTE}" "refs/tags/${TAG}"
}

find_run_id_for_tag_commit() {
  local sha="$1"
  local json
  json="$(gh run list --workflow "${WORKFLOW}" --limit 20 --json databaseId,headSha,event,status,conclusion,url,displayTitle,createdAt)"
  python3 - "$sha" <<'PY' <<<"${json}"
import json, sys
sha = sys.argv[1]
runs = json.load(sys.stdin)
for run in runs:
    if run.get('event') == 'push' and run.get('headSha') == sha:
        print(run['databaseId'])
        break
PY
}

wait_for_workflow() {
  local started_at run_id sha now
  sha="$(tag_commit_sha)"
  started_at="$(date +%s)"
  log "Waiting for workflow ${WORKFLOW} for ${TAG} at ${sha}"

  while true; do
    run_id="$(find_run_id_for_tag_commit "${sha}")"
    if [[ -n "${run_id}" ]]; then
      log "Watching workflow run ${run_id}"
      gh run watch "${run_id}" --exit-status --interval 10
      return 0
    fi

    now="$(date +%s)"
    if (( now - started_at >= TIMEOUT_SECONDS )); then
      die "Timed out waiting for workflow ${WORKFLOW} for tag ${TAG}."
    fi
    sleep "${POLL_SECONDS}"
  done
}

case "${COMMAND}" in
  delete-tag)
    delete_tag_if_present
    ;;
  publish)
    [[ "$(current_branch)" == "${BRANCH}" ]] || die "Current branch must be ${BRANCH} before publish."
    push_branch_if_needed
    if [[ "${RESET_TAG}" -eq 1 ]]; then
      delete_tag_if_present
    fi
    create_and_push_tag
    ;;
  wait)
    wait_for_workflow
    ;;
  run)
    [[ "$(current_branch)" == "${BRANCH}" ]] || die "Current branch must be ${BRANCH} before run."
    push_branch_if_needed
    if [[ "${RESET_TAG}" -eq 1 ]]; then
      delete_tag_if_present
    fi
    create_and_push_tag
    wait_for_workflow
    ;;
  *)
    die "Unsupported command: ${COMMAND}"
    ;;
esac
