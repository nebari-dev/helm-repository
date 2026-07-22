#!/usr/bin/env bash
# Template-rendering assertions for both Mimir modes (monolithic default,
# distributed opt-in). Pure `helm template` — no cluster required.
# Prerequisite: helm dependency update chart
set -euo pipefail

CHART="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "ASSERT FAIL: $1" >&2; exit 1; }

# assert_contains <var-name> <pattern> <message>
assert_contains() {
  if ! grep -q -- "$2" <<<"${!1}"; then fail "$3"; fi
}

# assert_not_contains <var-name> <pattern> <message>
assert_not_contains() {
  if grep -q -- "$2" <<<"${!1}"; then fail "$3"; fi
}

echo "== rendering default (monolithic) mode =="
DEFAULT_OUT="$(helm template test "$CHART" --namespace default --set nebariapp.enabled=false)"

echo "== rendering distributed mode =="
DIST_OUT="$(helm template test "$CHART" --namespace default --set nebariapp.enabled=false \
  --set mimir-distributed.enabled=true)"

# --- Mode toggle: exactly one Mimir topology renders per mode ---
assert_not_contains DEFAULT_OUT 'name: test-mimir-ingester' \
  "default mode must not render mimir-distributed components"
assert_contains DIST_OUT 'name: test-mimir-ingester' \
  "distributed mode must render mimir-distributed components"
assert_contains DIST_OUT 'name: test-mimir-gateway' \
  "distributed mode must render the mimir gateway"

# --- Monolithic Mimir (default) ---
assert_contains DEFAULT_OUT 'serviceName: test-mimir$' \
  "default mode must render the monolithic Mimir StatefulSet"
assert_contains DEFAULT_OUT 'name: test-mimir-config' \
  "default mode must render the monolithic Mimir ConfigMap"
assert_contains DEFAULT_OUT 'compactor_blocks_retention_period: 30d' \
  "monolithic config must bound retention (issue #22)"
assert_contains DEFAULT_OUT 'checksum/config' \
  "monolithic StatefulSet must roll on config changes"
assert_contains DEFAULT_OUT 'rule_path: /data/ruler' \
  "monolithic ruler workdir must be on the data volume (startup crash otherwise)"
assert_not_contains DIST_OUT 'serviceName: test-mimir$' \
  "distributed mode must not render the monolithic StatefulSet"

# --- Distributed mode: shared object store, no filesystem "buckets" ---
assert_contains DIST_OUT 'name: test-minio' \
  "distributed mode must deploy the bundled MinIO"
assert_contains DIST_OUT 'bucket_name: mimir-tsdb' \
  "distributed blocks storage must point at the MinIO bucket"
assert_not_contains DIST_OUT 'dir: /data/mimir-blocks' \
  "distributed mode must not use filesystem blocks storage (issue #22)"
assert_contains DIST_OUT 'compactor_blocks_retention_period: 30d' \
  "distributed config must bound retention (issue #22)"

# --- Mode-aware endpoints ---
assert_contains DEFAULT_OUT 'url: http://test-mimir:8080/prometheus' \
  "default datasource must point at the monolithic Mimir service"
assert_contains DEFAULT_OUT 'endpoint: http://test-mimir.default.svc.cluster.local:8080/otlp' \
  "default OTel exporter must point at the monolithic Mimir service"
assert_not_contains DEFAULT_OUT 'test-mimir-gateway' \
  "default mode must not reference the distributed gateway anywhere"
assert_contains DIST_OUT 'url: http://test-mimir-gateway:80/prometheus' \
  "distributed datasource must point at the mimir gateway"
assert_contains DIST_OUT 'endpoint: http://test-mimir-gateway.default.svc.cluster.local:80/otlp' \
  "distributed OTel exporter must point at the mimir gateway"

echo "== rendering with all Mimir disabled =="
NO_MIMIR_OUT="$(helm template test "$CHART" --namespace default --set nebariapp.enabled=false \
  --set mimir.enabled=false)"
assert_not_contains NO_MIMIR_OUT 'name: Mimir' \
  "with no Mimir enabled, the Grafana Mimir datasource must be omitted"

echo "All rendering assertions passed."
