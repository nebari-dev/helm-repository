#!/usr/bin/env bash
# The chart must render the same bytes every time: Argo CD renders with helm
# template, and anything random or looked up would change on every sync.
set -euo pipefail
cd "$(dirname "$0")/../.."
a=$(helm template t chart/ -f tests/e2e/ci-values.yaml)
b=$(helm template t chart/ -f tests/e2e/ci-values.yaml)
diff <(printf '%s\n' "$a") <(printf '%s\n' "$b")
echo deterministic
