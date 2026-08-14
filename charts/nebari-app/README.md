# nebari-app

A [library](https://helm.sh/docs/chart_template_guide/getting_started/#the-chart-yaml-file) Helm chart providing a reusable named template for rendering `NebariApp` custom resource instances.

The chart exposes one named template, `nebari-app.nebariApp`, that acts as a pure function: callers pass `metadata` and `spec` dicts and the template renders a `NebariApp` resource. It is not installable on its own — it is consumed as a [chart dependency](https://helm.sh/docs/helm/helm_dependency/).

## Install as a dependency

Add the chart to your consumer chart's `Chart.yaml`:

```yaml
dependencies:
  - name: nebari-app
    version: ">=0.1.0-0"
    repository: oci://quay.io/nebari/charts
```

or via a local file path during development:

```yaml
dependencies:
  - name: nebari-app
    version: ">=0.1.0-0"
    repository: file://../nebari-app
```

then run `helm dependency build`.

## Usage

The template takes a dict with `metadata` and `spec` keys:

```yaml
{{ include "nebari-app.nebariApp" (dict
    "metadata" (dict
      "name"      .Release.Name
      "namespace" .Release.Namespace
      "labels"    (dict "app.kubernetes.io/name" .Chart.Name)
    )
    "spec" .Values.nebariApp
) }}
```

### Required fields

The template enforces these required fields via Helm's `required` function (render aborts if any is missing or empty):

- `metadata.name`
- `spec.hostname`
- `spec.service.name`
- `spec.service.port`

All other validation (the rest of the `NebariAppSpec` schema) happens API-server-side at apply time. To catch schema errors before deployment, pipe `helm template` output through `kubectl apply --dry-run=server -f -`. This requires a cluster with the NebariApp CRD installed.

### Dynamic service values

When `spec.service.name` is derived (e.g. from a component name) rather than static, use `mergeOverwrite` to layer computed values under the consumer's static values:

```yaml
{{ include "nebari-app.nebariApp" (dict
    "metadata" (dict
      "name"      "frontend"
      "namespace" .Release.Namespace
    )
    "spec" (mergeOverwrite (dict
        "service" (dict
          "name" "frontend"
          "port" .Values.frontend.service.port
        )
      ) .Values.frontend.nebariApp)
) }}
```

`mergeOverwrite` gives precedence to its **second argument**, so consumer values override the computed defaults on overlapping keys; the computed `service.name`/`service.port` fill in the gaps.

### Multiple NebariApps from one chart

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
{{ include "mychart.nebariApp" (dict "top" . "component" "frontend" "spec" .Values.frontend.nebariApp) }}
```

## Namespace requirement

The Nebari operator only reconciles `NebariApp` resources whose target namespace carries the label `nebari.dev/managed=true`. This chart does not template that label — ensure the namespace is opted in separately (e.g. via a `Namespace` resource in your consumer chart).

## Field reference

The canonical reference for all `spec` fields is [docs/api-reference.md](../../docs/api-reference.md), auto-generated from the Go types. See also [docs/configuration-reference.md](../../docs/configuration-reference.md) for examples and usage guidance.
