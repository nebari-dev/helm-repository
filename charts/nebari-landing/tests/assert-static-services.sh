#!/usr/bin/env bash
# Renders the chart with the static-services settings and checks the
# STATIC_SERVICES env the webapi receives (see the nebari-landing.staticServices
# helper). Requires helm and jq; run after `helm dependency build`.
set -euo pipefail

chart="$(cd "$(dirname "$0")/.." && pwd)"
# Shared with the Go tests in internal/staticservices, so a change to the JSON
# the chart renders and a change to what the webapi accepts fail together.
golden="$chart/../../internal/staticservices/testdata/chart-keycloak.json"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Prints the decoded STATIC_SERVICES JSON, or nothing when the env is absent.
static_services() {
  helm template nebari-landing "$chart" --namespace nebari-system "$@" \
    | grep -A1 'name: STATIC_SERVICES' \
    | sed -n 's/^ *value: //p' \
    | jq -r .
}

# Expects rendering to fail with a message containing $1.
expect_render_error() {
  local want="$1"
  shift
  local out
  if out=$(helm template nebari-landing "$chart" --namespace nebari-system "$@" 2>&1); then
    fail "expected render to fail with \"$want\""
  fi
  grep -qF "$want" <<<"$out" || fail "render error does not mention \"$want\": $out"
}

toggle=(
  --set webapi.keycloak.landingPage.enabled=true
  --set frontend.keycloak.url=https://keycloak.example.com//
  --set webapi.keycloak.url=http://keycloak.keycloak.svc:8080/
)

# Default install: nothing rendered.
[ -z "$(static_services)" ] || fail "STATIC_SERVICES rendered with default values"

# Toggle on: one Keycloak entry derived from the Keycloak settings, matching the
# fixture the Go parser is tested against.
got=$(static_services "${toggle[@]}")
diff <(jq -S . "$golden") <(jq -S . <<<"$got") >/dev/null \
  || fail "Keycloak entry does not match $golden: $got"

# Without webapi.keycloak.url (the chart default) the card renders without a
# probe rather than with a relative probe URL the webapi would reject.
got=$(static_services --set webapi.keycloak.landingPage.enabled=true \
  --set frontend.keycloak.url=https://keycloak.example.com)
jq -e '.[0] | has("healthCheck") | not' <<<"$got" >/dev/null \
  || fail "healthCheck rendered without webapi.keycloak.url: $got"

# Custom entries are kept alongside the Keycloak entry, with the map key as id.
got=$(static_services "${toggle[@]}" \
  --set webapi.staticServices.grafana-admin.url=https://grafana.example.com/admin)
jq -e '[.[].id] == ["grafana-admin", "keycloak"]' <<<"$got" >/dev/null \
  || fail "custom entry not merged: $got"

# Separate value files (NIC overlays) add entries instead of replacing each
# other's, and a null entry removes one.
cat >"$tmp/a.yaml" <<'EOF'
webapi:
  staticServices:
    grafana-admin: {url: "https://grafana.example.com/admin"}
EOF
cat >"$tmp/b.yaml" <<'EOF'
webapi:
  staticServices:
    argo: {url: "https://argo.example.com"}
EOF
cat >"$tmp/c.yaml" <<'EOF'
webapi:
  staticServices:
    grafana-admin: null
EOF
got=$(static_services -f "$tmp/a.yaml" -f "$tmp/b.yaml")
jq -e '[.[].id] == ["argo", "grafana-admin"]' <<<"$got" >/dev/null \
  || fail "value files did not merge: $got"
got=$(static_services -f "$tmp/a.yaml" -f "$tmp/b.yaml" -f "$tmp/c.yaml")
jq -e '[.[].id] == ["argo"]' <<<"$got" >/dev/null \
  || fail "null entry not removed: $got"

# The webapi probes the Keycloak card itself (static checks are trusted and
# skip the probe runner), so its opt-in egress policy must allow the probe
# target: the keycloakx pods on the port in webapi.keycloak.url.
np=$(helm template nebari-landing "$chart" --namespace nebari-system "${toggle[@]}" \
  --show-only templates/webapi/networkpolicy.yaml \
  --set webapi.networkPolicy.enabled=true \
  --set 'webapi.networkPolicy.egress.kubernetesAPI.cidrs={10.0.0.1/32}')
grep -A12 'kubernetes.io/metadata.name: keycloak' <<<"$np" | grep -q 'port: 8080' \
  || fail "webapi NetworkPolicy does not allow the Keycloak card probe on 8080: $np"

# Misconfigurations fail at render time instead of crash-looping the webapi or
# widening the card's audience.
expect_render_error "frontend.keycloak.url is required" \
  --set webapi.keycloak.landingPage.enabled=true
expect_render_error "frontend.keycloak.realm is required" "${toggle[@]}" \
  --set frontend.keycloak.realm=
expect_render_error 'must not define id "keycloak"' "${toggle[@]}" \
  --set webapi.staticServices.keycloak.url=https://keycloak.example.com
expect_render_error "requiredGroups must be a non-empty list" "${toggle[@]}" \
  --set 'webapi.keycloak.landingPage.requiredGroups=null'
expect_render_error "requiredGroups must be a non-empty list" "${toggle[@]}" \
  --set webapi.keycloak.landingPage.requiredGroups=/nebari-admins

echo "static services render assertions passed"
