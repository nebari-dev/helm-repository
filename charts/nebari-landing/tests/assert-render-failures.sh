#!/usr/bin/env bash
# Asserts that unsafe value combinations fail `helm template` with a clear
# message instead of rendering a broken manifest. Run from the repo root after
# `helm dependency build charts/nebari-landing`.
set -euo pipefail

CHART="${CHART:-charts/nebari-landing}"
failures=0

# expect_render_failure <description> <expected message substring> <helm args...>
expect_render_failure() {
  local description="$1" expected="$2"
  shift 2
  local output
  if output="$(helm template nebari-landing "$CHART" --namespace nebari-system "$@" 2>&1)"; then
    echo "FAIL: ${description}: render succeeded, expected failure" >&2
    failures=$((failures + 1))
    return
  fi
  if [[ "$output" != *"$expected"* ]]; then
    echo "FAIL: ${description}: render failed without the expected message" >&2
    echo "  expected substring: ${expected}" >&2
    echo "  got: ${output}" >&2
    failures=$((failures + 1))
    return
  fi
  echo "ok: ${description}"
}

# helm template (and ArgoCD) cannot use lookup(), so enabling the webapi egress
# policy without API-server CIDRs must fail instead of cutting off the watcher.
expect_render_failure \
  "webapi NetworkPolicy enabled without Kubernetes API CIDRs" \
  "webapi.networkPolicy.enabled=true requires webapi.networkPolicy.egress.kubernetesAPI.cidrs" \
  --set webapi.networkPolicy.enabled=true

if ((failures > 0)); then
  exit 1
fi
