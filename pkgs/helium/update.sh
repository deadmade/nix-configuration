#!/usr/bin/env bash
set -euo pipefail

repo="imputnet/helium-linux"
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
file="${dir}/default.nix"

current="$(sed -nE 's/^[[:space:]]*version = "([^"]+)";/\1/p' "${file}" | head -n1)"

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

prefetch() {
  nix store prefetch-file --json --hash-type sha256 "$1" \
    | sed -E 's/.*"hash":"([^"]+)".*/\1/'
}

base="https://github.com/${repo}/releases/download/${latest}"
x86_64_hash="$(prefetch "${base}/helium-${latest}-x86_64.AppImage")"
arm64_hash="$(prefetch "${base}/helium-${latest}-arm64.AppImage")"

sed -i \
  -e "s|version = \"[^\"]*\";|version = \"${latest}\";|" \
  -e "s|x86_64-linux = \"sha256-[^\"]*\";|x86_64-linux = \"${x86_64_hash}\";|" \
  -e "s|aarch64-linux = \"sha256-[^\"]*\";|aarch64-linux = \"${arm64_hash}\";|" \
  "${file}"

echo "Updated Helium ${current} -> ${latest}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "changed=true"
    echo "version=${latest}"
  } >>"${GITHUB_OUTPUT}"
fi
