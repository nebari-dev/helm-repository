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
