{{- define "nebari-app.nebariApp" -}}
{{- $_ := required "metadata.name is required" .metadata.name -}}
{{- $_ := required "spec.hostname is required" .spec.hostname -}}
{{- $_ := required "spec.service is required" .spec.service -}}
{{- $_ := required "spec.service.name is required" .spec.service.name -}}
{{- $_ := required "spec.service.port is required" .spec.service.port -}}
{{- if lt (int .spec.service.port) 1 -}}{{- fail "spec.service.port must be >= 1" -}}{{- end -}}
apiVersion: reconcilers.nebari.dev/v1
kind: NebariApp
metadata:
  {{- toYaml .metadata | nindent 2 }}
spec:
  {{- toYaml .spec | nindent 2 }}
{{- end -}}
