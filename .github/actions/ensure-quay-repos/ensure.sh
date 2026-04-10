#!/usr/bin/env bash
#
# Ensure quay.io OCI chart repositories exist and are public.
#
# This script ONLY manages repositories under <namespace>/<repo-prefix>/,
# e.g. nebari/charts/*. It will never modify repositories outside that
# prefix — the repo path is derived from the chart name in each .tgz and
# always prefixed with QUAY_REPO_PREFIX.
#
# For each packaged Helm chart (.tgz) in the given directory:
#   - Missing  → created as public via POST /api/v1/repository
#   - Private  → changed to public via POST .../changevisibility
#   - Public   → skipped (no-op)
#
# Environment variables (required):
#   QUAY_API_TOKEN   — OAuth application token with repo:create + repo:admin scopes
#   QUAY_NAMESPACE   — quay.io organisation (e.g. "nebari")
#   QUAY_REPO_PREFIX — repository path prefix (e.g. "charts")
#
# Usage:
#   ensure.sh <packaged-dir>

set -euo pipefail

PACKAGED_DIR="${1:?Usage: ensure.sh <packaged-dir>}"

: "${QUAY_API_TOKEN:?QUAY_API_TOKEN is required}"
: "${QUAY_NAMESPACE:?QUAY_NAMESPACE is required}"
: "${QUAY_REPO_PREFIX:?QUAY_REPO_PREFIX is required}"

API_BASE="https://quay.io/api/v1"
AUTH_HEADER="Authorization: Bearer ${QUAY_API_TOKEN}"

for tgz in "${PACKAGED_DIR}"/*.tgz; do
  [ -f "$tgz" ] || continue

  chart_name=$(helm show chart "$tgz" | awk '/^name:/{print $2}')

  # Guard: only operate on repos within the expected prefix.
  # Reject chart names containing slashes or path traversal sequences
  # to prevent accidentally targeting repos outside <prefix>/<name>.
  if [[ "$chart_name" == */* ]] || [[ "$chart_name" == *..* ]] || [[ -z "$chart_name" ]]; then
    echo "  !! skipping '${chart_name}' — unexpected chart name" >&2
    continue
  fi

  repo_name="${QUAY_REPO_PREFIX}/${chart_name}"
  # Quay API expects slashes in repo names to be URL-encoded
  encoded_repo="${QUAY_REPO_PREFIX}%2F${chart_name}"
  api_url="${API_BASE}/repository/${QUAY_NAMESPACE}/${encoded_repo}"

  echo "Checking quay.io/${QUAY_NAMESPACE}/${repo_name} ..."

  http_code=$(curl -s -o /tmp/quay-repo-check.json -w "%{http_code}" \
    -H "${AUTH_HEADER}" "${api_url}")

  if [ "$http_code" = "200" ]; then
    is_public=$(python3 -c "import json; print(json.load(open('/tmp/quay-repo-check.json')).get('is_public', False))")
    if [ "$is_public" = "True" ]; then
      echo "  -> exists and is public."
    else
      echo "  -> exists but is private, changing to public..."
      curl -sf -X POST \
        -H "${AUTH_HEADER}" \
        -H "Content-Type: application/json" \
        -d '{"visibility": "public"}' \
        "${api_url}/changevisibility"
      echo "  -> done."
    fi
  else
    echo "  -> not found (HTTP ${http_code}), creating as public..."
    curl -sf -X POST \
      -H "${AUTH_HEADER}" \
      -H "Content-Type: application/json" \
      -d "{\"namespace\":\"${QUAY_NAMESPACE}\",\"repository\":\"${repo_name}\",\"visibility\":\"public\",\"description\":\"Helm chart for ${chart_name}\",\"repo_kind\":\"image\"}" \
      "${API_BASE}/repository"
    echo "  -> created."
  fi
done
