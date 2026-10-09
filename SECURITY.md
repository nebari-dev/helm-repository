# Security Policy

## Supported Versions

Security fixes are made on `main` and shipped in the next release. Only the most recent release receives fixes; older releases are not patched. If you can, please confirm the issue against the latest release or `main` before reporting.

## Reporting a Vulnerability

Please do not report security vulnerabilities through public GitHub issues, pull requests, or discussions.

Report them privately through GitHub's private vulnerability reporting: [open a new advisory](https://github.com/nebari-dev/helm-repository/security/advisories/new). Only the maintainers can see the report.

Please include as much of the following as you can:

- The version of this chart repository you are running, and where it is deployed
- Steps to reproduce, or a proof of concept
- The impact as you understand it, including what an attacker would need to exploit it

## What to Expect

The maintainers will acknowledge the report, work with you to confirm and understand the issue, and keep you updated on progress toward a fix. Once a fix is released, we will publish a GitHub Security Advisory and credit you unless you ask us not to.

Please give us a reasonable chance to release a fix before disclosing the issue publicly.

## Scope

In scope:

- The chart publishing workflows and actions in this repository
- The published Helm repository index and the OCI charts at `quay.io/nebari/charts`, including their signatures and provenance attestations

Out of scope here:

- Vulnerabilities in a chart's own templates or default values; report those to the repository that owns the chart
- Issues that require an attacker to already hold cluster-admin or cloud-account administrator credentials

## Verifying Releases

Every chart this repository publishes to `quay.io/nebari/charts` is signed with [Sigstore cosign](https://docs.sigstore.dev/) using keyless signing from the `release-helm-charts.yml` workflow. To verify a chart (replace `<chart>` and `<version>`):

```bash
cosign verify quay.io/nebari/charts/<chart>:<version> \
  --certificate-identity-regexp 'https://github\.com/nebari-dev/helm-repository/\.github/workflows/release-helm-charts\.yml@.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

See [Verifying Nebari artifacts](https://github.com/nebari-dev/.github/blob/main/verifying-nebari-artifacts.md) for build-provenance attestations and other artifact types.
