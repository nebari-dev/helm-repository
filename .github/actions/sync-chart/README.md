# `sync-chart` — Maintainer Setup Guide

This composite action is called from **tool repositories** to automatically open a PR in `nebari-dev/helm-repository`
whenever a new chart release is published.

> **Audience:** This guide is for maintainers of `nebari-dev/helm-repository`. Tool-repo contributors do not need to
> read this — they just use the workflow file that a maintainer drops into their repository.



## How it works

```
tool-repo release published
  └─► sync-helm-chart.yml (in tool repo)
        └─► nebari-dev/helm-repository/.github/actions/sync-chart@main
              └─► opens PR: charts/<chart-name>/  →  main
                    └─► PR merge triggers release-helm-charts.yml
                          └─► packages, indexes, publishes to gh-pages
```



## One-time maintainer setup

### 1. Create the bot account token

The action authenticates to `nebari-dev/helm-repository` using a **fine-grained Personal Access Token** owned by the
Nebari bot account (e.g. `nebari-bot`).

Create the token under the bot account at **Settings → Developer settings → Personal access tokens → Fine-grained
tokens**:

| Setting | Value |
|---|---|
| **Resource owner** | `nebari-dev` (the organisation) |
| **Repository access** | Only select repositories → `nebari-dev/helm-repository` |
| **Contents** | Read and write |
| **Pull requests** | Read and write |
| **Metadata** | Read-only _(added automatically)_ |

Copy the generated token — you will only see it once.

### 2. Store the token as an organisation secret

Store the token once at the **organisation level** so every tool repository can reference it without per-repo
configuration:

**GitHub org → Settings → Secrets and variables → Actions → New organisation secret**

| Field | Value |
|---|---|
| **Name** | `NEBARI_HELM_REPO_TOKEN` |
| **Access** | Select repositories → choose each tool repo that needs it |

> If you prefer repo-level secrets, add the same secret under **Settings → Secrets and variables → Actions** in each
> tool repository instead.

### 3. Create the quay.io robot account and secrets

Charts are pushed to `quay.io/nebari/charts` as OCI artifacts during each release. The release workflow authenticates using
a **robot account** under the `nebari` quay.io organisation.

#### Create the robot account

1. Log in to [quay.io](https://quay.io) as a `nebari-dev` org admin.
2. Go to **nebari-dev org → Settings → Robot Accounts → Create Robot Account**.
3. Name it `helm_publisher` (full name will be `nebari-dev+helm_publisher`).
4. Grant it **Write** permission on every chart repository under `nebari-dev` (or org-wide write if you prefer a single
   blanket grant).
5. Copy the generated token — you will only see it once.

#### Store the credentials as organisation secrets in GitHub

**GitHub org → Settings → Secrets and variables → Actions → New organisation secret**

| Secret name | Value | Repository access |
|---|---|---|
| `QUAY_USERNAME` | `nebari-dev+helm_publisher` | `nebari-dev/helm-repository` only |
| `QUAY_PASSWORD` | _(generated token)_ | `nebari-dev/helm-repository` only |

> These secrets are consumed by the **Release Helm Charts** workflow in this repo only — tool repositories do not need
> them.

### 4. Create the labels in helm-repository

The action applies labels to every PR it opens. Make sure these labels exist in `nebari-dev/helm-repository` (**Issues →
Labels → New label**):

| Label | Suggested colour |
|---|---|
| `automated` | `#0075ca` |
| `helm-sync` | `#7c5cfc` |

### 5. Add the caller workflow to each tool repository

Copy [`.github/examples/sync-helm-chart.example.yml`](../examples/sync-helm-chart.example.yml) into the tool repository
at `.github/workflows/sync-helm-chart.yml`.

Adjust these two inputs at minimum:

```yaml
- uses: nebari-dev/helm-repository/.github/actions/sync-chart@main
  with:
    chart-path: helm-chart                    # directory containing Chart.yaml
    token: ${{ secrets.NEBARI_HELM_REPO_TOKEN }}
```

The workflow triggers on `release: published` by default, which aligns with the standard Nebari tool release process.



## Action inputs reference

| Input | Required | Default | Description |
|---|---|---|---|
| `token` | ✅ | — | Fine-grained PAT with contents + PR write on this repo |
| `chart-path` | ✅ | `helm-chart` | Path to the chart source dir in the calling repo |
| `chart-name` | | _(from Chart.yaml)_ | Override the destination `charts/<name>/` directory |
| `helm-repository-ref` | | `main` | PR base branch |
| `pr-title` | | _(auto-generated)_ | Override the PR title |
| `pr-labels` | | `automated,helm-sync` | Comma-separated labels (must exist in this repo) |
| `pr-reviewers` | | _(empty)_ | Comma-separated GitHub usernames to request review |
| `lint-chart` | | `true` | Run `helm lint` before opening the PR |

## Action outputs

| Output | Description |
|---|---|
| `pr-number` | Pull request number opened in this repo |
| `pr-url` | URL of the pull request |
| `chart-name` | Resolved chart name |
| `chart-version` | Resolved chart version |



## Bumping the chart version automatically from a release tag

If the tool repo uses a GitHub release tag as the authoritative version, uncomment the version-bump step in the example
workflow:

```yaml
- name: Bump chart version to release tag
  run: |
    version="${{ github.event.release.tag_name }}"
    version="${version#v}"   # strip leading 'v'
    sed -i "s/^version:.*/version: ${version}/" helm-chart/Chart.yaml
    sed -i "s/^appVersion:.*/appVersion: \"${version}\"/" helm-chart/Chart.yaml
```

This runs **before** the `sync-chart` action so the PR always carries the correct version.



## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `403` on PR creation | Token lacks PR write permission or wrong repo scope | Re-create token with correct permissions |
| `Chart.yaml not found` | `chart-path` is wrong | Check the path relative to the calling repo root |
| Duplicate PR not updated | Branch name collision from a different chart version | Check the `sync/<name>-<version>` branch; delete stale branches if needed |
| Labels not applied | Labels don't exist in `helm-repository` | Create them under Issues → Labels |
