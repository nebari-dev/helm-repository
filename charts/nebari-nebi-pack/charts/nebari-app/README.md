# nebari-app

A [library](https://helm.sh/docs/chart_template_guide/getting_started/#the-chart-yaml-file) Helm chart providing reusable templates for rendering `NebariApp` custom resource instances.

## Install as a dependency

Add the chart to your consumer chart's `Chart.yaml`:

```yaml
dependencies:
  - name: nebari-app
    version: ">=0.1.0"
    repository: oci://quay.io/nebari/charts
```

or via a local file path during development:

```yaml
dependencies:
  - name: nebari-app
    version: ">=0.1.0"
    repository: file://../nebari-app
```

then run `helm dependency build`.

## Templates

| Template | Description |
|----------|-------------|
| [`nebari-app.nebariApp`](#nebari-appnebariapp) | Renders a complete `NebariApp` resource from `metadata` and `spec` dicts |
| [`nebari-app.deepTplJson`](#nebari-appdeeptpljson) | Applies template expansion to every string containing `{{ ... }}` in a nested structure, parsing each rendered result as JSON |

> New here? For a step-by-step, end-to-end walkthrough (dependency → values → template → apply → verify), start with [Onboarding an app with the nebari-app Helm chart](../../docs/using-the-nebari-app-chart.md). This README is the reference for the template contracts.

### nebari-app.nebariApp

Renders a complete `NebariApp` custom resource.

#### Usage

```yaml
{{ include "nebari-app.nebariApp" (dict "metadata" $metadata "spec" $spec "tplCtx" $tplCtx) }}
```

#### Parameters

- `$metadata`: Metadata mapping, such as name, namespace, and labels. This is used as-is; no templating is applied to metadata by this template.
- `$spec`: `NebariApp` CR specification. Templates will be expanded using [`nebari-app.deepTplJson`](#nebari-appdeeptpljson) if `$tplCtx` is passed.
- `$tplCtx`: Optional templating context. If omitted, no templating is applied.

#### Required fields

The template enforces the presence of `$metadata.name`, `$spec.hostname`, `$spec.service.name`, and `$spec.service.port`, and rejects a port below 1. All other validation (the rest of the `NebariAppSpec` schema) happens API-server-side at apply time. To catch schema errors before deployment, pipe `helm template` output through `kubectl apply --dry-run=server -f -`. This requires a cluster with the NebariApp CRD installed.

#### Dynamic defaults

If `tplCtx` is provided, the template uses `nebari-app.deepTplJson` internally to render `$spec`. Any string containing `{{ ... }}` is expanded and **its result must be valid JSON**, which is then parsed and used as its native type. Pipe string results through `| toJson`. Without it, a result that happens to parse as JSON is silently retyped, so `'{{ .Chart.AppVersion }}'` with `appVersion: "1.0"` becomes the number `1`, which the API server rejects as a label value. Strings with no `{{ ... }}` are left untouched and keep their original type.

```yaml
# values.yaml
service:
  port: 80

nebariApp:
  hostname: '{{ printf "%s.example.com" .Release.Name | toJson }}'
  service:
    name: '{{ printf "%s-service" .Release.Name | toJson }}'
    port: "{{ .Values.service.port }}"
```

```yaml
# template.yaml
{{ include "nebari-app.nebariApp" (dict
    "metadata" (dict
      "name"      .Release.Name
      "namespace" .Release.Namespace
      "labels"    (dict "app.kubernetes.io/name" .Chart.Name)
    )
    "spec" .Values.nebariApp
    "tplCtx"  .
) }}
```

#### Multiple NebariApps from one chart

To avoid repeating `metadata` construction at every call site, define a thin consumer-owned wrapper template that builds `metadata` from `top` and `component` and forwards `spec`:

```yaml
{{ define "mychart.nebariApp" -}}
{{- $top := .top -}}
{{- $component := .component -}}
{{- include "nebari-app.nebariApp" (dict
    "metadata" (dict
      "name"      $component
      "namespace" $top.Release.Namespace
    )
    "spec" .spec
) -}}
{{- end }}
```

Then each call site passes only `top`, `component`, and `spec`:

```yaml
{{ include "mychart.nebariApp" (dict "top" . "component" "frontend" "spec" .Values.nebariApp) }}
```

#### Namespace requirement

The Nebari operator only reconciles `NebariApp` resources whose target namespace carries the label `nebari.dev/managed=true`. This chart does not template that label. Ensure the namespace is opted in separately (e.g. via a `Namespace` resource in your consumer chart).

### nebari-app.deepTplJson

Apply template expansion to every string containing `{{ ... }}` in a nested structure. Each template must render to valid JSON; otherwise the render aborts. The rendered JSON is parsed and used as its native Go type. Strings with no template are left untouched and keep their original type. This is useful for embedding dynamic values (computed at render time) directly in your values, eliminating the need for manual merging patterns.

#### Usage

```yaml
{{ include "nebari-app.deepTplJson" (dict "ctx" $ctx "value" $value) | fromJson }}
```

#### Parameters

- `$ctx`: Context for template rendering.
- `$value`: Arbitrarily nested structure.

#### Behavior

- Recursively traverses maps and slices
- Map keys are always rendered with `tpl` and used as strings
- `tpl` is applied to a value only if it is a string containing `{{ ... }}`; strings without a template are left untouched and keep their original type
- A templated value must render to valid JSON, otherwise the render aborts
- The rendered JSON is parsed and used as its native Go type (object, array, number, boolean, null, string)
- Returns JSON string of the fully rendered structure

#### Example

```yaml
{{ include "nebari-app.deepTplJson" (dict "ctx" . "value" .Values.config) | fromJson }}
```
