{{/*
Expand the name of the chart.
*/}}
{{- define "nebari-lgtm-pack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nebari-lgtm-pack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nebari-lgtm-pack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nebari-lgtm-pack.labels" -}}
helm.sh/chart: {{ include "nebari-lgtm-pack.chart" . }}
{{ include "nebari-lgtm-pack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nebari-lgtm-pack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nebari-lgtm-pack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
OIDC client secret name (created by nebari-operator).
Pattern: <fullname>-oidc-client
This helper hardcodes the chart name instead of using .Chart.Name so it
produces the correct name even when evaluated via tpl in subchart context
(where .Chart.Name would be the subchart's name, not the parent's).
*/}}
{{- define "nebari-lgtm-pack.oidc-secret-name" -}}
{{- $chartName := "nebari-lgtm-pack" -}}
{{- if contains $chartName .Release.Name -}}
{{- printf "%s-oidc-client" .Release.Name -}}
{{- else -}}
{{- printf "%s-%s-oidc-client" .Release.Name $chartName -}}
{{- end -}}
{{- end }}

{{/*
Keycloak OIDC base URL for constructing auth/token/userinfo endpoints.
Modern KeycloakX (v17+) uses "/" as the base path by default.
Set nebariapp.keycloakBasePath to "/auth" for legacy Keycloak installations.
*/}}
{{- define "nebari-lgtm-pack.keycloak-oidc-url" -}}
https://{{ .Values.nebariapp.keycloakHostname }}{{ .Values.nebariapp.keycloakBasePath }}/realms/{{ .Values.nebariapp.keycloakRealm | default "nebari" }}/protocol/openid-connect
{{- end }}

{{/*
Monolithic Mimir base configuration. mimir.extraConfig is deep-merged over
this in templates/mimir/configmap.yaml. Filesystem storage is valid here
because a single process owns the single /data volume — unlike distributed
mode, where a filesystem "bucket" is invisible to every other component
(issue #22).
*/}}
{{- define "nebari-lgtm-pack.mimir-monolithic-config" -}}
multitenancy_enabled: false

server:
  http_listen_port: 8080
  grpc_listen_port: 9095

# Classic architecture (no Kafka-backed ingest), matching the distributed
# mode's settings.
ingest_storage:
  enabled: false

# Single-process rings: every component talks to itself.
ingester:
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: memberlist
    replication_factor: 1

distributor:
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: memberlist

store_gateway:
  sharding_ring:
    replication_factor: 1

blocks_storage:
  backend: filesystem
  filesystem:
    dir: /data/blocks
  bucket_store:
    sync_dir: /data/tsdb-sync
  tsdb:
    dir: /data/tsdb

compactor:
  data_dir: /data/compactor
  sharding_ring:
    kvstore:
      store: memberlist

ruler_storage:
  backend: filesystem
  filesystem:
    dir: /data/rules

# The ruler is part of -target=all. Its working directory defaults to
# ./data-ruler/, which is unwritable for the non-root user on a read-only
# root filesystem — Mimir 3.0.1 hard-fails at startup without this.
ruler:
  rule_path: /data/ruler

# Default filepath (./metrics-activity.log) is not writable by the non-root
# container user; keep it on the data volume.
activity_tracker:
  filepath: /data/metrics-activity.log

limits:
  # Bound disk usage — unset means keep blocks forever (issue #22).
  compactor_blocks_retention_period: {{ .Values.mimir.retention }}
{{- end }}

{{/*
Mimir service host and port — switch between the chart's monolithic Service
and the mimir-distributed gateway based on which mode is enabled. Consumers
build URLs as http://<host>:<port>/... (Grafana datasource, OTel exporter).
*/}}
{{- define "nebari-lgtm-pack.mimir-host" -}}
{{- if index .Values "mimir-distributed" "enabled" -}}
{{- .Release.Name }}-mimir-gateway
{{- else -}}
{{- .Release.Name }}-mimir
{{- end -}}
{{- end }}

{{- define "nebari-lgtm-pack.mimir-port" -}}
{{- if index .Values "mimir-distributed" "enabled" -}}80{{- else -}}8080{{- end -}}
{{- end }}

{{/*
Truthy when any Mimir (monolithic or distributed) is part of this install;
empty string otherwise, so it can be used directly in `if` conditions.
*/}}
{{- define "nebari-lgtm-pack.mimir-enabled" -}}
{{- if or .Values.mimir.enabled (index .Values "mimir-distributed" "enabled") -}}true{{- end -}}
{{- end }}
