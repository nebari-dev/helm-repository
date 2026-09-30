{{- define "collab-hub.name" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- $name | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "collab-hub.fullname" -}}
{{- $fullname := "" -}}
{{- if .Values.fullnameOverride -}}
{{- $fullname = .Values.fullnameOverride -}}
{{- else -}}
{{- $name := include "collab-hub.name" . -}}
{{- if contains $name .Release.Name -}}
{{- $fullname = .Release.Name -}}
{{- else -}}
{{- $fullname = printf "%s-%s" .Release.Name $name -}}
{{- end -}}
{{- end -}}
{{- $fullname | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "collab-hub.component-name" -}}
{{- $componentName := printf "%s-%s" (include "collab-hub.fullname" .top) .component -}}
{{- $componentName | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "collab-hub.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .top.Chart.Name .top.Chart.Version | replace "+" "-" | quote }}
app.kubernetes.io/name: {{ include "collab-hub.name" .top }}
app.kubernetes.io/instance: {{ .top.Release.Name }}
app.kubernetes.io/managed-by: {{ .top.Release.Service }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "collab-hub.selectorLabels" -}}
app.kubernetes.io/name: {{ include "collab-hub.name" .top }}
app.kubernetes.io/instance: {{ .top.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "collab-hub.frames-storage-claim" -}}
{{- if .Values.frames.storage.persistence.existingClaim -}}
{{- .Values.frames.storage.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-frames" (include "collab-hub.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "collab-hub.api-service-account-name" -}}
{{- if .Values.api.serviceAccount.create -}}
{{- default (include "collab-hub.component-name" (dict "top" . "component" "api")) .Values.api.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.api.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Whether the app enforces the protection map and the restricted CORS default.
Returns the string "true" or "false".

`security.enforce` null follows `api.ingress.enabled`: standalone exposure is
new and is hardened from the start, while an install behind the Nebari gateway
keeps the behavior it has today until its operator opts in explicitly.
*/}}
{{- define "collab-hub.security-enforced" -}}
{{- if kindIs "invalid" .Values.security.enforce -}}
{{- ternary "true" "false" .Values.api.ingress.enabled -}}
{{- else -}}
{{- ternary "true" "false" .Values.security.enforce -}}
{{- end -}}
{{- end -}}

{{/*
Whether uvicorn trusts X-Forwarded-*. Returns "true" or "false".
Null follows the exposure mode, so gateway installs keep today's behavior
(the application default, off) and only ingress exposure turns it on.
*/}}
{{- define "collab-hub.proxy-headers-enabled" -}}
{{- if kindIs "invalid" .Values.server.proxyHeaders -}}
{{- ternary "true" "false" .Values.api.ingress.enabled -}}
{{- else -}}
{{- ternary "true" "false" .Values.server.proxyHeaders -}}
{{- end -}}
{{- end -}}

{{/*
The protection map the app is given: the configured entries plus the
/metrics rule, appended last so it wins by the documented last-equally-specific
precedence and an operator never has to restate the map to open one path.
*/}}
{{- define "collab-hub.security-paths" -}}
{{- $paths := .Values.security.paths | default list -}}
{{- $paths = append $paths (dict "path" "/metrics" "match" "exact" "access" .Values.security.metricsAccess) -}}
{{- toJson $paths -}}
{{- end -}}

{{- define "collab-hub.api-tls-secret-name" -}}
{{- if .Values.api.ingress.tls.secretName -}}
{{- .Values.api.ingress.tls.secretName -}}
{{- else -}}
{{- printf "%s-tls" (include "collab-hub.component-name" (dict "top" . "component" "api")) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
NebariApp helper template.
Expects a dict with keys: top, component, service, nebariapp
*/}}
{{- define "collab-hub.nebariapp" -}}
{{- $top := .top -}}
{{- $component := .component -}}
{{- $service := .service -}}
{{- $nebariapp := .nebariapp -}}
apiVersion: reconcilers.nebari.dev/v1
kind: NebariApp
metadata:
  name: {{ include "collab-hub.component-name" (dict "top" $top "component" $component) }}
  namespace: {{ $top.Release.Namespace }}
  labels:
    {{- include "collab-hub.labels" (dict "top" $top "component" $component) | nindent 4 }}
spec:
  hostname: {{ required (printf "%s.nebariapp.hostname is required" $component) $nebariapp.hostname }}
  service:
    name: {{ $service.name }}
    port: {{ $service.port }}
    {{- with $service.namespace }}
    namespace: {{ . }}
    {{- end }}
  {{- with $nebariapp.serviceAccountName }}
  serviceAccountName: {{ . }}
  {{- end }}
  {{- with $nebariapp.routing }}
  routing:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $nebariapp.auth }}
  auth:
    enabled: {{ .enabled | default false }}
    provider: {{ .provider | default "keycloak" }}
    provisionClient: {{ .provisionClient | default true }}
    {{- if hasKey . "enforceAtGateway" }}
    enforceAtGateway: {{ .enforceAtGateway }}
    {{- end }}
    {{- with .redirectURI }}
    redirectURI: {{ . }}
    {{- end }}
    {{- with .clientSecretRef }}
    clientSecretRef: {{ . }}
    {{- end }}
    {{- with .scopes }}
    scopes:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .groups }}
    groups:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .forwardAccessToken }}
    forwardAccessToken: {{ . }}
    {{- end }}
    {{- with .denyRedirect }}
    denyRedirect:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .issuerURL }}
    issuerURL: {{ . }}
    {{- end }}
    {{- with .spaClient }}
    spaClient:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .deviceFlowClient }}
    deviceFlowClient:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .keycloakConfig }}
    keycloakConfig:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .tokenExchange }}
    tokenExchange:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- end }}
  {{- with $nebariapp.gateway }}
  gateway: {{ . }}
  {{- end }}
  {{- with $nebariapp.landingPage }}
  landingPage:
    enabled: {{ .enabled | default false }}
    {{- with .displayName }}
    displayName: {{ . | quote }}
    {{- end }}
    {{- with .description }}
    description: {{ . | quote }}
    {{- end }}
    {{- with .icon }}
    icon: {{ . | quote }}
    {{- end }}
    {{- with .category }}
    category: {{ . | quote }}
    {{- end }}
    {{- if .priority }}
    priority: {{ .priority }}
    {{- end }}
    {{- with .externalUrl }}
    externalUrl: {{ . | quote }}
    {{- end }}
    {{- with .healthCheck }}
    healthCheck:
      enabled: {{ .enabled | default false }}
      {{- with .path }}
      path: {{ . | quote }}
      {{- end }}
      {{- if .intervalSeconds }}
      intervalSeconds: {{ .intervalSeconds }}
      {{- end }}
      {{- if .timeoutSeconds }}
      timeoutSeconds: {{ .timeoutSeconds }}
      {{- end }}
      {{- if .port }}
      port: {{ .port }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Cog registry (issue #87).

Where the CA bundle ConfigMap is mounted. Fixed rather than configurable: the
path is an implementation detail shared by the volumeMount and every source's
ca_bundle_path, and nothing outside the pod needs to know it.
*/}}
{{- define "collab-hub.cogs-ca-bundle-mount-path" -}}
/etc/collab-hub/cogs-ca
{{- end -}}

