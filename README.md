# Nebari Helm Repository

[![Release Helm Charts](https://github.com/nebari-dev/helm-repository/actions/workflows/release-helm-charts.yml/badge.svg)](https://github.com/nebari-dev/helm-repository/actions/workflows/release-helm-charts.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-purple.svg)](LICENSE)
[![Chart Catalog](https://img.shields.io/badge/chart%20catalog-nebari--dev.github.io-BA18DA)](https://nebari-dev.github.io/helm-repository/)

An automated Helm chart repository for the [Nebari](https://nebari.dev) ecosystem, published via GitHub Pages.

| | |
|---|---|
| **Chart catalog** | https://nebari-dev.github.io/helm-repository/ |
| **Helm index URL** | `https://raw.githubusercontent.com/nebari-dev/helm-repository/gh-pages/` |
| **Raw index.yaml** | https://raw.githubusercontent.com/nebari-dev/helm-repository/gh-pages/index.yaml |

## Using the repository

### Option A — Helm index (classic)

```bash
# Add the repository
helm repo add nebari https://raw.githubusercontent.com/nebari-dev/helm-repository/gh-pages/

# Update the local cache
helm repo update nebari

# List available charts
helm search repo nebari

# Install a chart
helm install my-release nebari/<chart-name>
```

#### Private repository access (GitHub Enterprise)

```bash
helm repo add nebari \
  https://raw.githubusercontent.com/nebari-dev/helm-repository/gh-pages/ \
  --username <your-github-username> \
  --password <your-PAT>
```

### Option B — OCI registry (quay.io)

Charts are also published as OCI artifacts to `quay.io/nebari-dev`. No `helm repo add` step is required.

```bash
# Install directly — version flag is required for OCI
helm install my-release oci://quay.io/nebari-dev/<chart-name> --version <version>

# Pull without installing
helm pull oci://quay.io/nebari-dev/<chart-name> --version <version>

# Inspect chart metadata
helm show chart oci://quay.io/nebari-dev/<chart-name> --version <version>
```

> OCI charts are public and require no authentication to pull. The OCI reference for each chart is shown in the
> [chart catalog](https://nebari-dev.github.io/helm-repository/).

## Publishing a new chart

Chart **source directories** live in `charts/` on `main`. You never need to run `helm package` manually — CI does it.

1. Scaffold or copy your chart into `charts/`:
   ```bash
   helm create charts/my-chart
   # edit Chart.yaml, values.yaml, templates/ …
   ```
2. Commit and push to `main`:
   ```bash
   git add charts/my-chart
   git commit -m "feat: add my-chart v1.0.0"
   git push
   ```

The [Release Helm Charts](.github/workflows/release-helm-charts.yml) GitHub Actions workflow will automatically:
- Run `helm package` on every directory under `charts/`
- Merge the new packages into `index.yaml` on `gh-pages` (preserving historical `created` timestamps)
- Copy chart archives to `helm/` on `gh-pages`

> **`gh-pages` is CI-managed for chart releases.** The landing page (`index.html`) lives directly on `gh-pages` — update
> it there via a PR targeting that branch.

## Syncing charts from other repositories (automated)

Tool repositories can sync their Helm chart into this repo automatically using the
[`sync-chart`](.github/actions/sync-chart/action.yml) composite action. When a new release is published in the tool
repo, the action:

1. Copies the chart source directory into `charts/<chart-name>/` here.
2. Opens a PR against `main` for review.
3. On merge, the existing **Release Helm Charts** workflow packages and publishes it.

> This is set up by **helm-repository maintainers** using the Nebari bot account. See the
> [maintainer setup guide](.github/actions/sync-chart/README.md) for token creation, organisation secret configuration,
> and per-repo rollout steps.

<details>
<summary><strong>Directory structure</strong></summary>

### `main` branch (source of truth)

```
helm-repository/
├── .github/
│   ├── actions/
│   │   └── sync-chart/
│   │       ├── action.yml            # Reusable composite action
│   │       └── README.md             # Maintainer setup guide
│   ├── examples/
│   │   └── sync-helm-chart.example.yml  # Copy this into tool repositories
│   └── workflows/
│       └── release-helm-charts.yml   # CI/CD workflow
├── charts/                           # Helm chart source directories
│   ├── my-chart/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   └── README.md
└── README.md
```

### `gh-pages` branch (served by GitHub Pages)

```
gh-pages/
├── helm/
│   └── my-chart-1.0.0.tgz           # Packaged chart archives (written by CI)
├── index.html                        # Landing page — update via PR to gh-pages
└── index.yaml                        # Helm repository index (written by CI)
```

Chart releases (packaging, index updates, OCI push) are fully automated by CI. The landing page (`index.html`) is
managed directly on `gh-pages` — to update it, open a PR targeting the `gh-pages` branch.

</details>

## License

[Apache 2.0](LICENSE)
