# charts/

This directory holds Helm chart **source directories** — one sub-directory per chart.

```
charts/
└── my-chart/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        └── ...
```

## Adding a new chart

```bash
# Scaffold a new chart
helm create charts/my-chart

# Edit charts/my-chart/Chart.yaml, values.yaml, templates/ as needed, then:
git add charts/my-chart
git commit -m "feat: add my-chart"
git push
```

The [Release Helm Charts](../.github/workflows/release-helm-charts.yml) workflow will automatically:

1. Run `helm package` on every chart directory.
2. Merge the new packages into `index.yaml` on `gh-pages` (preserving historical `created` timestamps).
3. Deploy the updated index, chart archives, and landing page to `gh-pages`.

> **Note:** never commit pre-packaged `.tgz` files here. CI does the packaging.
