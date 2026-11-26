#!/usr/bin/env bash
# Render examples/nebari-values.yaml and check the wiring an operator relies on. The example sets
# no image tags: a released chart pins them (release.yaml tag-paths). The chart in this repo has
# no pinned tags, so this fills them with --set.
# Needs helm, jq and yq (mikefarah).
set -euo pipefail
cd "$(dirname "$0")/../.."

fills=(--set image.tag=wiring-test --set tools.image.tag=wiring-test)
render() { helm template mem0 chart/ -n mem0 -f examples/nebari-values.yaml "${fills[@]}"; }

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f examples/nebari-values.yaml ] || fail "examples/nebari-values.yaml does not exist"

out=$(render)
docs=$(printf '%s\n' "$out" | yq -o=json '.' | jq -s '.')

# The caller grant names the ServiceAccount of Tapas's gateway pod (sqlite default), and nothing else.
subjects=$(jq -c '[.[] | select(.kind == "RoleBinding" and (.metadata.name | endswith("-admin-key-reader"))) | .subjects[] | [.kind, .namespace, .name]]' <<<"$docs")
[ "$subjects" = '[["ServiceAccount","javo","javo-controller"]]' ] \
  || fail "role binding subjects are $subjects"

# The server NetworkPolicy admits only the Tapas gateway pods on 8000.
jq -e '[.[] | select(.kind == "NetworkPolicy") | select(.spec.policyTypes | index("Ingress"))
  | .spec.ingress[]? | select(.ports[0].port == 8000) | .from[]
  | select(.namespaceSelector.matchLabels["kubernetes.io/metadata.name"] == "javo"
    and .podSelector.matchLabels["app.kubernetes.io/name"] == "javo"
    and .podSelector.matchLabels["app.kubernetes.io/component"] == "gateway")] | length == 1' \
  <<<"$docs" >/dev/null || fail "no NetworkPolicy ingress rule for the javo gateway pods"

deploy=$(jq -c '.[] | select(.kind == "Deployment")' <<<"$docs")

# The server container never sees the client secret: no reference to the model-client Secret,
# its volume or the client-secret key. Only the token-proxy init container mounts it.
jq -e '.spec.template.spec.containers[] | select(.name == "server")
  | [.env[]?, .envFrom[]?, .volumeMounts[]?] | tostring | test("model-client|client-secret|client-id") | not' \
  <<<"$deploy" >/dev/null || fail "server container references the model client Secret"
jq -e '.spec.template.spec.initContainers[] | select(.name == "token-proxy")
  | .volumeMounts | map(.name) | index("model-client")' <<<"$deploy" >/dev/null \
  || fail "token-proxy does not mount the model client Secret"

# mem0's OpenAI base URL is the in-pod token proxy, not the model endpoint or api.openai.com.
base=$(jq -r '.spec.template.spec.containers[] | select(.name == "server")
  | .env[] | select(.name == "OPENAI_BASE_URL") | .value' <<<"$deploy")
[ "$base" = "http://127.0.0.1:8081/v1" ] || fail "OPENAI_BASE_URL is '$base'"

# Both images are pinned (tag or digest) and neither is :latest.
images=$(jq -r '.spec.template.spec | [.containers[], .initContainers[]] | .[].image' <<<"$deploy")
while read -r img; do
  case "$img" in
    *:latest | "") fail "image '$img' is not pinned" ;;
    *@sha256:* | *:?*) ;;
    *) fail "image '$img' is not pinned" ;;
  esac
done <<<"$images"

# GitOps-safe: a second render is byte-identical.
[ "$out" = "$(render)" ] || fail "two renders differ"

echo "PASS: values wiring"
