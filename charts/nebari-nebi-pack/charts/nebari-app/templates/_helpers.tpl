{{- define "nebari-app.internal.deepTplJson" -}}
{{- $ctx := .ctx -}}
{{- $value := .value -}}
{{- $tplValue := "" -}}

{{- /* maps: recursively handle keys and values */ -}}
{{- if kindIs "map" $value -}}
    {{- $tplValue = dict -}}
    {{- range $k, $v := $value -}}
        {{- $_ := set $tplValue (tpl $k $ctx) (include "nebari-app.internal.deepTplJson" (dict "ctx" $ctx "value" $v) | fromJson).tplValue -}}
    {{- end -}}

{{- /* slices: recursively handle elements */ -}}
{{- else if kindIs "slice" $value -}}
    {{- $tplValue = list -}}
    {{- range $v := $value -}}
        {{- $tplValue = append $tplValue (include "nebari-app.internal.deepTplJson" (dict "ctx" $ctx "value" $v) | fromJson).tplValue -}}
    {{- end -}}

{{- /* templates: render */ -}}
{{- else if and (kindIs "string" $value) (contains "{{" $value) -}}
    {{- $renderResult := tpl $value $ctx -}}
    {{- /* The fromJson function requires the output to be JSON object so we need to wrap the output, which can be any valid JSON. */ -}}
    {{- $parseResult := printf "{\"tplValue\": %s}" (tpl $value $ctx) | fromJson -}}
    {{- if $parseResult.Error }}
        {{- /* $parseResult.Error holds the actual parser error message. */ -}}
        {{- /* We do not include it, because it might be misleading since it might point to the outer object the user doesn't know about. */ -}}
        {{- fail (printf "template %s was rendered into %s, which is not valid JSON" ($value | quote) ($renderResult | quote)) -}}
    {{- end -}}
    {{- $tplValue = $parseResult.tplValue -}}

{{- /* any other type: return as-is */ -}}
{{- else -}}
    {{- $tplValue = $value -}}
{{- end -}}

{{- dict "tplValue" $tplValue | toJson -}}
{{- end -}}

{{/*
    Apply template expansion to all strings in a nested structure.

    Template expressions must render to valid JSON.

    Usage:
        {{ include "nebari-app.deepTplJson" (dict "ctx" $ctx "value" $value) }}

    Parameters:
        - $ctx: Context for template rendering.
        - $value: Arbitrarily nested structure.

    Returns:
        JSON string of the rendered $value.

    Example:
        {{ include "nebari-app.deepTplJson" (dict "ctx" . "value" .Values.config) | fromJson }}
*/}}
{{- define "nebari-app.deepTplJson" -}}
{{- $_ := required "ctx is required" .ctx -}}
{{- $_ := required "value is required" .value -}}
{{- (include "nebari-app.internal.deepTplJson" . | fromJson).tplValue | toJson  -}}
{{- end -}}
