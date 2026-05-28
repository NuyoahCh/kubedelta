#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${ROOT}/.bin:${PATH}"
PROVIDER="${CLUSTER_PROVIDER:-native}"

case "${PROVIDER}" in
  native)
    exec "${ROOT}/scripts/native-cluster-down.sh"
    ;;
  kind)
    CLUSTER_NAME="${CLUSTER_NAME:-kubedelta}"
    if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
      kind delete cluster --name "${CLUSTER_NAME}"
      echo "Deleted kind cluster ${CLUSTER_NAME}"
    else
      echo "No kind cluster named ${CLUSTER_NAME}"
    fi
    ;;
  *)
    echo "Unknown CLUSTER_PROVIDER=${PROVIDER}" >&2
    exit 1
    ;;
esac
