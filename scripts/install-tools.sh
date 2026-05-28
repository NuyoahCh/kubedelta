#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${ROOT}/.bin"
mkdir -p "${BIN_DIR}"

install_kind() {
  if command -v kind >/dev/null 2>&1; then
    echo "kind already installed: $(kind --version)"
    return
  fi
  local arch os
  arch="$(uname -m)"
  case "${arch}" in
    arm64|aarch64) arch=arm64 ;;
    x86_64|amd64) arch=amd64 ;;
    *) echo "unsupported arch: ${arch}" >&2; exit 1 ;;
  esac
  os="$(uname | tr '[:upper:]' '[:lower:]')"
  local version="v0.27.0"
  local url="https://kind.sigs.k8s.io/dl/${version}/kind-${os}-${arch}"
  echo "Downloading kind from ${url}"
  curl -fsSL "${url}" -o "${BIN_DIR}/kind"
  chmod +x "${BIN_DIR}/kind"
  echo "Installed kind to ${BIN_DIR}/kind"
}

install_kind
export PATH="${BIN_DIR}:${PATH}"
echo "Add to shell: export PATH=\"${BIN_DIR}:\$PATH\""
