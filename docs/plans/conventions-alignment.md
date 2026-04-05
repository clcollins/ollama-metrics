# Plan: Align ollama-metrics with CONVENTIONS.md

## Summary

Adopt the standardized CONVENTIONS.md from the clcollins project family.
This brings containerized CI, plan-document requirements, and validation
script patterns to the ollama-metrics repository.

## Changes

### Containerized CI

- Add `test/Containerfile.ci` with all lint/validation tools
  (yamllint, markdownlint-cli2, checkmake, shellcheck, kubeconform)
- CI container runs lint checks identically locally (`make ci-all`)
  and remotely (GHA parallel jobs)
- Go-specific checks (fmt, vet, lint, test, build) remain on the GHA
  runner since they need the Go toolchain

### Validation Scripts

- Add `test/scripts/check-containerfile-tags.sh` — validates base image
  tags are pinned and use known registries
- Replace inline Makefile grep with the standardized script

### Makefile Restructure

- Add `ci-build`, `ci-all`, `ci-checks` targets per convention
- Add `docs-check`, `shellcheck-lint`, `kubernetes-validate` targets
- Add `.env` file support via `-include .env`
- Rename `test` → `go-test`; `test` now runs `ci-all`

### Build Context

- Add `.containerignore` to exclude non-build files from app container
- Add `test/.containerignore` for CI container build context

### Documentation

- Add CONVENTIONS.md (project standards)
- Add CLAUDE.md (Claude Code configuration)
- Add this plan document in `docs/plans/`

## Lessons Learned

- First plan document in this repo; no prior lessons to incorporate
- Pattern established by clcollins/ollama-container PR #5
