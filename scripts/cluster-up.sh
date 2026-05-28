#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${ROOT}/.bin:${PATH}"

# Ubuntu/Linux 默认宿主机 kubeadm；需要 kind 时: CLUSTER_PROVIDER=kind make cluster-up
PROVIDER="${CLUSTER_PROVIDER:-native}"

case "${PROVIDER}" in
  native)
    exec "${ROOT}/scripts/native-cluster-up.sh"
    ;;
  kind)
    exec "${ROOT}/scripts/kind-cluster-up.sh"
    ;;
  *)
    echo "Unknown CLUSTER_PROVIDER=${PROVIDER} (use native or kind)" >&2
    exit 1
    ;;
esac
