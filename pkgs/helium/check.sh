#!/usr/bin/env bash
set -uo pipefail

repo="imputnet/helium-linux"
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
file="${dir}/default.nix"
cache="${XDG_CACHE_HOME:-${HOME}/.cache}/helium-latest"
ttl_minutes=720

current="$(sed -nE 's/^[[:space:]]*version = "([^"]+)";/\1/p' "${file}" | head -n1)"
[[ -n "${current}" ]] || exit 0

if [[ ! -e "${cache}" ]] || [[ -n "$(find "${cache}" -mmin "+${ttl_minutes}" 2>/dev/null)" ]]; then
  mkdir -p "$(dirname "${cache}")" 2>/dev/null
  url="$(curl -fsSL --max-time 2 -o /dev/null -w '%{url_effective}' \
    "https://github.com/${repo}/releases/latest" 2>/dev/null)"
  tag="${url##*/}"
  if [[ -n "${tag}" && "${tag}" != "latest" ]]; then
    printf '%s\n' "${tag}" >"${cache}" 2>/dev/null
  else
    touch "${cache}" 2>/dev/null
  fi
fi

[[ -s "${cache}" ]] || exit 0
latest="$(head -n1 "${cache}")"

if [[ -n "${latest}" && "${latest}" != "${current}" ]]; then
  printf 'helium: %s installed → %s available  (run `helium-update`)\n' \
    "${current}" "${latest}"
fi

exit 0
