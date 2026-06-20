#!/usr/bin/env bash
# Update the vendored Helium package to the latest imputnet/helium-linux release.
# Bumps `version` and both per-system hashes in default.nix. Safe to run locally
# (needs nix + curl) or from CI. Exits 0 with no changes when already current.
set -euo pipefail

repo="imputnet/helium-linux"
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
file="${dir}/default.nix"

current="$(sed -nE 's/^[[:space:]]*version = "([^"]+)";/\1/p' "${file}" | head -n1)"

# Resolve the latest tag from the releases/latest redirect (no API token / jq).
latest="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/${repo}/releases/latest")"
latest="${latest##*/}"

echo "current: ${current}"
echo "latest:  ${latest}"

if [[ -z "${latest}" || "${latest}" == "latest" ]]; then
  echo "Could not determine the latest release." >&2
  exit 1
fi

if [[ "${current}" == "${latest}" ]]; then
  echo "Already up to date."
  [[ -n "${GITHUB_OUTPUT:-}" ]] && echo "changed=false" >>"${GITHUB_OUTPUT}"
  exit 0
fi

# nix store prefetch-file --json emits a single-line {"hash":"sha256-...",...}.
prefetch() {
  nix store prefetch-file --json --hash-type sha256 "$1" \
    | sed -E 's/.*"hash":"([^"]+)".*/\1/'
}

base="https://github.com/${repo}/releases/download/${latest}"
amd64_hash="$(prefetch "${base}/helium-bin_${latest}-1_amd64.deb")"
arm64_hash="$(prefetch "${base}/helium-bin_${latest}-1_arm64.deb")"

sed -i \
  -e "s|version = \"[^\"]*\";|version = \"${latest}\";|" \
  -e "s|x86_64-linux = \"sha256-[^\"]*\";|x86_64-linux = \"${amd64_hash}\";|" \
  -e "s|aarch64-linux = \"sha256-[^\"]*\";|aarch64-linux = \"${arm64_hash}\";|" \
  "${file}"

echo "Updated Helium ${current} -> ${latest}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "changed=true"
    echo "version=${latest}"
  } >>"${GITHUB_OUTPUT}"
fi
