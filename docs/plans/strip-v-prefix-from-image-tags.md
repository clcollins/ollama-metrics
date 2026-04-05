# Plan: Strip v prefix from container image tags

## Problem

Git release tags use the `vX.Y.Z` convention (e.g., `v0.1.0`). The
image-build-push workflow previously published container images with
both `:v0.1.0` and `:0.1.0` tags. We want to publish only the bare
semver tag (`:0.1.0`) — no `v` prefix on pushed image tags.

## Intent

- **Git tags**: Continue using `vX.Y.Z` format for releases — this is
  the standard convention and should not change.
- **Image tags**: Always strip the `v` prefix before tagging the pushed
  image. Tag `v0.2.0` produces image `:0.2.0`, never `:v0.2.0`.
- **Trigger**: The workflow triggers on `v*.*.*` tags (semver releases).
  It does NOT trigger on bare `X.Y.Z` tags.

## Changes

### image-build-push.yaml

- Tighten tag trigger from `v*` to `v*.*.*` to only match semver
  release tags (not arbitrary v-prefixed tags like `v-test`)
- Strip the `v` prefix from `github.ref_name` before using it as the
  image tag and VERSION build-arg
- Remove the conditional that published both `:vX.Y.Z` and `:X.Y.Z` —
  only publish `:X.Y.Z`

## Tagging flow

```text
git tag v0.2.0        → triggers workflow
github.ref_name       → "v0.2.0"
VERSION (stripped)     → "0.2.0"
pushed image tags     → quay.io/clcollins/ollama-metrics:0.2.0
                         quay.io/clcollins/ollama-metrics:<short-sha>
```

## Lessons learned

- First plan in this area; no prior lessons to incorporate
- Copilot review caught that the glob `*.*.*` also matches `v0.2.0`,
  which led to clarifying intent: the trigger should explicitly use
  `v*.*.*` and the stripping should always happen
