{{/*
Expand the name of the chart.
*/}}
{{- define "nebari-landing.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "nebari-landing.fullname" -}}
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
Chart label.
*/}}
{{- define "nebari-landing.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to every resource.
*/}}
{{- define "nebari-landing.labels" -}}
helm.sh/chart: {{ include "nebari-landing.chart" . }}
app.kubernetes.io/name: {{ include "nebari-landing.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels for the frontend Deployment / Service.
*/}}
{{- define "nebari-landing.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nebari-landing.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: frontend
{{- end }}

{{/*
Selector labels for the webapi Deployment / Service.
*/}}
{{- define "nebari-landing.webapi.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nebari-landing.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: webapi
{{- end }}

{{/*
webapi ServiceAccount name.
*/}}
{{- define "nebari-landing.webapi.serviceAccountName" -}}
{{- if .Values.webapi.serviceAccount.create }}
{{- default (printf "%s-webapi" (include "nebari-landing.fullname" .)) .Values.webapi.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.webapi.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Redis address (host:port) derived from the subchart service name.
Uses the Bitnami standalone service naming convention.
*/}}
{{- define "nebari-landing.redisAddr" -}}
{{- printf "%s-redis-master:6379" .Release.Name }}
{{- end }}
