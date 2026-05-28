#!/usr/bin/env bash
# 模拟 lamby 公有云/私有云扩容：向 kind 集群追加 worker（约等于新增节点池容量）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${ROOT}/.bin:${PATH}"
CLUSTER_NAME="${CLUSTER_NAME:-kubedelta}"
POOL_NAME="${1:-pool-c}"

TMP="$(mktemp)"
cat >"${TMP}" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "nodepool.kubedelta.io/name=${POOL_NAME},kubedelta.io/tolerance=true"
EOF

echo "Adding worker node (pool=${POOL_NAME}) ..."
kind create node --name "${CLUSTER_NAME}-worker-lamby" --config "${TMP}"
kind join --name "${CLUSTER_NAME}-worker-lamby" "${CLUSTER_NAME}"
rm -f "${TMP}"

kubectl get nodes -L nodepool.kubedelta.io/name
