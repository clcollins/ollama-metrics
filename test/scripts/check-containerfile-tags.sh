#!/usr/bin/env bash
#
# Validates Containerfile base image references:
# - No :latest tags (warn or fail based on ENFORCE)
# - Images use known registries
#
set -euo pipefail

CONTAINERFILE="${1:-Containerfile}"
ENFORCE="${ENFORCE:-0}"
EXIT_CODE=0

KNOWN_REGISTRIES=(
  "docker.io"
  "ghcr.io"
  "gcr.io"
  "registry.k8s.io"
  "quay.io"
  "mcr.microsoft.com"
  "public.ecr.aws"
  "lscr.io"
  "registry.access.redhat.com"
  "registry.redhat.io"
  "registry.fedoraproject.org"
)

if [ ! -f "${CONTAINERFILE}" ]; then
  echo "ERROR: ${CONTAINERFILE} not found"
  exit 1
fi

echo "Checking ${CONTAINERFILE}..."

# Collect stage aliases from "FROM ... AS <name>" lines
declare -A STAGE_ALIASES
while IFS= read -r line; do
  alias=$(echo "${line}" | sed -E 's/.*[Aa][Ss][[:space:]]+([^[:space:]]+).*/\1/')
  if [ "${alias}" != "${line}" ]; then
    STAGE_ALIASES["${alias}"]=1
  fi
done < <(grep -iE '^FROM[[:space:]]' "${CONTAINERFILE}")

while IFS= read -r line; do
  # Strip inline comments and extract image reference (strip FROM and AS alias)
  image=$(echo "${line}" | sed -E 's/[[:space:]]+#.*$//; s/^FROM[[:space:]]+//i; s/[[:space:]]+[Aa][Ss][[:space:]]+.*//; s/[[:space:]]*$//')

  # Skip build stage references (matched against collected AS aliases)
  if [[ -n "${STAGE_ALIASES["${image}"]+x}" ]]; then
    continue
  fi

  # Extract tag from the last path segment (after the last /)
  # This avoids misclassifying registry ports (e.g., localhost:5000/image)
  last_segment="${image##*/}"
  if [[ "${last_segment}" =~ :latest$ ]] || [[ ! "${last_segment}" =~ : ]]; then
    echo "WARNING: ${image} uses :latest or no tag (implicit latest)"
    if [ "${ENFORCE}" = "1" ]; then
      EXIT_CODE=1
    fi
  fi

  # Check for known registry (string prefix match, not regex)
  registry_found=0
  for registry in "${KNOWN_REGISTRIES[@]}"; do
    if [[ "${image}" == "${registry}/"* ]]; then
      registry_found=1
      break
    fi
  done

  if [ "${registry_found}" = "0" ]; then
    echo "WARNING: ${image} does not use a known registry"
    if [ "${ENFORCE}" = "1" ]; then
      EXIT_CODE=1
    fi
  fi

done < <(grep -iE '^FROM[[:space:]]' "${CONTAINERFILE}")

if [ "${EXIT_CODE}" = "0" ]; then
  echo "All checks passed."
fi

exit "${EXIT_CODE}"
