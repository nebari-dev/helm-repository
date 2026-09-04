{{/*
  Render a complete `NebariApp` custom resource.

  Usage:
    {{ include "nebari-app.nebariApp" (dict "metadata" $metadata "spec" $spec "tplCtx" $tplCtx) }}

  Parameters:
    - `$metadata`: Metadata mapping, such as name, namespace, and labels.
    - `$spec`: `NebariApp` CR specification. Templates will be expanded using nebari-app.deepTplJson if $tplCtx is passed.
    - `$tplCtx`: Optional templating context. If omitted, no templating is applied.

  Returns:
    rendered NebariApp CR.
*/}}
{{- define "nebari-app.nebariApp" -}}

{{- $metadata := .metadata -}}
{{- $_ := required "metadata.name is required" $metadata.name -}}

{{- $spec := .spec -}}
{{- /* Template first, then validate: a non-empty template can expand to an empty value, so checking the raw input would pass where the rendered output should fail. */ -}}
{{- if hasKey . "tplCtx" -}}
  {{- $spec = include "nebari-app.deepTplJson" (dict "ctx" .tplCtx "value" $spec) | fromJson -}}
{{- end -}}
{{- $_ := required "spec.hostname is required" $spec.hostname -}}
{{- $_ := required "spec.service is required" $spec.service -}}
{{- $_ := required "spec.service.name is required" $spec.service.name -}}
{{- $_ := required "spec.service.port is required" $spec.service.port -}}
{{- if lt (int $spec.service.port) 1 -}}{{- fail "spec.service.port must be >= 1" -}}{{- end -}}

apiVersion: reconcilers.nebari.dev/v1
kind: NebariApp
metadata:
  {{- $metadata | toYamlPretty | nindent 2 }}
spec:
  {{- $spec | toYamlPretty | nindent 2 }}

{{- end }}
