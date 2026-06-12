{{/*
Expand the name of the chart.
*/}}
{{- define "nebari-langfuse.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name (release-derived). Used for labels only.
*/}}
{{- define "nebari-langfuse.fullname" -}}
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
Stable application name. Pinned (default "langfuse"), NOT release-derived, so the
NebariApp name and the operator-created OIDC secret name (<appName>-oidc-client)
are predictable and can be referenced as literals in the langfuse passthrough.
*/}}
{{- define "nebari-langfuse.appName" -}}
{{- default "langfuse" .Values.nebariapp.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name of the wrapper-generated secret holding salt/encryptionKey/nextauth + datastore passwords.
*/}}
{{- define "nebari-langfuse.secretsName" -}}
{{- printf "%s-secrets" (include "nebari-langfuse.appName" .) }}
{{- end }}

{{- define "nebari-langfuse.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "nebari-langfuse.labels" -}}
helm.sh/chart: {{ include "nebari-langfuse.chart" . }}
{{ include "nebari-langfuse.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "nebari-langfuse.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nebari-langfuse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
