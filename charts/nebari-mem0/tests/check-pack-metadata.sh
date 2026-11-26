#!/usr/bin/env bash
# Validate pack-metadata.yaml against the published schema.
# The schema lives in the private software-pack-dashboard repo, so unauthenticated
# CI cannot fetch it (404). In that case fall back to a basic YAML-parse +
# required-keys check (kept in sync with the schema's required list) and warn
# rather than failing.
set -euo pipefail

SCHEMA_URL="https://raw.githubusercontent.com/nebari-dev/software-pack-dashboard/main/schema/pack-metadata.schema.json"
METADATA_FILE="${1:-$(dirname "$0")/../../pack-metadata.yaml}"

schema_file=$(mktemp)
code=$(curl -sL -o "$schema_file" -w '%{http_code}' "$SCHEMA_URL")

if [ "$code" = "200" ]; then
    echo "Schema published; validating strictly with check-jsonschema."
    check-jsonschema --schemafile "$schema_file" "$METADATA_FILE"
else
    echo "::warning::pack-metadata schema not published (HTTP $code) - falling back to basic checks"
    python3 - "$METADATA_FILE" <<'PY'
import sys, yaml

path = sys.argv[1]
d = yaml.safe_load(open(path))

# Mirrors the published schema's required list (schema/pack-metadata.schema.json
# in software-pack-dashboard), plus the fields this pack relies on.
required = ["name", "display_name", "level", "owner", "deprecated",
            "nebariapp_integration", "scope"]
missing = [k for k in required if k not in d]
assert not missing, f"missing required keys: {missing}"

valid_levels = {"experimental", "alpha", "beta", "ga"}
assert d["level"] in valid_levels, f"bad level: {d['level']} (must be one of {valid_levels})"

assert "standalone-supported" in d.get("scope", {}), "scope.standalone-supported missing"

print(f"pack-metadata basic checks passed: {d['name']} ({d['level']})")
PY
fi