{{- define "collab-hub.cogs-ca-bundle-path" -}}
{{- if .Values.cogs.caBundle.configMap -}}
{{- printf "%s/%s" (include "collab-hub.cogs-ca-bundle-mount-path" .) .Values.cogs.caBundle.key -}}
{{- end -}}
{{- end -}}

{{/*
The environment variable a source's Secret key is mounted under. Takes
(dict "id" <source id> "suffix" <USERNAME|PASSWORD|WEBHOOK_SECRET>). The id is
upper-cased and every character outside [A-Z0-9] becomes "_", so the name is
a valid POSIX identifier; cogs-validations.yaml fails the render if two ids
collapse to the same name. config.py reads exactly the names rendered here
(the JSON carries them as credentials.username_env / password_env and
webhook_secret_env), so this template is the single source of the convention.
*/}}
{{- define "collab-hub.cogs-source-env-name" -}}
{{- printf "COLLAB_HUB_COGS_SOURCE_%s_%s" (regexReplaceAll "[^A-Z0-9]" (upper .id) "_") .suffix -}}
{{- end -}}

{{/*
The value of COLLAB_HUB_API__COGS__REGISTRY_SOURCES: the source list as JSON
in the API's snake_case shape, with every empty optional field omitted and
NO secret values — only the env var names the API resolves them from.
pydantic-settings parses list-valued settings from the environment as JSON;
toJson sorts keys, so the rendering is deterministic.
*/}}
{{- define "collab-hub.cogs-registry-sources" -}}
{{- $top := . -}}
{{- $caBundlePath := include "collab-hub.cogs-ca-bundle-path" . -}}
{{- $out := list -}}
{{- range .Values.cogs.registry.sources -}}
{{- $source := dict "id" .id "kind" .kind "url" .url -}}
{{- with .apiUrl }}{{ $_ := set $source "api_url" . }}{{ end -}}
{{- with .tokenUrl }}{{ $_ := set $source "token_url" . }}{{ end -}}
{{- with .projects }}{{ $_ := set $source "projects" . }}{{ end -}}
{{- with .repositories }}{{ $_ := set $source "repositories" . }}{{ end -}}
{{- with .indexUrl }}{{ $_ := set $source "index_url" . }}{{ end -}}
{{- with (default $caBundlePath .caBundlePath) }}{{ $_ := set $source "ca_bundle_path" . }}{{ end -}}
{{- if hasKey . "requestTimeoutSeconds" }}{{ $_ := set $source "request_timeout_seconds" .requestTimeoutSeconds }}{{ end -}}
{{- $credentials := .credentials | default dict -}}
{{- if $credentials.existingSecret -}}
{{- $_ := set $source "credentials" (dict
      "username_env" (include "collab-hub.cogs-source-env-name" (dict "id" .id "suffix" "USERNAME"))
      "password_env" (include "collab-hub.cogs-source-env-name" (dict "id" .id "suffix" "PASSWORD"))) -}}
{{- end -}}
{{- $webhook := .webhook | default dict -}}
{{- if $webhook.existingSecret -}}
{{- $_ := set $source "webhook_secret_env" (include "collab-hub.cogs-source-env-name" (dict "id" .id "suffix" "WEBHOOK_SECRET")) -}}
{{- end -}}
{{- $out = append $out $source -}}
{{- end -}}
{{- toJson $out -}}
{{- end -}}
