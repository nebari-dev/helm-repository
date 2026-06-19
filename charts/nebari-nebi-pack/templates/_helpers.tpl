{{/*
Expand the name of the chart.
*/}}
{{- define "nebari-nebi-pack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nebari-nebi-pack.fullname" -}}
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
{{- define "nebari-nebi-pack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nebari-nebi-pack.labels" -}}
helm.sh/chart: {{ include "nebari-nebi-pack.chart" . }}
{{ include "nebari-nebi-pack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nebari-nebi-pack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nebari-nebi-pack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
PostgreSQL selector labels
*/}}
{{- define "nebari-nebi-pack.postgresSelectorLabels" -}}
app.kubernetes.io/name: {{ include "nebari-nebi-pack.name" . }}-postgres
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "nebari-nebi-pack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "nebari-nebi-pack.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
PostgreSQL DSN
*/}}
{{- define "nebari-nebi-pack.postgresDSN" -}}
{{- $host := printf "%s-postgres" (include "nebari-nebi-pack.fullname" .) }}
{{- printf "host=%s port=5432 user=nebi password=$(POSTGRES_PASSWORD) dbname=nebi sslmode=disable" $host }}
{{- end }}

{{/*
Keycloak hostname used to derive the OIDC issuer. Falls back to
keycloak.<base domain of nebariapp.hostname> (the operator convention).
*/}}
{{- define "nebari-nebi-pack.keycloakHostname" -}}
{{- if .Values.keycloak.hostname -}}
{{- .Values.keycloak.hostname -}}
{{- else -}}
{{- printf "keycloak.%s" (.Values.nebariapp.hostname | default "" | splitList "." | rest | join ".") -}}
{{- end -}}
{{- end }}

{{/*
OIDC issuer URL. Uses auth.oidc.issuerURL when set, otherwise derives it from
the Keycloak hostname against the "nebari" realm.
*/}}
{{- define "nebari-nebi-pack.oidcIssuerURL" -}}
{{- if .Values.auth.oidc.issuerURL -}}
{{- .Values.auth.oidc.issuerURL -}}
{{- else -}}
{{- printf "https://%s/realms/nebari" (include "nebari-nebi-pack.keycloakHostname" .) -}}
{{- end -}}
{{- end }}

{{/*
OIDC client ID. Uses auth.oidc.clientID when set, otherwise derives the
operator-provisioned client ID: <release namespace>-<fullname>.
*/}}
{{- define "nebari-nebi-pack.oidcClientID" -}}
{{- if .Values.auth.oidc.clientID -}}
{{- .Values.auth.oidc.clientID -}}
{{- else -}}
{{- printf "%s-%s" .Release.Namespace (include "nebari-nebi-pack.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
OIDC client secret name. Uses auth.oidc.clientSecretName when set, otherwise
derives the operator-provisioned secret: <fullname>-oidc-client.
*/}}
{{- define "nebari-nebi-pack.oidcClientSecretName" -}}
{{- if .Values.auth.oidc.clientSecretName -}}
{{- .Values.auth.oidc.clientSecretName -}}
{{- else -}}
{{- printf "%s-oidc-client" (include "nebari-nebi-pack.fullname" .) -}}
{{- end -}}
{{- end }}
