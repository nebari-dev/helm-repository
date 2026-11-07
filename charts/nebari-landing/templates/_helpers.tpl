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
Selector labels for the isolated health-prober Deployment / Service.
*/}}
{{- define "nebari-landing.healthProber.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nebari-landing.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: health-prober
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

{{/*
Static landing-page entries as a JSON array for the webapi's STATIC_SERVICES:
webapi.staticServices (a map keyed by id, so value overlays merge entries
instead of replacing the whole set) plus, when
webapi.keycloak.landingPage.enabled, an entry for the Keycloak admin console
derived from the existing Keycloak settings. Entries set to null are skipped,
so an overlay can remove one. Renders an empty string when there are none.
*/}}
{{- define "nebari-landing.staticServices" -}}
{{- $services := list -}}
{{- $kc := .Values.webapi.keycloak.landingPage -}}
{{- if and $kc.enabled (index .Values.webapi.staticServices "keycloak") -}}
{{- fail "webapi.staticServices must not define id \"keycloak\" while webapi.keycloak.landingPage.enabled=true" -}}
{{- end -}}
{{- range $id, $svc := .Values.webapi.staticServices -}}
{{- if $svc -}}
{{- $services = append $services (set (deepCopy $svc) "id" $id) -}}
{{- end -}}
{{- end -}}
{{- if $kc.enabled -}}
{{- $publicURL := regexReplaceAll "/+$" (required "frontend.keycloak.url is required when webapi.keycloak.landingPage.enabled=true" .Values.frontend.keycloak.url) "" -}}
{{- /* One realm for the card and the probe: login only works when the
       frontend and webapi realms match anyway. */ -}}
{{- $realm := required "frontend.keycloak.realm is required when webapi.keycloak.landingPage.enabled=true" .Values.frontend.keycloak.realm -}}
{{- if or (not (kindIs "slice" $kc.requiredGroups)) (not $kc.requiredGroups) -}}
{{- fail "webapi.keycloak.landingPage.requiredGroups must be a non-empty list: an empty list shows the Keycloak card to every signed-in user" -}}
{{- end -}}
{{- $entry := dict
  "id" "keycloak"
  "displayName" $kc.displayName
  "description" $kc.description
  "url" (printf "%s/admin/%s/console/" $publicURL $realm)
  "category" $kc.category
  "priority" $kc.priority
  "visibility" "private"
  "requiredGroups" $kc.requiredGroups
-}}
{{- if $kc.icon -}}
{{- $_ := set $entry "icon" $kc.icon -}}
{{- end -}}
{{- with .Values.webapi.keycloak.url -}}
{{- $_ := set $entry "healthCheck" (dict "url" (printf "%s/realms/%s" (regexReplaceAll "/+$" . "") $realm)) -}}
{{- end -}}
{{- $services = append $services $entry -}}
{{- end -}}
{{- if $services -}}
{{- toJson $services -}}
{{- end -}}
{{- end }}
