{{/* Expand the name of the chart. */}}
{{- define "pack-testbed.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name (truncated to 63 chars for DNS).
If the release name contains the chart name it is used as-is.
*/}}
{{- define "pack-testbed.fullname" -}}
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

{{/* Chart name and version for the chart label. */}}
{{- define "pack-testbed.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels */}}
{{- define "pack-testbed.labels" -}}
helm.sh/chart: {{ include "pack-testbed.chart" . }}
{{ include "pack-testbed.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels */}}
{{- define "pack-testbed.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pack-testbed.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
