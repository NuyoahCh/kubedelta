#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${ROOT}/.bin:${PATH}"
CLUSTER_NAME="${CLUSTER_NAME:-kubedelta}"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  kind delete cluster --name "${CLUSTER_NAME}"
  echo "Deleted kind cluster ${CLUSTER_NAME}"
else
  echo "No kind cluster named ${CLUSTER_NAME}"
fi
